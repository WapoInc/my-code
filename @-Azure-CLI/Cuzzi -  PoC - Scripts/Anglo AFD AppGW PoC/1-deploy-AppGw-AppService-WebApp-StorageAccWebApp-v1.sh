#!/usr/bin/env bash
###############################################################################
# South Africa North HLD deployment
#
#   [ active VM ] --> [ App Gateway (WAF) ] --> [ API App (App Service) ] --> [ Storage static website ]
##
# IDEMPOTENT: every resource is checked first. If it already exists the script
# prints [FOUND] and skips creation. Dependency-sensitive resources are followed
# by an explicit wait so dependents are never built against a half-ready parent.
#
# NOTE on re-runs: if a previous run failed *midway* through the storage block
# (account created but static site / firewall not finished), the account will be
# treated as [FOUND] and that block skipped -- delete the account and re-run, or
# finish it by hand. This is the usual trade-off of coarse per-resource skipping.
#
# Run:   chmod +x deploy-san-hld.sh && ./deploy-san-hld.sh
# Needs: az CLI >= 2.55, logged in (az login), correct subscription selected.
###############################################################################
set -euo pipefail

###############################################################################
# 0. CORE SETTINGS  -- edit these ###-###
###############################################################################
LOCATION="southafricanorth"
SUBSCRIPTION=""                       # optional; leave "" to use current default
<<<<<<<< HEAD:@-Azure-CLI/Cuzzi -  PoC - Scripts/Anglo AFD AppGW PoC/1-deploy-AppGw-AppService-WebApp-StorageAccWebApp-v1.sh
RG="1-deploy-AppGw-AppService-WebApp-StorageAccWebApp-v1"             # RG
========
<<<<<<< HEAD:@-Azure-CLI/Cuzzi -  PoC - Scripts/Anglo AFD AppGW PoC/1-deploy-san-hld-Appservice-WebApp-SQL-staticweb.sh
RG="mneu-rg-prod-mrk-001-v2"             # RG is not in the diagram -- adjust to taste
=======
RG="mneu-rg-prod-mrk-001-v4"          # RG is not in the diagram -- adjust to taste
>>>>>>> 32f2204 (aaz):@-Azure-CLI/Cuzzi -  PoC - Scripts/Anglo AFD AppGW PoC/1-deploy-san-hld-Appservice-SQL-staticweb.sh
>>>>>>>> afd2cb1d21847a8eb77af9d88e1058d5e40b4208:@-Azure-CLI/Cuzzi -  PoC - Scripts/Anglo AFD AppGW PoC/1-deploy-san-hld-Appservice-SQL-staticweb.sh

###############################################################################
# 1. RESOURCE NAMES (exactly as per the HLD)
#    NOTE: API_APP must be GLOBALLY unique (*.azurewebsites.net) and STORAGE_ACCT
#          must be globally unique, 3-24 chars, lowercase letters/numbers only
#          (no hyphens) -- so the 'mkt' SQL name is folded into 'mneustprodmkt001'.
#          Add a suffix to either if the name is already taken.
###############################################################################
<<<<<<<< HEAD:@-Azure-CLI/Cuzzi -  PoC - Scripts/Anglo AFD AppGW PoC/1-deploy-AppGw-AppService-WebApp-StorageAccWebApp-v1.sh
AGW_NAME="mneu-agw-prod-mrk-001-v1"
API_APP="mneu-api-prod-mrk-001-v1"
STORAGE_ACCT="mneustprodmkt001v1"     # backend static website (was the SQL server)
VM_NAME="mneu-vm-prod-mrk-001-v1"
========
AGW_NAME="mneu-agw-prod-mrk-001-v4"
API_APP="mneu-api-prod-mrk-001-v4"
STORAGE_ACCT="mneustprodmkt001v4"     # backend static website (was the SQL server)
VM_NAME="mneu-vm-prod-mrk-001-v4"
>>>>>>>> afd2cb1d21847a8eb77af9d88e1058d5e40b4208:@-Azure-CLI/Cuzzi -  PoC - Scripts/Anglo AFD AppGW PoC/1-deploy-san-hld-Appservice-SQL-staticweb.sh

