param(
  [string]$Location = "brazilsouth",
  [string]$Prefix   = "gs2025",
  [string]$Env      = "dev",
  [string]$Project  = "skillbridge"
)

$ErrorActionPreference = "Stop"
$rg = "$Prefix-$Project-$Env-rg"
$plan = "$Prefix-$Project-$Env-plan"
$webapp = "$Prefix-$Project-$Env-api"
$mysql = ($Prefix + $Project + $Env + "mysql").ToLower()
$db = "appdb"
$adminUser = "fiapadmin"
if (-not $env:MYSQL_ADMIN_PASSWORD) { $env:MYSQL_ADMIN_PASSWORD = "Fiap@2tds" }

az group create -n $rg -l $Location | Out-Null
az appservice plan create -g $rg -n $plan --sku B1 --is-linux | Out-Null
az webapp create -g $rg -p $plan -n $webapp --runtime "JAVA|17-java17" | Out-Null

az mysql flexible-server create -g $rg -n $mysql -l $Location `
  --admin-user $adminUser --admin-password $env:MYSQL_ADMIN_PASSWORD `
  --sku-name Standard_B1ms --tier Burstable --storage-size 20 --version 8.0 --yes | Out-Null

az mysql flexible-server db create -g $rg -s $mysql -d $db | Out-Null

try { $localIp = (Invoke-RestMethod -Uri "https://ifconfig.me") } catch { $localIp = "0.0.0.0" }
az mysql flexible-server firewall-rule create -g $rg -s $mysql -n "allow-local-ip" --start-ip-address $localIp --end-ip-address $localIp | Out-Null

$fqdn = az mysql flexible-server show -g $rg -n $mysql --query "fullyQualifiedDomainName" -o tsv
$jdbc = "jdbc:mysql://$fqdn:3306/$db?createDatabaseIfNotExist=true&useSSL=true&requireSSL=false&useUnicode=true&characterEncoding=UTF-8&serverTimezone=UTC"

az webapp config appsettings set -g $rg -n $webapp --settings `
  SPRING_PROFILES_ACTIVE=$Env `
  SPRING_DATASOURCE_URL=$jdbc `
  SPRING_DATASOURCE_USERNAME=$adminUser `
  SPRING_DATASOURCE_PASSWORD=$env:MYSQL_ADMIN_PASSWORD `
  JAVA_OPTS="-Xms256m -Xmx512m" `
  WEBSITES_PORT=8080 | Out-Null

Write-Host "Web App: https://$webapp.azurewebsites.net"
Write-Host "MySQL FQDN: $fqdn"
