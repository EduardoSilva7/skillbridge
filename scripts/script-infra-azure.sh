#!/usr/bin/env bash
set -euo pipefail

# =========================
# CONFIG (defaults)
# =========================
SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-bf23da40-8f8a-4f42-980a-0497f40fe328}"

# RG/Plan/WebApp ficam nesta região
LOCATION="${LOCATION:-brazilsouth}"

PREFIX="${PREFIX:-gs2025}"
PROJECT="${PROJECT:-skillbridge}"
ENV="${ENV:-dev}"

RG_NAME="${RG_NAME:-${PREFIX}-${PROJECT}-${ENV}-rg}"
PLAN_NAME="${PLAN_NAME:-${PREFIX}-${PROJECT}-${ENV}-plan}"
WEBAPP_NAME="${WEBAPP_NAME:-${PREFIX}-${PROJECT}-${ENV}-api}"

# ----- MySQL: criaremos em Canada Central por padrão, com fallback -----
MYSQL_LOCATION_PRIMARY="${MYSQL_LOCATION_PRIMARY:-canadacentral}"
MYSQL_LOCATION_FALLBACK="${MYSQL_LOCATION_FALLBACK:-eastus}"

MYSQL_SERVER="${MYSQL_SERVER:-${PREFIX}${PROJECT}${ENV}mysql}"   
MYSQL_DB="${MYSQL_DB:-appdb}"

MYSQL_ADMIN_USER="${MYSQL_ADMIN_USER:-fiapadmin}"
MYSQL_ADMIN_PASSWORD="${MYSQL_ADMIN_PASSWORD:-Fiap@2tds}"
MYSQL_VERSION="${MYSQL_VERSION:-8.0.21}"  

PLAN_SKU="${PLAN_SKU:-S1}"                       # App Service Plan Linux
MYSQL_SKU_PRIMARY="${MYSQL_SKU_PRIMARY:-Standard_B1ms}"
MYSQL_SKU_FALLBACK="${MYSQL_SKU_FALLBACK:-Standard_B2s}"

# =========================
# helpers
# =========================
log(){ echo ">> $*"; }
exists_rg()      { az group exists -n "$RG_NAME" --subscription "$SUBSCRIPTION_ID"; }
exists_plan()    { az appservice plan show -g "$RG_NAME" -n "$PLAN_NAME" --subscription "$SUBSCRIPTION_ID" &>/dev/null && echo true || echo false; }
exists_webapp()  { az webapp show -g "$RG_NAME" -n "$WEBAPP_NAME" --subscription "$SUBSCRIPTION_ID" &>/dev/null && echo true || echo false; }
exists_mysql()   { az mysql flexible-server show -g "$RG_NAME" -n "$MYSQL_SERVER" --subscription "$SUBSCRIPTION_ID" &>/dev/null && echo true || echo false; }
exists_db()      { az mysql flexible-server db show -g "$RG_NAME" -s "$MYSQL_SERVER" -d "$MYSQL_DB" --subscription "$SUBSCRIPTION_ID" &>/dev/null && echo true || echo false; }

create_mysql(){
  local loc="$1"; local sku="$2"
  log "Tentando criar MySQL Flexible em '$loc' com SKU '$sku' (version $MYSQL_VERSION)..."
  set +e
  az mysql flexible-server create -g "$RG_NAME" -n "$MYSQL_SERVER" -l "$loc" \
    --admin-user "$MYSQL_ADMIN_USER" --admin-password "$MYSQL_ADMIN_PASSWORD" \
    --sku-name "$sku" --tier Burstable --storage-size 20 --version "$MYSQL_VERSION" \
    --subscription "$SUBSCRIPTION_ID" --yes -o none
  local rc=$?
  set -e
  return $rc
}

# =========================
# Execução
# =========================
log "Usando subscription: $SUBSCRIPTION_ID"
az account set --subscription "$SUBSCRIPTION_ID"

# 1) Resource Group
if [[ "$(exists_rg)" != true ]]; then
  log "Criando Resource Group: $RG_NAME ($LOCATION)"
  az group create -n "$RG_NAME" -l "$LOCATION" -o none
else
  log "Resource Group já existe: $RG_NAME"
fi

# 2) App Service Plan (Linux)
if [[ "$(exists_plan)" != true ]]; then
  log "Criando App Service Plan Linux: $PLAN_NAME (SKU: $PLAN_SKU)"
  az appservice plan create -g "$RG_NAME" -n "$PLAN_NAME" --sku "$PLAN_SKU" --is-linux \
    --subscription "$SUBSCRIPTION_ID" -o none
