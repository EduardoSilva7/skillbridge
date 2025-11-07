#!/usr/bin/env bash
set -euo pipefail

# =========================
# CONFIG (com defaults)
# =========================
SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-bf23da40-8f8a-4f42-980a-0497f40fe328}"
LOCATION="${LOCATION:-brazilsouth}"             # mude para eastus/southcentralus se quiser
PREFIX="${PREFIX:-gs2025}"
PROJECT="${PROJECT:-skillbridge}"
ENV="${ENV:-dev}"

RG_NAME="${RG_NAME:-${PREFIX}-${PROJECT}-${ENV}-rg}"
PLAN_NAME="${PLAN_NAME:-${PREFIX}-${PROJECT}-${ENV}-plan}"
WEBAPP_NAME="${WEBAPP_NAME:-${PREFIX}-${PROJECT}-${ENV}-api}"       
MYSQL_SERVER="${MYSQL_SERVER:-${PREFIX}${PROJECT}${ENV}mysql}"       
MYSQL_DB="${MYSQL_DB:-appdb}"

MYSQL_ADMIN_USER="${MYSQL_ADMIN_USER:-fiapadmin}"
MYSQL_ADMIN_PASSWORD="${MYSQL_ADMIN_PASSWORD:-Fiap@2tds}"           

# =========================
# Funções utilitárias
# =========================
log() { echo -e ">> $*"; }
exists_rg()      { az group exists -n "$RG_NAME" --subscription "$SUBSCRIPTION_ID"; }
exists_plan()    { az appservice plan show -g "$RG_NAME" -n "$PLAN_NAME" --subscription "$SUBSCRIPTION_ID" &>/dev/null && echo true || echo false; }
exists_webapp()  { az webapp show -g "$RG_NAME" -n "$WEBAPP_NAME" --subscription "$SUBSCRIPTION_ID" &>/dev/null && echo true || echo false; }
exists_mysql()   { az mysql flexible-server show -g "$RG_NAME" -n "$MYSQL_SERVER" --subscription "$SUBSCRIPTION_ID" &>/dev/null && echo true || echo false; }
exists_db()      { az mysql flexible-server db show -g "$RG_NAME" -s "$MYSQL_SERVER" -d "$MYSQL_DB" --subscription "$SUBSCRIPTION_ID" &>/dev/null && echo true || echo false; }

choose_appservice_sku() {
  local want=("B1" "S1")
  for sku in "${want[@]}"; do
    if az appservice plan list-skus --location "$LOCATION" --subscription "$SUBSCRIPTION_ID" -o tsv | awk '{print $1}' | grep -qx "$sku"; then
      echo "$sku"; return 0
    fi
  done
  echo "S1"
}

choose_mysql_sku() {
  local want=("Standard_B1ms" "Standard_B2s")
  local available
  available="$(az mysql flexible-server list-skus --location "$LOCATION" --subscription "$SUBSCRIPTION_ID" -o tsv | awk '{print $1}')"
  for sku in "${want[@]}"; do
    if echo "$available" | grep -qx "$sku"; then
      echo "$sku"; return 0
    fi
  done
  echo "Standard_B2s"
}

# =========================
# Execução
# =========================
log "Usando subscription: $SUBSCRIPTION_ID"; az account set --subscription "$SUBSCRIPTION_ID"

# 1) Resource Group
if [[ "$(exists_rg)" != true ]]; then
  log "Criando Resource Group: $RG_NAME ($LOCATION)"
  az group create -n "$RG_NAME" -l "$LOCATION" -o none
else
  log "Resource Group já existe: $RG_NAME"
fi

# 2) App Service Plan (Linux)
if [[ "$(exists_plan)" != true ]]; then
  PLAN_SKU="${PLAN_SKU:-$(choose_appservice_sku)}"
  log "Criando App Service Plan Linux: $PLAN_NAME (SKU: $PLAN_SKU)"
  az appservice plan create -g "$RG_NAME" -n "$PLAN_NAME" --sku "$PLAN_SKU" --is-linux --subscription "$SUBSCRIPTION_ID" -o none
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

# 4) MySQL Flexible Server
if [[ "$(exists_mysql)" != true ]]; then
  MYSQL_SKU="${MYSQL_SKU:-$(choose_mysql_sku)}"
  log "Criando MySQL Flexible: $MYSQL_SERVER (SKU: $MYSQL_SKU)"
  az mysql flexible-server create -g "$RG_NAME" -n "$MYSQL_SERVER" -l "$LOCATION" \
    --admin-user "$MYSQL_ADMIN_USER" --admin-password "$MYSQL_ADMIN_PASSWORD" \
    --sku-name "$MYSQL_SKU" --tier Burstable --storage-size 20 --version 8.0 \
    --subscription "$SUBSCRIPTION_ID" --yes -o none
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

# 6) Firewall rule para seu IP atual (se falhar, ignora)
if command -v curl >/dev/null 2>&1; then
  LOCAL_IP="$(curl -s https://ifconfig.me || echo 0.0.0.0)"
else
  LOCAL_IP="0.0.0.0"
fi
log "Criando regra de firewall para IP local: $LOCAL_IP"
az mysql flexible-server firewall-rule create -g "$RG_NAME" -s "$MYSQL_SERVER" \
  -n "allow-local-ip" --start-ip-address "$LOCAL_IP" --end-ip-address "$LOCAL_IP" \
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
echo "Resource Group ....: $RG_NAME"
echo "Web App ...........: https://${WEBAPP_NAME}.azurewebsites.net"
echo "MySQL FQDN ........: $FQDN"
echo "SPRING_DATASOURCE_URL sugerida:"
echo "$JDBC"
echo "================================================"
