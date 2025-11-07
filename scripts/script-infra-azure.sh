#!/usr/bin/env bash
set -euo pipefail

LOCATION="brazilsouth"
PREFIX="gs2025"
ENV="dev"
PROJECT="skillbridge"
RG_NAME="${PREFIX}-${PROJECT}-${ENV}-rg"
PLAN_NAME="${PREFIX}-${PROJECT}-${ENV}-plan"
WEBAPP_NAME="${PREFIX}-${PROJECT}-${ENV}-api"
MYSQL_SERVER="${PREFIX}${PROJECT}${ENV}mysql"
MYSQL_DB="appdb"
MYSQL_ADMIN_USER="fiapadmin"
: "${MYSQL_ADMIN_PASSWORD:=Fiap@2tds}"

LOCAL_IP="$(curl -s https://ifconfig.me || echo 0.0.0.0)"

az group create -n "${RG_NAME}" -l "${LOCATION}" 1>/dev/null
az appservice plan create -g "${RG_NAME}" -n "${PLAN_NAME}" --sku B1 --is-linux 1>/dev/null
az webapp create -g "${RG_NAME}" -p "${PLAN_NAME}" -n "${WEBAPP_NAME}" --runtime "JAVA|17-java17" 1>/dev/null

az mysql flexible-server create -g "${RG_NAME}" -n "${MYSQL_SERVER}" -l "${LOCATION}"   --admin-user "${MYSQL_ADMIN_USER}" --admin-password "${MYSQL_ADMIN_PASSWORD}"   --sku-name Standard_B1ms --tier Burstable --storage-size 20 --version 8.0 --yes 1>/dev/null

az mysql flexible-server db create -g "${RG_NAME}" -s "${MYSQL_SERVER}" -d "${MYSQL_DB}" 1>/dev/null

az mysql flexible-server firewall-rule create -g "${RG_NAME}" -s "${MYSQL_SERVER}"   -n "allow-local-ip" --start-ip-address "${LOCAL_IP}" --end-ip-address "${LOCAL_IP}" 1>/dev/null || true

FQDN=$(az mysql flexible-server show -g "${RG_NAME}" -n "${MYSQL_SERVER}" --query "fullyQualifiedDomainName" -o tsv)

SPRING_DATASOURCE_URL="jdbc:mysql://${FQDN}:3306/${MYSQL_DB}?createDatabaseIfNotExist=true&useSSL=true&requireSSL=false&useUnicode=true&characterEncoding=UTF-8&serverTimezone=UTC"

az webapp config appsettings set -g "${RG_NAME}" -n "${WEBAPP_NAME}" --settings   "SPRING_PROFILES_ACTIVE=${ENV}"   "SPRING_DATASOURCE_URL=${SPRING_DATASOURCE_URL}"   "SPRING_DATASOURCE_USERNAME=${MYSQL_ADMIN_USER}"   "SPRING_DATASOURCE_PASSWORD=${MYSQL_ADMIN_PASSWORD}"   "JAVA_OPTS=-Xms256m -Xmx512m"   "WEBSITES_PORT=8080" 1>/dev/null

echo "Web App: https://${WEBAPP_NAME}.azurewebsites.net"
echo "MySQL FQDN: ${FQDN}"
