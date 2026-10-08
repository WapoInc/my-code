#!/usr/bin/env bash
###############################################################################
# South Africa North HLD deployment
#
#   [ Azure Front Door Premium ] --Private Link--> [ App Gateway (WAF) ]
#                                                        |
#                                                        v
#                                               [ API App (App Service) ]
#                                               [ active VM (private) ]
##
# Each execution generates a new five-character suffix and deploys an independent
# environment. Dependency-sensitive resources are followed by an explicit wait
# so dependents are never built against a half-ready parent.
# #########@@@@@@Copilot
# Run:   chmod +x deploy-san-hld.sh && ./deploy-san-hld.sh
# Needs: az CLI >= 2.55 with the `az afd` commands available, logged in
#        (az login), correct subscription selected.
###############################################################################
set -euo pipefail

###############################################################################
# 0. CORE SETTINGS  -- edit these ###-###
###############################################################################
LOCATION="southafricanorth"
SUBSCRIPTION=""                       # optional; leave "" to use current default
DEFAULT_RG="xxx-deploy-AppGw-AppService-WebApp-StorageAccWebApp-v1"
SUFFIX_HEX=$(od -An -N3 -tx1 /dev/urandom | tr -d ' \n')
UNIQUE_SUFFIX=${SUFFIX_HEX%?}
if [ "${#UNIQUE_SUFFIX}" -ne 5 ]; then
  printf 'ERROR: Unable to generate a five-character resource suffix.\n' >&2
  exit 1
fi

###############################################################################
# 1. RESOURCE NAMES (exactly as per the HLD)
#    The per-run suffix prevents collisions between independent deployments.
###############################################################################
AGW_NAME="mneu-agw-prod-mrk-001-v1-${UNIQUE_SUFFIX}"
API_APP="mneu-api-prod-mrk-001-v1-${UNIQUE_SUFFIX}"
VM_NAME="mneu-vm-prod-mrk-001-v1-${UNIQUE_SUFFIX}"
AFD_PROFILE="mneu-afd-prod-mrk-001-v1-${UNIQUE_SUFFIX}"
AFD_ENDPOINT="mneu-afd-endpoint-prod-mrk-001-v1-${UNIQUE_SUFFIX}"
AFD_ORIGIN_GROUP="appgw-origin-group-${UNIQUE_SUFFIX}"
AFD_ORIGIN="appgw-origin-${UNIQUE_SUFFIX}"
AFD_ROUTE="appgw-route-${UNIQUE_SUFFIX}"

###############################################################################
# 2. NETWORKING
###############################################################################
VNET="mneu-vnet-prod-mrk-001-v1-${UNIQUE_SUFFIX}"
VNET_CIDR="10.20.0.0/16"
SUBNET_AGW="snet-agw-v1-${UNIQUE_SUFFIX}";       SUBNET_AGW_CIDR="10.20.1.0/24"   # App Gateway (dedicated)
SUBNET_APP="snet-appsvc-v1-${UNIQUE_SUFFIX}";    SUBNET_APP_CIDR="10.20.3.0/24"   # App Service VNet integration
SUBNET_WORKLOAD="snet-workload-v1-${UNIQUE_SUFFIX}"; SUBNET_WORKLOAD_CIDR="10.20.4.0/24"  # extra subnet, same VNet as AGW (holds the VM)
SUBNET_AGW_PL="snet-agw-private-link-v1-${UNIQUE_SUFFIX}"; SUBNET_AGW_PL_CIDR="10.20.5.0/24"
AGW_PRIVATE_IP="10.20.1.10"           # static private frontend IP; must be inside SUBNET_AGW_CIDR
AGW_PUBLIC_IP="mneu-pip-agw-prod-mrk-001-v1-${UNIQUE_SUFFIX}"
AGW_PRIVATE_LINK="agw-private-link-v1-${UNIQUE_SUFFIX}"
AGW_PROBE="appgw-appsvc-probe-${UNIQUE_SUFFIX}"
WAF_POLICY="mneu-wafpol-prod-mrk-001-v1-${UNIQUE_SUFFIX}"