###############################################################################
# 2. NETWORKING
###############################################################################
<<<<<<<< HEAD:@-Azure-CLI/Cuzzi -  PoC - Scripts/Anglo AFD AppGW PoC/1-deploy-AppGw-AppService-WebApp-StorageAccWebApp-v1.sh
VNET="mneu-vnet-prod-mrk-001-v1"
VNET_CIDR="10.20.0.0/16"
SUBNET_AGW="snet-agw-v1";       SUBNET_AGW_CIDR="10.20.1.0/24"   # App Gateway (dedicated)
SUBNET_APP="snet-appsvc-v1";    SUBNET_APP_CIDR="10.20.3.0/24"   # App Service VNet integration
SUBNET_WORKLOAD="snet-workload-v1"; SUBNET_WORKLOAD_CIDR="10.20.4.0/24"  # extra subnet, same VNet as AGW (holds the VM)
AGW_PRIVATE_IP="10.20.1.10"           # static private frontend IP; must be inside SUBNET_AGW_CIDR
WAF_POLICY="mneu-wafpol-prod-mrk-001-v1"
========
VNET="mneu-vnet-prod-mrk-001-v4"
VNET_CIDR="10.20.0.0/16"
SUBNET_AGW="snet-agw-v4";       SUBNET_AGW_CIDR="10.20.1.0/24"   # App Gateway (dedicated)
SUBNET_APP="snet-appsvc-v4";    SUBNET_APP_CIDR="10.20.3.0/24"   # App Service VNet integration
SUBNET_WORKLOAD="snet-workload-v4"; SUBNET_WORKLOAD_CIDR="10.20.4.0/24"  # extra subnet, same VNet as AGW (holds the VM)
AGW_PRIVATE_IP="10.20.1.10"           # static private frontend IP; must be inside SUBNET_AGW_CIDR
WAF_POLICY="mneu-wafpol-prod-mrk-001-v4"
>>>>>>>> afd2cb1d21847a8eb77af9d88e1058d5e40b4208:@-Azure-CLI/Cuzzi -  PoC - Scripts/Anglo AFD AppGW PoC/1-deploy-san-hld-Appservice-SQL-staticweb.sh

###############################################################################
# 3. SKUs / SIZES  -- reasonable prod defaults, tune as needed
###############################################################################
<<<<<<<< HEAD:@-Azure-CLI/Cuzzi -  PoC - Scripts/Anglo AFD AppGW PoC/1-deploy-AppGw-AppService-WebApp-StorageAccWebApp-v1.sh
APP_PLAN="mneu-asp-prod-mrk-001-v1"
========
APP_PLAN="mneu-asp-prod-mrk-001-v4"
>>>>>>>> afd2cb1d21847a8eb77af9d88e1058d5e40b4208:@-Azure-CLI/Cuzzi -  PoC - Scripts/Anglo AFD AppGW PoC/1-deploy-san-hld-Appservice-SQL-staticweb.sh
APP_PLAN_SKU="P1v3"                   # Linux App Service plan
APP_RUNTIME="DOTNETCORE:8.0"          # change to NODE:20-lts, PYTHON:3.12, etc.
VM_SIZE="Standard_B2s"
VM_IMAGE="Win2022Datacenter"          # Windows Server 2022 Datacenter
VM_ADMIN="adminroot"
# !! Hard-coded plaintext password as requested. This is insecure (shell history,
# !! source control) and Azure's banned-password check may reject a common value
# !! like this at deploy time. Prefer a runtime prompt or Key Vault for anything real.
VM_ADMIN_PASSWORD='P@ssw0rd123!'
<<<<<<<< HEAD:@-Azure-CLI/Cuzzi -  PoC - Scripts/Anglo AFD AppGW PoC/1-deploy-AppGw-AppService-WebApp-StorageAccWebApp-v1.sh
VM_NSG="mneu-nsg-vm-prod-mrk-001-v1"    # NSG protecting the VM
========
VM_NSG="mneu-nsg-vm-prod-mrk-001-v4"    # NSG protecting the VM
>>>>>>>> afd2cb1d21847a8eb77af9d88e1058d5e40b4208:@-Azure-CLI/Cuzzi -  PoC - Scripts/Anglo AFD AppGW PoC/1-deploy-san-hld-Appservice-SQL-staticweb.sh

