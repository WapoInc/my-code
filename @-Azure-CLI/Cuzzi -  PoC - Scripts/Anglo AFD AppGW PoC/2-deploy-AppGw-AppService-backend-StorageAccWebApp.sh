#!/usr/bin/env bash
###############################################################################
# South Africa North HLD deployment
#
#   [ active VM ] --> [ App Gateway (WAF) ] --> [ API App (App Service) ] --> [ Storage static website ]
#
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
# 0. CORE SETTINGS  -- edit these
###############################################################################
LOCATION="southafricanorth"
SUBSCRIPTION=""                       # optional; leave "" to use current default
RG="2-deploy-AppGw-AppService-backend-StorageAccWebApp"             # RG
###############################################################################
# 1. RESOURCE NAMES (exactly as per the HLD)##
#    NOTE: API_APP must be GLOBALLY unique (*.azurewebsites.net) and STORAGE_ACCT
#          must be globally unique, 3-24 chars, lowercase letters/numbers only
#          (no hyphens) -- so the 'mkt' SQL name is folded into 'mneustprodmkt001'.
#          Add a suffix to either if the name is already taken.
###############################################################################
AGW_NAME="mneu-agw-prod-mrk-001-2"
API_APP="mneu-api-prod-mrk-001-2"
VM_NAME="mneu-vm-prod-mrk-001-2"

###############################################################################
# 2. NETWORKING
###############################################################################
VNET="mneu-vnet-prod-mrk-001-2"
VNET_CIDR="10.20.0.0/16"
SUBNET_AGW="snet-agw-2";       SUBNET_AGW_CIDR="10.20.1.0/24"   # App Gateway (dedicated)
SUBNET_APP="snet-appsvc-2";    SUBNET_APP_CIDR="10.20.3.0/24"   # App Service VNet integration
SUBNET_WORKLOAD="snet-workload-2"; SUBNET_WORKLOAD_CIDR="10.20.4.0/24"  # extra subnet, same VNet as AGW (holds the VM)
AGW_PRIVATE_IP="10.20.1.10"           # static private frontend IP; must be inside SUBNET_AGW_CIDR
WAF_POLICY="mneu-wafpol-prod-mrk-001-2"

###############################################################################
# 3. SKUs / SIZES  -- reasonable prod defaults, tune as needed
###############################################################################
APP_PLAN="mneu-asp-prod-mrk-001-2"
APP_PLAN_SKU="P1v3"                   # Linux App Service plan
APP_RUNTIME="DOTNETCORE:8.0"          # change to NODE:20-lts, PYTHON:3.12, etc.
VM_SIZE="Standard_B2s"
VM_IMAGE="Win2022Datacenter"          # Windows Server 2022 Datacenter
VM_ADMIN="adminroot"
# !! Hard-coded plaintext password as requested. This is insecure (shell history,
# !! source control) and Azure's banned-password check may reject a common value
# !! like this at deploy time. Prefer a runtime prompt or Key Vault for anything real.
VM_ADMIN_PASSWORD='P@ssw0rd123!'
VM_PIP="mneu-pip-vm-prod-mrk-001-2"       # public IP for RDP access
VM_NSG="mneu-nsg-vm-prod-mrk-001-2"       # NSG allowing RDP from the fixed source
RDP_SOURCE_IP="156.155.28.158"

###############################################################################
# --- Helpers ---
###############################################################################
say()     { printf '\n>> %s\n' "$*"; }
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

say "Deploy Node.js PoC app to $API_APP"
TMP_APP_DIR=$(mktemp -d)
cat > "$TMP_APP_DIR/index.js" <<'APPEOF'
const http = require('http');
const port = process.env.PORT || 8080;
http.createServer((_req, res) => {
  res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
  res.end(`<!DOCTYPE html>
<html lang="en"><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>--xxx-MiaCasa-xxx--</title>
<style>
  body { margin:0; height:100vh; display:flex; align-items:center;
         justify-content:center; font-family:system-ui,sans-serif;
         background:#0b1a2b; color:#fff; }
  h1 { font-size:clamp(2rem,8vw,5rem); }
</style>
</head><body>
  <h1>--xxx-MiaCasa-xxx--</h1>
</body></html>`);
}).listen(port, () => console.log('Listening on port ' + port));
APPEOF
cat > "$TMP_APP_DIR/package.json" <<'PKGEOF'
{"name":"poc-api","version":"1.0.0","main":"index.js","scripts":{"start":"node index.js"}}
PKGEOF
(cd "$TMP_APP_DIR" && zip -r app.zip . -x "*.zip" >/dev/null)
# Switch runtime to Node:20-lts (idempotent)
az webapp config set -g "$RG" -n "$API_APP" \
  --linux-fx-version "NODE|20-lts" -o none