###############################################################################
# 3. SKUs / SIZES  -- reasonable prod defaults, tune as needed
###############################################################################
APP_PLAN="mneu-asp-prod-mrk-001-v1-${UNIQUE_SUFFIX}"
APP_PLAN_SKU="P1v3"                   # Linux App Service plan
APP_RUNTIME="DOTNETCORE:8.0"          # change to NODE:20-lts, PYTHON:3.12, etc.
VM_SIZE="Standard_B2s"
VM_IMAGE="Win2022Datacenter"          # Windows Server 2022 Datacenter
VM_ADMIN="adminroot"
VM_COMPUTER_NAME="mneu-vm-${UNIQUE_SUFFIX}"
# !! Hard-coded plaintext password as requested. This is insecure (shell history,
# !! source control) and Azure's banned-password check may reject a common value
# !! like this at deploy time. Prefer a runtime prompt or Key Vault for anything real.
VM_ADMIN_PASSWORD='P@ssw0rd123!'
VM_NSG="mneu-nsg-vm-prod-mrk-001-v1-${UNIQUE_SUFFIX}" # NSG protecting the VM
NSG_WEB_RULE="Allow-Web-Outbound-${UNIQUE_SUFFIX}"
APP_ACCESS_RULE="Allow-AGW-Subnet-${UNIQUE_SUFFIX}"
SCM_ACCESS_RULE="Allow-AGW-Subnet-SCM-${UNIQUE_SUFFIX}"

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

printf 'Resource group base name [%s]: ' "$DEFAULT_RG"
if ! IFS= read -r RG_INPUT; then
  printf '\nERROR: Unable to read the resource group name.\n' >&2
  exit 1
fi
RG="${RG_INPUT:-$DEFAULT_RG}-${UNIQUE_SUFFIX}"
printf 'Using suffix %s; resource group will be %s.\n' "$UNIQUE_SUFFIX" "$RG"

if ! az afd profile -h >/dev/null 2>&1; then
  printf 'ERROR: Azure Front Door CLI commands are unavailable. Install/update the Azure CLI cdn extension.\n' >&2
  exit 1
fi

say "Resource group: $RG"
if exists az group show -n "$RG"; then
  printf 'ERROR: Generated resource group %s already exists. Run the script again for a new suffix.\n' "$RG" >&2
  exit 1
fi
az group create -n "$RG" -l "$LOCATION" -o none
made "Resource group $RG created"

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
    -n "$SUBNET_AGW" --address-prefixes "$SUBNET_AGW_CIDR" -o none
  made "Subnet $SUBNET_AGW created"
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

say "Subnet: $SUBNET_AGW_PL (Application Gateway Private Link)"
if exists az network vnet subnet show -g "$RG" --vnet-name "$VNET" -n "$SUBNET_AGW_PL"; then
  found "Subnet $SUBNET_AGW_PL"
else
  az network vnet subnet create -g "$RG" --vnet-name "$VNET" \
    -n "$SUBNET_AGW_PL" --address-prefixes "$SUBNET_AGW_PL_CIDR" \
    --disable-private-link-service-network-policies true -o none
  made "Subnet $SUBNET_AGW_PL created"
fi
# Application Gateway Private Link requires this policy to remain disabled.
az network vnet subnet update -g "$RG" --vnet-name "$VNET" \
  -n "$SUBNET_AGW_PL" --disable-private-link-service-network-policies true -o none

say "Application Gateway feature compatibility (Private Link requires network isolation disabled)"
FEATURE_STATE=$(az feature show --namespace Microsoft.Network \
  --name EnableApplicationGatewayNetworkIsolation --query properties.state -o tsv 2>/dev/null || echo "NotRegistered")
if [ "$FEATURE_STATE" = "Registered" ] || [ "$FEATURE_STATE" = "Registering" ]; then
  az feature unregister --namespace Microsoft.Network \
    --name EnableApplicationGatewayNetworkIsolation -o none
  waitmsg "network isolation feature to unregister (required for Private Link)"
  until [ "$(az feature show --namespace Microsoft.Network \
    --name EnableApplicationGatewayNetworkIsolation \
    --query properties.state -o tsv)" = "Unregistered" ]; do
    sleep 30
  done
  az provider register --namespace Microsoft.Network -o none
  made "Feature EnableApplicationGatewayNetworkIsolation unregistered"