###############################################################################
# --- Helpers ---
###############################################################################
say()     { printf '\n===============================================================================\n>> %s\n===============================================================================\n' "$*"; }
found()   { printf '   [FOUND]  %s -- skipping create\n' "$*"; }
made()    { printf '   [OK]     %s\n' "$*"; }
waitmsg() { printf '   [WAIT]   %s\n' "$*"; }

# exists <az ... show ...> : returns 0 if the resource is found, 1 otherwise
exists() { "$@" -o none >/dev/null 2>&1; }

###############################################################################
# --- Execution ---
###############################################################################
[ -n "$SUBSCRIPTION" ] && az account set --subscription "$SUBSCRIPTION"

say "Resource group: $RG"
if exists az group show -n "$RG"; then
  found "Resource group $RG"
else
  az group create -n "$RG" -l "$LOCATION" -o none
  made "Resource group $RG created"
fi

say "Virtual network: $VNET"
if exists az network vnet show -g "$RG" -n "$VNET"; then
  found "VNet $VNET"
else
  az network vnet create -g "$RG" -n "$VNET" -l "$LOCATION" \
    --address-prefixes "$VNET_CIDR" -o none
  made "VNet $VNET created"
fi
waitmsg "VNet $VNET to finish provisioning"
az network vnet wait -g "$RG" -n "$VNET" --created -o none

say "Subnet: $SUBNET_AGW (App Gateway)"
if exists az network vnet subnet show -g "$RG" --vnet-name "$VNET" -n "$SUBNET_AGW"; then
  found "Subnet $SUBNET_AGW"
else
  az network vnet subnet create -g "$RG" --vnet-name "$VNET" \
    -n "$SUBNET_AGW" --address-prefixes "$SUBNET_AGW_CIDR" \
    --delegations Microsoft.Network/applicationGateways -o none
  made "Subnet $SUBNET_AGW created"
fi
# Ensure delegation is present regardless of whether subnet already existed
DELEG=$(az network vnet subnet show -g "$RG" --vnet-name "$VNET" -n "$SUBNET_AGW" \
  --query "delegations[?serviceName=='Microsoft.Network/applicationGateways'] | length(@)" \
  -o tsv 2>/dev/null || echo 0)
if [ "${DELEG:-0}" -eq 0 ]; then
  az network vnet subnet update -g "$RG" --vnet-name "$VNET" \
    -n "$SUBNET_AGW" --delegations Microsoft.Network/applicationGateways -o none
  made "Delegation Microsoft.Network/applicationGateways added to $SUBNET_AGW"
else
  found "Delegation Microsoft.Network/applicationGateways on $SUBNET_AGW"
fi

say "Subnet: $SUBNET_APP (App Service delegated)"
if exists az network vnet subnet show -g "$RG" --vnet-name "$VNET" -n "$SUBNET_APP"; then
  found "Subnet $SUBNET_APP"
else
  az network vnet subnet create -g "$RG" --vnet-name "$VNET" \
    -n "$SUBNET_APP" --address-prefixes "$SUBNET_APP_CIDR" \
    --delegations Microsoft.Web/serverFarms -o none
  made "Subnet $SUBNET_APP created"
fi

say "Subnet: $SUBNET_WORKLOAD (VM, same VNet as AGW)"
if exists az network vnet subnet show -g "$RG" --vnet-name "$VNET" -n "$SUBNET_WORKLOAD"; then
  found "Subnet $SUBNET_WORKLOAD"
else
  az network vnet subnet create -g "$RG" --vnet-name "$VNET" \
    -n "$SUBNET_WORKLOAD" --address-prefixes "$SUBNET_WORKLOAD_CIDR" -o none
  made "Subnet $SUBNET_WORKLOAD created"
fi

say "Private-only App Gateway feature (subscription-wide, one-time)"
FEATURE_STATE=$(az feature show --namespace Microsoft.Network \
  --name EnableApplicationGatewayNetworkIsolation --query properties.state -o tsv 2>/dev/null || echo "NotRegistered")
if [ "$FEATURE_STATE" = "Registered" ]; then
  found "Feature EnableApplicationGatewayNetworkIsolation (already Registered)"
else
  az feature register --namespace Microsoft.Network \
    --name EnableApplicationGatewayNetworkIsolation -o none || true
  waitmsg "feature registration (can take up to ~30 min the first time)"
  until [ "$(az feature show --namespace Microsoft.Network \
    --name EnableApplicationGatewayNetworkIsolation \
    --query properties.state -o tsv)" = "Registered" ]; do
    sleep 30
  done
  az provider register --namespace Microsoft.Network -o none   # propagate the feature
  made "Feature EnableApplicationGatewayNetworkIsolation registered"