else
  log "App Service Plan já existe: $PLAN_NAME"
fi

# 3) Web App (Java 17)
if [[ "$(exists_webapp)" != true ]]; then
  log "Criando Web App: $WEBAPP_NAME (Java 17)"
  az webapp create -g "$RG_NAME" -p "$PLAN_NAME" -n "$WEBAPP_NAME" \
    --runtime "JAVA|17-java17" --subscription "$SUBSCRIPTION_ID" -o none
else
  log "Web App já existe: $WEBAPP_NAME"
fi

# 4) MySQL Flexible com fallback (região/SKU)
if [[ "$(exists_mysql)" != true ]]; then
  if ! create_mysql "$MYSQL_LOCATION_PRIMARY" "$MYSQL_SKU_PRIMARY"; then
    log "Falha em $MYSQL_LOCATION_PRIMARY/$MYSQL_SKU_PRIMARY — tentando $MYSQL_LOCATION_PRIMARY/$MYSQL_SKU_FALLBACK"
    if ! create_mysql "$MYSQL_LOCATION_PRIMARY" "$MYSQL_SKU_FALLBACK"; then
      log "Falha em $MYSQL_LOCATION_PRIMARY — tentando fallback $MYSQL_LOCATION_FALLBACK/$MYSQL_SKU_FALLBACK"
      create_mysql "$MYSQL_LOCATION_FALLBACK" "$MYSQL_SKU_FALLBACK"
    fi
  fi
else
  log "MySQL Flexible já existe: $MYSQL_SERVER"
fi

# 5) Database
if [[ "$(exists_db)" != true ]]; then
  log "Criando database: $MYSQL_DB"
  az mysql flexible-server db create -g "$RG_NAME" -s "$MYSQL_SERVER" -d "$MYSQL_DB" \
    --subscription "$SUBSCRIPTION_ID" -o none
else
  log "Database já existe: $MYSQL_DB"
fi

# 6) Firewall rule para IP atual (best-effort)
if command -v curl >/dev/null 2>&1; then
  LOCAL_IP="$(curl -s https://ifconfig.me || echo 0.0.0.0)"
else
  LOCAL_IP="0.0.0.0"
fi
log "Criando regra de firewall para IP local: $LOCAL_IP (ignorar erro se não suportado)"
az mysql flexible-server firewall-rule create \
  --resource-group "$RG_NAME" \
  --name "$MYSQL_SERVER" \
  --rule-name "allow-local-ip" \
  --start-ip-address "$LOCAL_IP" \
  --end-ip-address "$LOCAL_IP" \
  --subscription "$SUBSCRIPTION_ID" -o none || true

# 7) App Settings no Web App
FQDN="$(az mysql flexible-server show -g "$RG_NAME" -n "$MYSQL_SERVER" --subscription "$SUBSCRIPTION_ID" --query 'fullyQualifiedDomainName' -o tsv)"
JDBC="jdbc:mysql://${FQDN}:3306/${MYSQL_DB}?createDatabaseIfNotExist=true&useSSL=true&requireSSL=false&useUnicode=true&characterEncoding=UTF-8&serverTimezone=UTC"

log "Aplicando App Settings no Web App"
az webapp config appsettings set -g "$RG_NAME" -n "$WEBAPP_NAME" --subscription "$SUBSCRIPTION_ID" --settings \
  SPRING_PROFILES_ACTIVE="$ENV" \
  SPRING_DATASOURCE_URL="$JDBC" \
  SPRING_DATASOURCE_USERNAME="$MYSQL_ADMIN_USER" \
  SPRING_DATASOURCE_PASSWORD="$MYSQL_ADMIN_PASSWORD" \
  JAVA_OPTS="-Xms256m -Xmx512m" \
  WEBSITES_PORT=8080 -o none

echo
echo "==================== SAÍDAS ===================="
echo "Resource Group ....: $RG_NAME (RG/Plan/WebApp em $LOCATION)"
echo "Web App ...........: https://${WEBAPP_NAME}.azurewebsites.net"
echo "MySQL FQDN ........: $FQDN (MySQL criado em $MYSQL_LOCATION_PRIMARY ou $MYSQL_LOCATION_FALLBACK)"
echo "SPRING_DATASOURCE_URL sugerida:"
echo "$JDBC"
echo "================================================"