elif [ "$FEATURE_STATE" = "Unregistering" ]; then
  waitmsg "network isolation feature to finish unregistering"
  until [ "$(az feature show --namespace Microsoft.Network \
    --name EnableApplicationGatewayNetworkIsolation \
    --query properties.state -o tsv)" = "Unregistered" ]; do
    sleep 30
  done
  az provider register --namespace Microsoft.Network -o none
  made "Feature EnableApplicationGatewayNetworkIsolation unregistered"
else
  found "Feature EnableApplicationGatewayNetworkIsolation is not registered"
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

say "Deploy Hello page Node.js app to $API_APP"
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
<title>XXX-Hello-XXX</title>
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
{"name":"hello-page","version":"1.0.0","main":"index.js","scripts":{"start":"node index.js"}}
PKGEOF
(cd "$TMP_APP_DIR" && zip -r app.zip . -x "*.zip" >/dev/null)
az webapp config set -g "$RG" -n "$API_APP" \
  --linux-fx-version "NODE|20-lts" -o none
# Enable Oryx build during zip deploy (installs deps / runs start script for Linux)
az webapp config appsettings set -g "$RG" -n "$API_APP" \
  --settings SCM_DO_BUILD_DURING_DEPLOYMENT=true -o none
# Re-runs: a previous run may have locked the SCM (Kudu) endpoint to the AGW subnet
# (the SCM access rule below). That lock blocks 'az webapp deploy' from this
# machine with HTTP 403 ("Web App - Unavailable"). Temporarily remove it so Kudu is
# reachable for the deploy; the SCM lock is re-applied further down in this script.
if az webapp config access-restriction show -g "$RG" -n "$API_APP" --scm-site true \
    --query "ipSecurityRestrictions[?name=='${SCM_ACCESS_RULE}']" -o tsv 2>/dev/null | grep -q .; then
  az webapp config access-restriction remove -g "$RG" -n "$API_APP" --scm-site true \
    --rule-name "$SCM_ACCESS_RULE" -o none
  made "Temporarily removed SCM lock $SCM_ACCESS_RULE for deployment"
  # Give the access-restriction change a moment to propagate to the SCM front end.
  sleep 20
fi
# --track-status false avoids the 404 from the deploymentStatus polling endpoint,
# which is a known Azure CLI issue where tracking fails even though the zip deploy succeeds.
az webapp deploy -g "$RG" -n "$API_APP" \
  --src-path "$TMP_APP_DIR/app.zip" --type zip --track-status false -o none
rm -rf "$TMP_APP_DIR"
made "Hello page app deployed to $API_APP"

say "Application Gateway public IP: $AGW_PUBLIC_IP"
if exists az network public-ip show -g "$RG" -n "$AGW_PUBLIC_IP"; then
  found "Public IP $AGW_PUBLIC_IP"
else
  az network public-ip create -g "$RG" -n "$AGW_PUBLIC_IP" -l "$LOCATION" \
    --sku Standard --allocation-method Static -o none
  made "Public IP $AGW_PUBLIC_IP created"
fi

say "Application Gateway (WAF_v2, public + private frontends): $AGW_NAME"
if exists az network application-gateway show -g "$RG" -n "$AGW_NAME"; then
  AGW_PUBLIC_FRONTEND_COUNT=$(az network application-gateway show -g "$RG" -n "$AGW_NAME" \
    --query "frontendIPConfigurations[?publicIPAddress != null] | length(@)" -o tsv)
  if [ "${AGW_PUBLIC_FRONTEND_COUNT:-0}" -eq 0 ]; then
    waitmsg "replacing network-isolated gateway, which is incompatible with Private Link"
    az network application-gateway delete -g "$RG" -n "$AGW_NAME" -o none
    az network application-gateway wait -g "$RG" -n "$AGW_NAME" --deleted -o none
    made "Incompatible App Gateway $AGW_NAME removed"
  else
    found "App Gateway $AGW_NAME"
  fi