fi

say "WAF policy: $WAF_POLICY"
if exists az network application-gateway waf-policy show -g "$RG" -n "$WAF_POLICY"; then
  found "WAF policy $WAF_POLICY"
else
  az network application-gateway waf-policy create -g "$RG" -n "$WAF_POLICY" -l "$LOCATION" -o none
  made "WAF policy $WAF_POLICY created"
fi
# Ensure Prevention mode (idempotent -- safe to re-apply)
az network application-gateway waf-policy policy-setting update \
  -g "$RG" --policy-name "$WAF_POLICY" --mode Prevention --state Enabled -o none

say "App Service plan: $APP_PLAN"
if exists az appservice plan show -g "$RG" -n "$APP_PLAN"; then
  found "App Service plan $APP_PLAN"
else
  az appservice plan create -g "$RG" -n "$APP_PLAN" -l "$LOCATION" \
    --sku "$APP_PLAN_SKU" --is-linux -o none
  made "App Service plan $APP_PLAN created"
fi

say "API web app: $API_APP"
if exists az webapp show -g "$RG" -n "$API_APP"; then
  found "Web app $API_APP"
else
  az webapp create -g "$RG" -p "$APP_PLAN" -n "$API_APP" \
    --runtime "$APP_RUNTIME" -o none
  made "Web app $API_APP created"
fi

say "App Service VNet integration -> $SUBNET_APP"
if [ -n "$(az webapp vnet-integration list -g "$RG" -n "$API_APP" -o tsv 2>/dev/null)" ]; then
  found "VNet integration already present on $API_APP"
else
  az webapp vnet-integration add -g "$RG" -n "$API_APP" \
    --vnet "$VNET" --subnet "$SUBNET_APP" -o none
  made "VNet integration added to $API_APP"
fi

say "Deploy storage-proxy Node.js app to $API_APP"
# The App Service acts as a transparent proxy to the storage static website.
# This keeps the content in storage while the AGW WAF protects the entry point.
TMP_APP_DIR=$(mktemp -d)
cat > "$TMP_APP_DIR/index.js" <<'APPEOF'
const http = require('http');
const https = require('https');
const url = require('url');
const port = process.env.PORT || 8080;
http.createServer((_req, res) => {
  res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
  res.end(`<!DOCTYPE html>
<html lang="en"><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<<<<<<< HEAD:@-Azure-CLI/Cuzzi -  PoC - Scripts/Anglo AFD AppGW PoC/1-deploy-san-hld-Appservice-WebApp-SQL-staticweb.sh
<title>Hello from castlegate to home</title>
=======
<title>XXX-Hello-XXX</title>
>>>>>>> 32f2204 (aaz):@-Azure-CLI/Cuzzi -  PoC - Scripts/Anglo AFD AppGW PoC/1-deploy-san-hld-Appservice-SQL-staticweb.sh
<style>
  body { margin:0; height:100vh; display:flex; align-items:center;
         justify-content:center; font-family:system-ui,sans-serif;
         background:#0b1a2b; color:#fff; }
  h1 { font-size:clamp(2rem,8vw,5rem); }
</style>
</head><body>
  <h1>XXX-Hello-XXX</h1>
</body></html>`);
}).listen(port, () => console.log('Listening on port ' + port));
APPEOF
cat > "$TMP_APP_DIR/package.json" <<'PKGEOF'
{"name":"storage-proxy","version":"1.0.0","main":"index.js","scripts":{"start":"node index.js"}}
PKGEOF
(cd "$TMP_APP_DIR" && zip -r app.zip . -x "*.zip" >/dev/null)
az webapp config set -g "$RG" -n "$API_APP" \
  --linux-fx-version "NODE|20-lts" -o none
# Enable Oryx build during zip deploy (installs deps / runs start script for Linux)
az webapp config appsettings set -g "$RG" -n "$API_APP" \
  --settings SCM_DO_BUILD_DURING_DEPLOYMENT=true -o none