az webapp deploy -g "$RG" -n "$API_APP" \
  --src-path "$TMP_APP_DIR/app.zip" --type zip -o none
rm -rf "$TMP_APP_DIR"
made "Node.js PoC app deployed to $API_APP"

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

say "Public IP for VM RDP: $VM_PIP"
if exists az network public-ip show -g "$RG" -n "$VM_PIP"; then
  found "Public IP $VM_PIP"
else
  az network public-ip create -g "$RG" -n "$VM_PIP" -l "$LOCATION" \
    --sku Standard --allocation-method Static -o none
  made "Public IP $VM_PIP created"
fi

say "NSG for VM RDP (allow $RDP_SOURCE_IP -> 3389): $VM_NSG"
if exists az network nsg show -g "$RG" -n "$VM_NSG"; then
  found "NSG $VM_NSG"
else
  az network nsg create -g "$RG" -n "$VM_NSG" -l "$LOCATION" -o none
  made "NSG $VM_NSG created"
fi
# Idempotent: add/update the RDP allow rule
if exists az network nsg rule show -g "$RG" --nsg-name "$VM_NSG" -n "Allow-RDP-Source"; then
  found "NSG rule Allow-RDP-Source"
else
  az network nsg rule create -g "$RG" --nsg-name "$VM_NSG" \
    -n "Allow-RDP-Source" --priority 100 \
    --source-address-prefixes "${RDP_SOURCE_IP}/32" \
    --destination-port-ranges 3389 --protocol Tcp \
    --access Allow --direction Inbound -o none
  made "NSG rule Allow-RDP-Source created (src ${RDP_SOURCE_IP}/32 -> TCP 3389)"
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
    --computer-name "mneu-vm-mrk-001-2" \
    --image "$VM_IMAGE" --size "$VM_SIZE" \
    --vnet-name "$VNET" --subnet "$SUBNET_WORKLOAD" \
    --admin-username "$VM_ADMIN" --admin-password "$VM_ADMIN_PASSWORD" \
    --public-ip-address "$VM_PIP" --nsg "$VM_NSG" -o none
  made "VM $VM_NAME created"
  waitmsg "VM $VM_NAME to finish provisioning"
  az vm wait -g "$RG" -n "$VM_NAME" --created -o none
fi
# Idempotent: ensure public IP and NSG are wired to the NIC (handles existing VM case)
VM_NIC=$(az vm show -g "$RG" -n "$VM_NAME" \
  --query "networkProfile.networkInterfaces[0].id" -o tsv | xargs basename)
az network nic update -g "$RG" -n "$VM_NIC" --network-security-group "$VM_NSG" -o none
az network nic ip-config update -g "$RG" --nic-name "$VM_NIC" \
  -n ipconfig1 --public-ip-address "$VM_PIP" -o none
made "NIC $VM_NIC: NSG and public IP ensured"

echo ""
echo "=== Done ==="
VM_PUBLIC_IP=$(az network public-ip show -g "$RG" -n "$VM_PIP" --query ipAddress -o tsv 2>/dev/null || echo "(pending)")
echo "App Gateway private frontend IP: ${AGW_PRIVATE_IP} (reachable only inside the VNet / via peering / VPN / ER)"
echo "VM RDP:       ${VM_PUBLIC_IP}:3389  (allowed from ${RDP_SOURCE_IP} only)"
echo "App Service:  https://${API_APP}.azurewebsites.net  (serves --xxx-MiaCasa-xxx-- via AGW at ${AGW_PRIVATE_IP})"