fi
if ! exists az network application-gateway show -g "$RG" -n "$AGW_NAME"; then
  AGW_DELEGATION_COUNT=$(az network vnet subnet show -g "$RG" --vnet-name "$VNET" \
    -n "$SUBNET_AGW" \
    --query "delegations[?serviceName=='Microsoft.Network/applicationGateways'] | length(@)" \
    -o tsv)
  if [ "${AGW_DELEGATION_COUNT:-0}" -gt 0 ]; then
    az network vnet subnet update -g "$RG" --vnet-name "$VNET" \
      -n "$SUBNET_AGW" --remove delegations -o none
    made "Network-isolation delegation removed from $SUBNET_AGW"
  fi
  # Private Link is associated with the static private frontend; the public
  # frontend keeps this gateway out of the incompatible network-isolation mode.
  az network application-gateway create -g "$RG" -n "$AGW_NAME" -l "$LOCATION" \
    --sku WAF_v2 --capacity 2 \
    --vnet-name "$VNET" --subnet "$SUBNET_AGW" \
    --public-ip-address "$AGW_PUBLIC_IP" \
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
if exists az network application-gateway probe show -g "$RG" --gateway-name "$AGW_NAME" -n "$AGW_PROBE"; then
  found "Health probe $AGW_PROBE"
else
  az network application-gateway probe create \
    -g "$RG" --gateway-name "$AGW_NAME" -n "$AGW_PROBE" \
    --protocol Https --host "${API_APP}.azurewebsites.net" \
    --path "/" --interval 30 --timeout 30 --threshold 3 -o none
  made "Health probe $AGW_PROBE created"
fi

# Backend HTTP settings: HTTPS:443, preserve App Service hostname, attach probe.
az network application-gateway http-settings update \
  -g "$RG" --gateway-name "$AGW_NAME" -n appGatewayBackendHttpSettings \
  --protocol Https --port 443 --host-name-from-backend-pool true \
  --probe "$AGW_PROBE" -o none
made "Backend HTTP settings updated (HTTPS + probe)"

say "Application Gateway Private Link: $AGW_PRIVATE_LINK"
AGW_FRONTEND_NAME=$(az network application-gateway frontend-ip list \
  -g "$RG" --gateway-name "$AGW_NAME" \
  --query "[?privateIPAddress=='${AGW_PRIVATE_IP}'].name | [0]" -o tsv)
if [ -z "$AGW_FRONTEND_NAME" ]; then
  printf 'ERROR: No Application Gateway frontend uses private IP %s.\n' "$AGW_PRIVATE_IP" >&2
  exit 1
fi
AGW_LISTENER_NAME=$(az network application-gateway http-listener list \
  -g "$RG" --gateway-name "$AGW_NAME" --query "[0].name" -o tsv)
if [ -z "$AGW_LISTENER_NAME" ]; then
  printf 'ERROR: Application Gateway %s has no HTTP listener to bind to its private frontend.\n' "$AGW_NAME" >&2
  exit 1
fi
az network application-gateway http-listener update \
  -g "$RG" --gateway-name "$AGW_NAME" -n "$AGW_LISTENER_NAME" \
  --frontend-ip "$AGW_FRONTEND_NAME" -o none
made "Listener $AGW_LISTENER_NAME bound to private frontend $AGW_FRONTEND_NAME"
if az network application-gateway private-link list \
    -g "$RG" --gateway-name "$AGW_NAME" \
    --query "[?name=='${AGW_PRIVATE_LINK}'] | length(@)" -o tsv | grep -q '^1$'; then
  found "Application Gateway Private Link $AGW_PRIVATE_LINK"
else
  AGW_PL_SUBNET_ID=$(az network vnet subnet show -g "$RG" --vnet-name "$VNET" \
    -n "$SUBNET_AGW_PL" --query id -o tsv)
  az network application-gateway private-link add \
    -g "$RG" --gateway-name "$AGW_NAME" \
    -n "$AGW_PRIVATE_LINK" --frontend-ip "$AGW_FRONTEND_NAME" \
    --subnet "$AGW_PL_SUBNET_ID" -o none
  made "Application Gateway Private Link $AGW_PRIVATE_LINK created"
fi
waitmsg "App Gateway $AGW_NAME Private Link configuration to finish provisioning"
az network application-gateway wait -g "$RG" -n "$AGW_NAME" --updated -o none

# App Service access restriction: only accept inbound from the AGW subnet.
# Requires Microsoft.Web service endpoint on snet-agw so the subnet-based rule
# can match traffic from the AGW (without this the rule never fires -> default deny -> 502).
az network vnet subnet update -g "$RG" --vnet-name "$VNET" -n "$SUBNET_AGW" \
  --service-endpoints Microsoft.Web -o none