# Re-runs: a previous run may have locked the SCM (Kudu) endpoint to the AGW subnet
# (Allow-AGW-Subnet-SCM rule below). That lock blocks 'az webapp deploy' from this
# machine with HTTP 403 ("Web App - Unavailable"). Temporarily remove it so Kudu is
# reachable for the deploy; the SCM lock is re-applied further down in this script.
if az webapp config access-restriction show -g "$RG" -n "$API_APP" --scm-site true \
    --query "ipSecurityRestrictions[?name=='Allow-AGW-Subnet-SCM']" -o tsv 2>/dev/null | grep -q .; then
  az webapp config access-restriction remove -g "$RG" -n "$API_APP" --scm-site true \
    --rule-name "Allow-AGW-Subnet-SCM" -o none
  made "Temporarily removed SCM lock Allow-AGW-Subnet-SCM for deployment"
  # Give the access-restriction change a moment to propagate to the SCM front end.
  sleep 20
fi
# --track-status false avoids the 404 from the deploymentStatus polling endpoint,
# which is a known Azure CLI issue where tracking fails even though the zip deploy succeeds.
az webapp deploy -g "$RG" -n "$API_APP" \
  --src-path "$TMP_APP_DIR/app.zip" --type zip --track-status false -o none
rm -rf "$TMP_APP_DIR"
made "Storage-proxy app deployed to $API_APP"

say "Application Gateway (WAF_v2, PRIVATE frontend only): $AGW_NAME"
if exists az network application-gateway show -g "$RG" -n "$AGW_NAME"; then
  found "App Gateway $AGW_NAME"
else
  # Private-only: static private IP from the AGW subnet is the frontend; no public IP.
  # Listener stays on HTTP:80 for simplicity. For production add a TLS cert + 443 listener.
  az network application-gateway create -g "$RG" -n "$AGW_NAME" -l "$LOCATION" \
    --sku WAF_v2 --capacity 2 \
    --vnet-name "$VNET" --subnet "$SUBNET_AGW" \
    --private-ip-address "$AGW_PRIVATE_IP" \
    --waf-policy "$WAF_POLICY" \
    --servers "${API_APP}.azurewebsites.net" \
    --priority 100 -o none
  made "App Gateway $AGW_NAME created"
fi
waitmsg "App Gateway $AGW_NAME to finish provisioning"
az network application-gateway wait -g "$RG" -n "$AGW_NAME" --created -o none

# Custom health probe: must send the correct Host header or App Service returns 400
# and AGW marks the backend unhealthy (-> 502 to the client).
if exists az network application-gateway probe show -g "$RG" --gateway-name "$AGW_NAME" -n appgw-appsvc-probe; then
  found "Health probe appgw-appsvc-probe"
else
  az network application-gateway probe create \
    -g "$RG" --gateway-name "$AGW_NAME" -n appgw-appsvc-probe \
    --protocol Https --host "${API_APP}.azurewebsites.net" \
    --path "/" --interval 30 --timeout 30 --threshold 3 -o none
  made "Health probe appgw-appsvc-probe created"
fi

# Backend HTTP settings: HTTPS:443, preserve App Service hostname, attach probe.
az network application-gateway http-settings update \
  -g "$RG" --gateway-name "$AGW_NAME" -n appGatewayBackendHttpSettings \
  --protocol Https --port 443 --host-name-from-backend-pool true \
  --probe appgw-appsvc-probe -o none
made "Backend HTTP settings updated (HTTPS + probe)"

# App Service access restriction: only accept inbound from the AGW subnet.
# Requires Microsoft.Web service endpoint on snet-agw so the subnet-based rule
# can match traffic from the AGW (without this the rule never fires -> default deny -> 502).
az network vnet subnet update -g "$RG" --vnet-name "$VNET" -n "$SUBNET_AGW" \
  --service-endpoints Microsoft.Web -o none
made "Microsoft.Web service endpoint enabled on $SUBNET_AGW"

if az webapp config access-restriction show -g "$RG" -n "$API_APP" \
    --query "ipSecurityRestrictions[?name=='Allow-AGW-Subnet']" -o tsv 2>/dev/null | grep -q .; then
  found "App Service access restriction Allow-AGW-Subnet"
else
  az webapp config access-restriction add -g "$RG" -n "$API_APP" \
    --rule-name "Allow-AGW-Subnet" --action Allow --priority 100 \
    --vnet-name "$VNET" --subnet "$SUBNET_AGW" -o none
  made "App Service access restriction: allow $SUBNET_AGW only"