made "Microsoft.Web service endpoint enabled on $SUBNET_AGW"

if az webapp config access-restriction show -g "$RG" -n "$API_APP" \
    --query "ipSecurityRestrictions[?name=='${APP_ACCESS_RULE}']" -o tsv 2>/dev/null | grep -q .; then
  found "App Service access restriction $APP_ACCESS_RULE"
else
  az webapp config access-restriction add -g "$RG" -n "$API_APP" \
    --rule-name "$APP_ACCESS_RULE" --action Allow --priority 100 \
    --vnet-name "$VNET" --subnet "$SUBNET_AGW" -o none
  made "App Service access restriction: allow $SUBNET_AGW only"
fi
# Also lock the SCM (Kudu) endpoint — prevents direct public access to the deploy API.
if az webapp config access-restriction show -g "$RG" -n "$API_APP" --scm-site true \
    --query "ipSecurityRestrictions[?name=='${SCM_ACCESS_RULE}']" -o tsv 2>/dev/null | grep -q .; then
  found "App Service SCM access restriction $SCM_ACCESS_RULE"
else
  az webapp config access-restriction add -g "$RG" -n "$API_APP" --scm-site true \
    --rule-name "$SCM_ACCESS_RULE" --action Allow --priority 100 \
    --vnet-name "$VNET" --subnet "$SUBNET_AGW" -o none
  made "App Service SCM access restriction: allow $SUBNET_AGW only"
fi

say "Azure Front Door Premium profile: $AFD_PROFILE"
if exists az afd profile show -g "$RG" -n "$AFD_PROFILE"; then
  found "Front Door profile $AFD_PROFILE"
else
  az afd profile create -g "$RG" -n "$AFD_PROFILE" \
    --sku Premium_AzureFrontDoor -o none
  made "Front Door Premium profile $AFD_PROFILE created"
fi

say "Azure Front Door endpoint: $AFD_ENDPOINT"
if exists az afd endpoint show -g "$RG" --profile-name "$AFD_PROFILE" -n "$AFD_ENDPOINT"; then
  found "Front Door endpoint $AFD_ENDPOINT"
else
  az afd endpoint create -g "$RG" --profile-name "$AFD_PROFILE" \
    -n "$AFD_ENDPOINT" --enabled-state Enabled -o none
  made "Front Door endpoint $AFD_ENDPOINT created"
fi

say "Azure Front Door origin group: $AFD_ORIGIN_GROUP"
if exists az afd origin-group show -g "$RG" --profile-name "$AFD_PROFILE" \
    -n "$AFD_ORIGIN_GROUP"; then
  found "Front Door origin group $AFD_ORIGIN_GROUP"
else
  az afd origin-group create -g "$RG" --profile-name "$AFD_PROFILE" \
    -n "$AFD_ORIGIN_GROUP" \
    --probe-request-type GET --probe-protocol Http \
    --probe-path "/" --probe-interval-in-seconds 60 \
    --sample-size 4 --successful-samples-required 3 \
    --additional-latency-in-milliseconds 50 -o none
  made "Front Door origin group $AFD_ORIGIN_GROUP created"
fi

say "Azure Front Door private origin: $AGW_NAME"
AGW_ID=$(az network application-gateway show -g "$RG" -n "$AGW_NAME" --query id -o tsv)
if exists az afd origin show -g "$RG" --profile-name "$AFD_PROFILE" \
    --origin-group-name "$AFD_ORIGIN_GROUP" -n "$AFD_ORIGIN"; then
  found "Front Door origin $AFD_ORIGIN"
else
  az afd origin create -g "$RG" --profile-name "$AFD_PROFILE" \
    --origin-group-name "$AFD_ORIGIN_GROUP" -n "$AFD_ORIGIN" \
    --enabled-state Enabled \
    --host-name "$AGW_PRIVATE_IP" \
    --origin-host-header "${API_APP}.azurewebsites.net" \
    --http-port 80 --https-port 443 --priority 1 --weight 500 \
    --shared-private-link-resource \
      group-id="$AGW_FRONTEND_NAME" \
      private-link="{id:$AGW_ID}" \
      private-link-location="$LOCATION" \
      request-message="Azure Front Door private connectivity request." \
      status=Pending -o none
  made "Front Door private origin $AFD_ORIGIN created"