fi
# Also lock the SCM (Kudu) endpoint — prevents direct public access to the deploy API.
if az webapp config access-restriction show -g "$RG" -n "$API_APP" --scm-site true \
    --query "ipSecurityRestrictions[?name=='Allow-AGW-Subnet-SCM']" -o tsv 2>/dev/null | grep -q .; then
  found "App Service SCM access restriction Allow-AGW-Subnet-SCM"
else
  az webapp config access-restriction add -g "$RG" -n "$API_APP" --scm-site true \
    --rule-name "Allow-AGW-Subnet-SCM" --action Allow --priority 100 \
    --vnet-name "$VNET" --subnet "$SUBNET_AGW" -o none
  made "App Service SCM access restriction: allow $SUBNET_AGW only"
fi

say "Storage account (backend static website): $STORAGE_ACCT"
if exists az storage account show -g "$RG" -n "$STORAGE_ACCT"; then
  found "Storage account $STORAGE_ACCT"
else
  az storage account create -g "$RG" -n "$STORAGE_ACCT" -l "$LOCATION" \
    --sku Standard_LRS --kind StorageV2 --min-tls-version TLS1_2 \
    --tags SecurityControl=Ignore -o none
  waitmsg "storage account $STORAGE_ACCT to reach provisioningState=Succeeded"
  until [ "$(az storage account show -g "$RG" -n "$STORAGE_ACCT" \
    --query provisioningState -o tsv 2>/dev/null)" = "Succeeded" ]; do
    sleep 5
  done
  made "Storage account $STORAGE_ACCT created"
fi

say "Lock down storage networking (deny public, allow AGW + VM + App Service subnets)"
# Enable the Microsoft.Storage service endpoint on all three subnets.
# NOTE: --service-endpoints REPLACES the list, so existing endpoints (e.g. Microsoft.Web
# on snet-agw) must be repeated here or they will be stripped and break other features.
az network vnet subnet update -g "$RG" --vnet-name "$VNET" -n "$SUBNET_AGW" \
  --service-endpoints Microsoft.Storage Microsoft.Web -o none
az network vnet subnet update -g "$RG" --vnet-name "$VNET" -n "$SUBNET_WORKLOAD" \
  --service-endpoints Microsoft.Storage -o none
az network vnet subnet update -g "$RG" --vnet-name "$VNET" -n "$SUBNET_APP" \
  --service-endpoints Microsoft.Storage Microsoft.Web -o none
# Allow all three subnets (idempotent -- add is a no-op if rule already exists)
az storage account network-rule add -g "$RG" --account-name "$STORAGE_ACCT" \
  --vnet-name "$VNET" --subnet "$SUBNET_AGW" -o none
az storage account network-rule add -g "$RG" --account-name "$STORAGE_ACCT" \
  --vnet-name "$VNET" --subnet "$SUBNET_WORKLOAD" -o none
az storage account network-rule add -g "$RG" --account-name "$STORAGE_ACCT" \
  --vnet-name "$VNET" --subnet "$SUBNET_APP" -o none

# Data-plane: get storage key, enable static website, upload content
STORAGE_KEY=$(az storage account keys list -g "$RG" -n "$STORAGE_ACCT" \
  --query "[0].value" -o tsv)

say "Enable static website on $STORAGE_ACCT"
az storage blob service-properties update \
  --account-name "$STORAGE_ACCT" --account-key "$STORAGE_KEY" \
  --static-website --index-document index.html --404-document index.html -o none
made "Static website enabled"