fi

say "Approve Azure Front Door private endpoint on $AGW_NAME"
AFD_PRIVATE_ENDPOINT_ID=""
for _ in {1..30}; do
  AFD_PRIVATE_ENDPOINT_ID=$(az network private-endpoint-connection list \
    --name "$AGW_NAME" -g "$RG" --type Microsoft.Network/applicationgateways \
    --query "[?properties.privateLinkServiceConnectionState.status=='Pending'].id | [0]" -o tsv)
  [ -n "$AFD_PRIVATE_ENDPOINT_ID" ] && break
  AFD_PRIVATE_ENDPOINT_STATUS=$(az network private-endpoint-connection list \
    --name "$AGW_NAME" -g "$RG" --type Microsoft.Network/applicationgateways \
    --query "[0].properties.privateLinkServiceConnectionState.status" -o tsv)
  [ "$AFD_PRIVATE_ENDPOINT_STATUS" = "Approved" ] && break
  sleep 10
done
if [ -n "$AFD_PRIVATE_ENDPOINT_ID" ]; then
  az network private-endpoint-connection approve \
    --id "$AFD_PRIVATE_ENDPOINT_ID" \
    --description "Approved for Azure Front Door Premium." -o none
  made "Azure Front Door private endpoint approved"
elif [ "${AFD_PRIVATE_ENDPOINT_STATUS:-}" = "Approved" ]; then
  found "Azure Front Door private endpoint already approved"
else
  printf 'ERROR: Front Door private endpoint request was not created within 5 minutes.\n' >&2
  exit 1
fi

say "Azure Front Door route: $AFD_ROUTE"
if exists az afd route show -g "$RG" --profile-name "$AFD_PROFILE" \
    --endpoint-name "$AFD_ENDPOINT" -n "$AFD_ROUTE"; then
  found "Front Door route $AFD_ROUTE"
else
  # Front Door terminates HTTPS and uses the gateway's existing HTTP listener.
  az afd route create -g "$RG" --profile-name "$AFD_PROFILE" \
    --endpoint-name "$AFD_ENDPOINT" -n "$AFD_ROUTE" \
    --origin-group "$AFD_ORIGIN_GROUP" \
    --supported-protocols Http Https --https-redirect Enabled \
    --forwarding-protocol HttpOnly --link-to-default-domain Enabled -o none
  made "Front Door route $AFD_ROUTE created"
fi

say "NSG for VM (VNet-internal protection): $VM_NSG"
if exists az network nsg show -g "$RG" -n "$VM_NSG"; then
  found "NSG $VM_NSG"
else
  az network nsg create -g "$RG" -n "$VM_NSG" -l "$LOCATION" -o none
  made "NSG $VM_NSG created"
fi
# Allow outbound HTTP + HTTPS for web access from the VM.
if exists az network nsg rule show -g "$RG" --nsg-name "$VM_NSG" -n "$NSG_WEB_RULE"; then
  found "NSG rule $NSG_WEB_RULE"
else
  az network nsg rule create -g "$RG" --nsg-name "$VM_NSG" \
    -n "$NSG_WEB_RULE" --priority 200 \
    --destination-port-ranges 80 443 --protocol Tcp \
    --access Allow --direction Outbound -o none
  made "NSG rule $NSG_WEB_RULE created (TCP 80 + 443 outbound)"
fi

say "Active VM -- Windows Server 2022, in $SUBNET_WORKLOAD: $VM_NAME"
if exists az vm show -g "$RG" -n "$VM_NAME"; then
  found "VM $VM_NAME"
else
  az vm create -g "$RG" -n "$VM_NAME" -l "$LOCATION" \
    --computer-name "$VM_COMPUTER_NAME" \
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
AFD_HOSTNAME=$(az afd endpoint show -g "$RG" --profile-name "$AFD_PROFILE" \
  -n "$AFD_ENDPOINT" --query hostName -o tsv)
echo "Front Door URL: https://${AFD_HOSTNAME}"
echo "App Gateway private frontend IP: ${AGW_PRIVATE_IP} (Front Door connects through Private Link)"
echo "VM:           private only (no public IP) -- use Bastion or VPN to connect"
echo "API app URL:  https://${API_APP}.azurewebsites.net (accessible via AGW only)"