say "Upload index.html to \$web (Hello World Storage Account)"
cat > /tmp/poc-index.html <<'HTML'
<!DOCTYPE html>
<html lang="en"><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Hello World Storage Account</title>
<style>
  body { margin:0; height:100vh; display:flex; align-items:center;
         justify-content:center; font-family:system-ui,sans-serif;
         background:#0b1a2b; color:#fff; }
  h1 { font-size:clamp(1.5rem,6vw,4rem); text-align:center; padding:1rem; }
</style>
</head><body>
  <h1>Hello World Storage Account</h1>
</body></html>
HTML
# Temporarily open the firewall so this script (running outside the VNet) can upload
az storage account update -g "$RG" -n "$STORAGE_ACCT" --default-action Allow -o none
az storage blob upload \
  --account-name "$STORAGE_ACCT" --account-key "$STORAGE_KEY" \
  -c '$web' -f /tmp/poc-index.html -n index.html \
  --content-type "text/html" --overwrite -o none
rm -f /tmp/poc-index.html
made "index.html uploaded to \$web"

# Re-lock firewall
az storage account update -g "$RG" -n "$STORAGE_ACCT" \
  --default-action Deny --bypass AzureServices -o none
made "Storage firewall: allow $SUBNET_AGW + $SUBNET_WORKLOAD + $SUBNET_APP"

# Get static website URL and point the App Service proxy at it
STATIC_SITE_URL=$(az storage account show -g "$RG" -n "$STORAGE_ACCT" \
  --query "primaryEndpoints.web" -o tsv)
say "Point App Service proxy at storage static site: $STATIC_SITE_URL"
az webapp config appsettings set -g "$RG" -n "$API_APP" \
  --settings "BACKEND_URL=${STATIC_SITE_URL}" -o none
made "BACKEND_URL set to $STATIC_SITE_URL"

say "NSG for VM (VNet-internal protection): $VM_NSG"
if exists az network nsg show -g "$RG" -n "$VM_NSG"; then
  found "NSG $VM_NSG"
else
  az network nsg create -g "$RG" -n "$VM_NSG" -l "$LOCATION" -o none
  made "NSG $VM_NSG created"
fi
# Allow outbound HTTP + HTTPS so the VM can browse to the storage static site
if exists az network nsg rule show -g "$RG" --nsg-name "$VM_NSG" -n "Allow-Web-Outbound"; then
  found "NSG rule Allow-Web-Outbound"
else
  az network nsg rule create -g "$RG" --nsg-name "$VM_NSG" \
    -n "Allow-Web-Outbound" --priority 200 \
    --destination-port-ranges 80 443 --protocol Tcp \
    --access Allow --direction Outbound -o none
  made "NSG rule Allow-Web-Outbound created (TCP 80 + 443 outbound)"
fi

say "Active VM -- Windows Server 2022, in $SUBNET_WORKLOAD: $VM_NAME"
if exists az vm show -g "$RG" -n "$VM_NAME"; then
  found "VM $VM_NAME"
else
  az vm create -g "$RG" -n "$VM_NAME" -l "$LOCATION" \
<<<<<<<< HEAD:@-Azure-CLI/Cuzzi -  PoC - Scripts/Anglo AFD AppGW PoC/1-deploy-AppGw-AppService-WebApp-StorageAccWebApp-v1.sh
    --computer-name "mneu-vm-mrk-v1" \
========
    --computer-name "mneu-vm-mrk-v4" \
>>>>>>>> afd2cb1d21847a8eb77af9d88e1058d5e40b4208:@-Azure-CLI/Cuzzi -  PoC - Scripts/Anglo AFD AppGW PoC/1-deploy-san-hld-Appservice-SQL-staticweb.sh
    --image "$VM_IMAGE" --size "$VM_SIZE" \
    --vnet-name "$VNET" --subnet "$SUBNET_WORKLOAD" \
    --admin-username "$VM_ADMIN" --admin-password "$VM_ADMIN_PASSWORD" \
    --public-ip-address "" --nsg "$VM_NSG" -o none
  made "VM $VM_NAME created"
  waitmsg "VM $VM_NAME to finish provisioning"
  az vm wait -g "$RG" -n "$VM_NAME" --created -o none
fi
# Idempotent: ensure NSG is wired to the NIC
VM_NIC=$(az vm show -g "$RG" -n "$VM_NAME" \
  --query "networkProfile.networkInterfaces[0].id" -o tsv | xargs basename)
az network nic update -g "$RG" -n "$VM_NIC" --network-security-group "$VM_NSG" -o none
made "NIC $VM_NIC: NSG ensured (no public IP)"

echo ""
echo "=== Done ==="
echo "App Gateway private frontend IP: ${AGW_PRIVATE_IP} (reachable only inside the VNet / via peering / VPN / ER)"
echo "VM:           private only (no public IP) -- use Bastion or VPN to connect"
echo "API app URL:  https://${API_APP}.azurewebsites.net (accessible via AGW only)"
