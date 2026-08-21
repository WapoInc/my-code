#!/bin/bash
# Deploy "Hello WapoInc" behind Azure Front Door (Standard), with two
# load-balanced origins in one origin group ("backend pool"):
#   1. A Linux App Service (WebApp)
#   2. An Ubuntu VM running Apache
#
# v4 — Added: per-resource deployment prompts, start/end timestamps,
#       and elapsed time tracking for each resource.
#
# NOTE: Azure Front Door (classic) stopped accepting new profile creation
# on 2025-03-31, so this uses Azure Front Door Standard (`az afd ...`),
# the current supported tier. Its "origin group" is the direct successor
# to classic Front Door's "backend pool" concept used here.
#
# Every step below checks whether its resource already exists and skips
# creation if so, so the script is safe to re-run after a partial failure.
set -euo pipefail

# ─── Helper Functions ────────────────────────────────────────────────────────
timestamp() {
  date "+%Y-%m-%d %H:%M:%S"
}

elapsed_seconds() {
  local start_epoch=$1
  local end_epoch=$(date +%s)
  echo $((end_epoch - start_epoch))
}

format_duration() {
  local seconds=$1
  local minutes=$((seconds / 60))
  local remaining_seconds=$((seconds % 60))
  if [ "$minutes" -gt 0 ]; then
    echo "${minutes}m ${remaining_seconds}s"
  else
    echo "${remaining_seconds}s"
  fi
}

deploy_start() {
  local resource_type=$1
  local resource_name=$2
  echo ""
  echo "│ DEPLOYING: $resource_type"
  echo "│ Name:      $resource_name"
  echo "│ Started:   $(timestamp)"
  echo "└──────────────────────────────────────────────────────────────────────"
  date +%s
}

deploy_end() {
  local resource_type=$1
  local resource_name=$2
  local start_epoch=$3
  local status=$4
  local duration=$(elapsed_seconds "$start_epoch")
  local formatted=$(format_duration "$duration")
  echo "  ✓ $resource_type [$resource_name] — $status (took $formatted)"
  echo ""
}

# ─── Script Start ────────────────────────────────────────────────────────────
SCRIPT_START_TIME=$(timestamp)
SCRIPT_START_EPOCH=$(date +%s)

echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║        WapoInc Front Door Solution — Deployment Script v4              ║"
echo "╠══════════════════════════════════════════════════════════════════════════╣"
echo "║  Start Date/Time: $SCRIPT_START_TIME                          ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""

# ─── Shared Variables ────────────────────────────────────────────────────────
RG="rg-wapoinc-v4"
LOCATION="southafricanorth"
# Deterministic suffix (not $RANDOM) so re-running the script targets the
# same WebApp / Front Door endpoint names instead of creating new ones.
SUFFIX=$(az account show --query id -o tsv | tr -d '-' | cut -c1-8)

# WebApp
APP_PLAN="plan-wapoinc"
APP_NAME="app-${RG}-${SUFFIX}"   # tied to $RG so it can't collide with a WebApp
                                  # left over in a different resource group
SKU_APP="F1"                    # Free tier
RUNTIME="NODE:22-lts"

# VM
VM_NAME="vm-wapoinc-apache"
ADMIN_USER="azureuser"
VM_SIZE="Standard_B2s"
IMAGE="Ubuntu2404"
PUBLIC_IP_NAME="pip-wapoinc-vm"
NSG_NAME="nsg-wapoinc-vm"
VNET_NAME="vnet-wapoinc"
SUBNET_NAME="subnet-wapoinc"

# Azure Front Door (Standard)
AFD_PROFILE="afd-wapoinc"
AFD_ENDPOINT="${RG}-${SUFFIX}"   # tied to $RG so it can't collide with an
                                  # endpoint reserved by a different resource group
AFD_ORIGIN_GROUP="og-wapoinc"    # backend pool equivalent
AFD_ORIGIN_WEBAPP="origin-webapp"
AFD_ORIGIN_VM="origin-vm"
AFD_ROUTE="route-wapoinc"

echo "Configuration:"
echo "  Resource Group : $RG"
echo "  Location       : $LOCATION"
echo "  VM Name        : $VM_NAME"
echo "  Web App Name   : $APP_NAME"
echo "  Front Door     : $AFD_PROFILE"
echo ""

# ─── Shared HTML Content ─────────────────────────────────────────────────────
read -r -d '' HTML_CONTENT <<'HTML' || true
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>WapoInc</title>
  <style>
    body {
      display: flex;
      justify-content: center;
      align-items: center;
      height: 100vh;
      margin: 0;
      font-family: Arial, sans-serif;
      background: #fff;
    }
    h1 {
      color: blue;
      font-size: 40pt;
    }
  </style>
</head>
<body>
  <h1>Hello WapoInc</h1>
</body>
</html>
HTML

# ─── Resource Group ──────────────────────────────────────────────────────────
STEP_START=$(deploy_start "Resource Group" "$RG")
if az group show --name "$RG" &>/dev/null; then
  deploy_end "Resource Group" "$RG" "$STEP_START" "already exists — skipped"
else
  az group create \
    --name "$RG" \
    --location "$LOCATION" \
    --output table
  deploy_end "Resource Group" "$RG" "$STEP_START" "created"
fi

# ─── VNet + Subnet ───────────────────────────────────────────────────────────
STEP_START=$(deploy_start "Virtual Network + Subnet" "$VNET_NAME / $SUBNET_NAME")
if az network vnet show --resource-group "$RG" --name "$VNET_NAME" &>/dev/null; then
  deploy_end "Virtual Network" "$VNET_NAME" "$STEP_START" "already exists — skipped"
else
  az network vnet create \
    --name "$VNET_NAME" \
    --resource-group "$RG" \
    --location "$LOCATION" \
    --address-prefix "10.0.0.0/16" \
    --subnet-name "$SUBNET_NAME" \
    --subnet-prefix "10.0.1.0/24" \
    --output table
  deploy_end "Virtual Network" "$VNET_NAME" "$STEP_START" "created"
fi

# ─── Public IP for VM ────────────────────────────────────────────────────────
STEP_START=$(deploy_start "Public IP Address" "$PUBLIC_IP_NAME")
if az network public-ip show --resource-group "$RG" --name "$PUBLIC_IP_NAME" &>/dev/null; then
  deploy_end "Public IP" "$PUBLIC_IP_NAME" "$STEP_START" "already exists — skipped"
else
  az network public-ip create \
    --name "$PUBLIC_IP_NAME" \
    --resource-group "$RG" \
    --location "$LOCATION" \
    --sku Standard \
    --allocation-method Static \
    --output table
  deploy_end "Public IP" "$PUBLIC_IP_NAME" "$STEP_START" "created"
fi

# ─── NSG with SSH + HTTP rules ───────────────────────────────────────────────
STEP_START=$(deploy_start "Network Security Group" "$NSG_NAME")
if az network nsg show --resource-group "$RG" --name "$NSG_NAME" &>/dev/null; then
  deploy_end "NSG" "$NSG_NAME" "$STEP_START" "already exists — skipped"
else
  az network nsg create \
    --name "$NSG_NAME" \
    --resource-group "$RG" \
    --location "$LOCATION" \
    --output table
  deploy_end "NSG" "$NSG_NAME" "$STEP_START" "created"
fi

STEP_START=$(deploy_start "NSG Rule" "Allow-SSH (port 22)")
if az network nsg rule show --resource-group "$RG" --nsg-name "$NSG_NAME" --name "Allow-SSH" &>/dev/null; then
  deploy_end "NSG Rule" "Allow-SSH" "$STEP_START" "already exists — skipped"
else
  az network nsg rule create \
    --name "Allow-SSH" \
    --nsg-name "$NSG_NAME" \
    --resource-group "$RG" \
    --priority 1000 \
    --protocol Tcp \
    --direction Inbound \
    --source-address-prefixes "*" \
    --source-port-ranges "*" \
    --destination-address-prefixes "*" \
    --destination-port-ranges 22 \
    --access Allow \
    --output table
  deploy_end "NSG Rule" "Allow-SSH" "$STEP_START" "created"
fi

STEP_START=$(deploy_start "NSG Rule" "Allow-HTTP (port 80)")
if az network nsg rule show --resource-group "$RG" --nsg-name "$NSG_NAME" --name "Allow-HTTP" &>/dev/null; then
  deploy_end "NSG Rule" "Allow-HTTP" "$STEP_START" "already exists — skipped"
else
  az network nsg rule create \
    --name "Allow-HTTP" \
    --nsg-name "$NSG_NAME" \
    --resource-group "$RG" \
    --priority 1010 \
    --protocol Tcp \
    --direction Inbound \
    --source-address-prefixes "*" \
    --source-port-ranges "*" \
    --destination-address-prefixes "*" \
    --destination-port-ranges 80 \
    --access Allow \
    --output table
  deploy_end "NSG Rule" "Allow-HTTP" "$STEP_START" "created"
fi

# ─── VM ──────────────────────────────────────────────────────────────────────
STEP_START=$(deploy_start "Virtual Machine (Ubuntu + Apache)" "$VM_NAME [size: $VM_SIZE, image: $IMAGE]")
if az vm show --resource-group "$RG" --name "$VM_NAME" &>/dev/null; then
  deploy_end "VM" "$VM_NAME" "$STEP_START" "already exists — skipped"
else
  # Cloud-init for the VM: install Apache + deploy the HTML page
  TMPDIR_VM=$(mktemp -d)
  CLOUD_INIT="$TMPDIR_VM/cloud-init.sh"
  cat > "$CLOUD_INIT" <<EOF
#!/bin/bash
apt-get update -y
apt-get install -y apache2
cat > /var/www/html/index.html <<'HTMLPAGE'
$HTML_CONTENT
HTMLPAGE
systemctl enable apache2
systemctl restart apache2
EOF

  az vm create \
    --name "$VM_NAME" \
    --resource-group "$RG" \
    --location "$LOCATION" \
    --size "$VM_SIZE" \
    --image "$IMAGE" \
    --admin-username "$ADMIN_USER" \
    --generate-ssh-keys \
    --public-ip-address "$PUBLIC_IP_NAME" \
    --public-ip-sku Standard \
    --vnet-name "$VNET_NAME" \
    --subnet "$SUBNET_NAME" \
    --nsg "$NSG_NAME" \
    --custom-data "$CLOUD_INIT" \
    --output table

  rm -rf "$TMPDIR_VM"
  deploy_end "VM" "$VM_NAME" "$STEP_START" "created"
fi

VM_PUBLIC_IP=$(az network public-ip show \
  --name "$PUBLIC_IP_NAME" \
  --resource-group "$RG" \
  --query "ipAddress" \
  --output tsv)

# ─── App Service Plan ────────────────────────────────────────────────────────
STEP_START=$(deploy_start "App Service Plan" "$APP_PLAN [SKU: $SKU_APP, Linux]")
if az appservice plan show --resource-group "$RG" --name "$APP_PLAN" &>/dev/null; then
  deploy_end "App Service Plan" "$APP_PLAN" "$STEP_START" "already exists — skipped"
else
  az appservice plan create \
    --name "$APP_PLAN" \
    --resource-group "$RG" \
    --location "$LOCATION" \
    --sku "$SKU_APP" \
    --is-linux \
    --output table
  deploy_end "App Service Plan" "$APP_PLAN" "$STEP_START" "created"
fi

# ─── Web App ─────────────────────────────────────────────────────────────────
STEP_START=$(deploy_start "Web App" "$APP_NAME [runtime: $RUNTIME]")
if az webapp show --resource-group "$RG" --name "$APP_NAME" &>/dev/null; then
  deploy_end "Web App" "$APP_NAME" "$STEP_START" "already exists — skipped"
else
  az webapp create \
    --name "$APP_NAME" \
    --resource-group "$RG" \
    --plan "$APP_PLAN" \
    --runtime "$RUNTIME" \
    --output table
  deploy_end "Web App" "$APP_NAME" "$STEP_START" "created"
fi

# ─── Deploy HTML page to Web App via Node static server ────────────────────
STEP_START=$(deploy_start "Web App Code Deployment (ZIP)" "$APP_NAME")
TMPDIR_APP=$(mktemp -d)
cat > "$TMPDIR_APP/index.html" <<EOF
$HTML_CONTENT
EOF

cat > "$TMPDIR_APP/server.js" <<'EOF'
const http = require("http");
const fs   = require("fs");
const path = require("path");

const PORT = process.env.PORT || 8080;
const HTML  = fs.readFileSync(path.join(__dirname, "index.html"));

http.createServer((req, res) => {
  res.writeHead(200, { "Content-Type": "text/html" });
  res.end(HTML);
}).listen(PORT, () => console.log(`Listening on port ${PORT}`));
EOF

cat > "$TMPDIR_APP/package.json" <<'EOF'
{
  "name": "wapoinc-hello",
  "version": "1.0.0",
  "scripts": { "start": "node server.js" },
  "engines": { "node": ">=20" }
}
EOF

ZIP_PATH="$TMPDIR_APP/deploy.zip"
(cd "$TMPDIR_APP" && zip -r "$ZIP_PATH" index.html server.js package.json > /dev/null)

az webapp deploy \
  --name "$APP_NAME" \
  --resource-group "$RG" \
  --src-path "$ZIP_PATH" \
  --type zip \
  --output table

rm -rf "$TMPDIR_APP"
deploy_end "Web App ZIP Deploy" "$APP_NAME" "$STEP_START" "deployed"

WEBAPP_HOSTNAME=$(az webapp show \
  --name "$APP_NAME" \
  --resource-group "$RG" \
  --query "defaultHostName" \
  --output tsv)

# ─── Azure Front Door (Standard) ─────────────────────────────────────────────
STEP_START=$(deploy_start "Front Door Profile" "$AFD_PROFILE [SKU: Standard_AzureFrontDoor]")
if az afd profile show --resource-group "$RG" --profile-name "$AFD_PROFILE" &>/dev/null; then
  deploy_end "Front Door Profile" "$AFD_PROFILE" "$STEP_START" "already exists — skipped"
else
  az afd profile create \
    --resource-group "$RG" \
    --profile-name "$AFD_PROFILE" \
    --sku Standard_AzureFrontDoor \
    --output table
  deploy_end "Front Door Profile" "$AFD_PROFILE" "$STEP_START" "created"
fi

STEP_START=$(deploy_start "Front Door Endpoint" "$AFD_ENDPOINT")
if az afd endpoint show --resource-group "$RG" --profile-name "$AFD_PROFILE" --endpoint-name "$AFD_ENDPOINT" &>/dev/null; then
  deploy_end "Front Door Endpoint" "$AFD_ENDPOINT" "$STEP_START" "already exists — skipped"
else
  az afd endpoint create \
    --resource-group "$RG" \
    --profile-name "$AFD_PROFILE" \
    --endpoint-name "$AFD_ENDPOINT" \
    --enabled-state Enabled \
    --output table
  deploy_end "Front Door Endpoint" "$AFD_ENDPOINT" "$STEP_START" "created"
fi

STEP_START=$(deploy_start "Front Door Origin Group (Backend Pool)" "$AFD_ORIGIN_GROUP")
if az afd origin-group show --resource-group "$RG" --profile-name "$AFD_PROFILE" --origin-group-name "$AFD_ORIGIN_GROUP" &>/dev/null; then
  deploy_end "Origin Group" "$AFD_ORIGIN_GROUP" "$STEP_START" "already exists — skipped"
else
  az afd origin-group create \
    --resource-group "$RG" \
    --profile-name "$AFD_PROFILE" \
    --origin-group-name "$AFD_ORIGIN_GROUP" \
    --probe-request-type GET \
    --probe-protocol Http \
    --probe-path "/" \
    --probe-interval-in-seconds 30 \
    --sample-size 4 \
    --successful-samples-required 3 \
    --additional-latency-in-milliseconds 50 \
    --output table
  deploy_end "Origin Group" "$AFD_ORIGIN_GROUP" "$STEP_START" "created"
fi

STEP_START=$(deploy_start "Front Door Origin — Web App" "$AFD_ORIGIN_WEBAPP → $WEBAPP_HOSTNAME")
if az afd origin show --resource-group "$RG" --profile-name "$AFD_PROFILE" --origin-group-name "$AFD_ORIGIN_GROUP" --origin-name "$AFD_ORIGIN_WEBAPP" &>/dev/null; then
  deploy_end "Origin (WebApp)" "$AFD_ORIGIN_WEBAPP" "$STEP_START" "already exists — skipped"
else
  az afd origin create \
    --resource-group "$RG" \
    --profile-name "$AFD_PROFILE" \
    --origin-group-name "$AFD_ORIGIN_GROUP" \
    --origin-name "$AFD_ORIGIN_WEBAPP" \
    --host-name "$WEBAPP_HOSTNAME" \
    --origin-host-header "$WEBAPP_HOSTNAME" \
    --http-port 80 \
    --https-port 443 \
    --priority 1 \
    --weight 500 \
    --enabled-state Enabled \
    --output table
  deploy_end "Origin (WebApp)" "$AFD_ORIGIN_WEBAPP" "$STEP_START" "created"
fi

STEP_START=$(deploy_start "Front Door Origin — VM" "$AFD_ORIGIN_VM → $VM_PUBLIC_IP")
if az afd origin show --resource-group "$RG" --profile-name "$AFD_PROFILE" --origin-group-name "$AFD_ORIGIN_GROUP" --origin-name "$AFD_ORIGIN_VM" &>/dev/null; then
  deploy_end "Origin (VM)" "$AFD_ORIGIN_VM" "$STEP_START" "already exists — skipped"
else
  az afd origin create \
    --resource-group "$RG" \
    --profile-name "$AFD_PROFILE" \
    --origin-group-name "$AFD_ORIGIN_GROUP" \
    --origin-name "$AFD_ORIGIN_VM" \
    --host-name "$VM_PUBLIC_IP" \
    --origin-host-header "$VM_PUBLIC_IP" \
    --http-port 80 \
    --https-port 443 \
    --priority 1 \
    --weight 500 \
    --enabled-state Enabled \
    --output table
  deploy_end "Origin (VM)" "$AFD_ORIGIN_VM" "$STEP_START" "created"
fi

STEP_START=$(deploy_start "Front Door Route" "$AFD_ROUTE [protocols: Http/Https, forwarding: HttpOnly]")
if az afd route show --resource-group "$RG" --profile-name "$AFD_PROFILE" --endpoint-name "$AFD_ENDPOINT" --route-name "$AFD_ROUTE" &>/dev/null; then
  deploy_end "Route" "$AFD_ROUTE" "$STEP_START" "already exists — skipped"
else
  # Forwarding protocol is HttpOnly because the VM's Apache origin has no TLS
  # certificate; the client-facing endpoint still supports/redirects to HTTPS.
  az afd route create \
    --resource-group "$RG" \
    --profile-name "$AFD_PROFILE" \
    --endpoint-name "$AFD_ENDPOINT" \
    --route-name "$AFD_ROUTE" \
    --origin-group "$AFD_ORIGIN_GROUP" \
    --supported-protocols Http Https \
    --forwarding-protocol HttpOnly \
    --https-redirect Enabled \
    --link-to-default-domain Enabled \
    --output table
  deploy_end "Route" "$AFD_ROUTE" "$STEP_START" "created"
fi

AFD_HOSTNAME=$(az afd endpoint show \
  --resource-group "$RG" \
  --profile-name "$AFD_PROFILE" \
  --endpoint-name "$AFD_ENDPOINT" \
  --query "hostName" \
  --output tsv)

# ─── Wait for Front Door edge propagation ───────────────────────────────────
# New/changed Front Door config can take up to 20 minutes to reach the edge
# network (up to 40 minutes after back-to-back changes), so poll the live
# endpoint instead of just assuming it's ready.
echo ""
echo "│ WAITING: Front Door Edge Propagation"
echo "│ Endpoint: https://$AFD_HOSTNAME/"
echo "│ Started:  $(timestamp)"
echo "└──────────────────────────────────────────────────────────────────────"
PROP_START_EPOCH=$(date +%s)
FD_READY=false
MAX_ATTEMPTS=60
for i in $(seq 1 $MAX_ATTEMPTS); do
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "https://$AFD_HOSTNAME/" || true)
  if [ "$HTTP_CODE" = "200" ]; then
    echo "  [$i/$MAX_ATTEMPTS] HTTP $HTTP_CODE — Front Door is live."
    FD_READY=true
    break
  fi
  echo "  [$i/$MAX_ATTEMPTS] HTTP $HTTP_CODE — not ready yet, waiting 20s..."
  sleep 20
done
PROP_DURATION=$(elapsed_seconds "$PROP_START_EPOCH")
echo "  Propagation wait took: $(format_duration $PROP_DURATION)"

# ─── Script End & Summary ────────────────────────────────────────────────────
SCRIPT_END_TIME=$(timestamp)
SCRIPT_END_EPOCH=$(date +%s)
TOTAL_DURATION=$(( SCRIPT_END_EPOCH - SCRIPT_START_EPOCH ))
TOTAL_FORMATTED=$(format_duration $TOTAL_DURATION)

echo ""
echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║                    DEPLOYMENT SUMMARY                                   ║"
echo "╠══════════════════════════════════════════════════════════════════════════╣"
if [ "$FD_READY" = true ]; then
  echo "║  Status         : ✓ SUCCESS — Front Door is live                       ║"
else
  echo "║  Status         : ⚠ COMPLETE (Front Door not yet live after 20 min)    ║"
  printf "║%-74s║\n" "                   Re-check: curl -I https://$AFD_HOSTNAME/"
fi
echo "╠══════════════════════════════════════════════════════════════════════════╣"
echo "║  Start Date/Time : $SCRIPT_START_TIME                                    ║"
echo "║  End Date/Time   : $SCRIPT_END_TIME                                    ║"
echo "║  Total Duration  : $TOTAL_FORMATTED                                              ║"
echo "╠══════════════════════════════════════════════════════════════════════════╣"
echo "║  Resources Deployed:                                                    ║"
echo "║    • Resource Group : $RG"
echo "║    • VNet           : $VNET_NAME"
echo "║    • Public IP      : $PUBLIC_IP_NAME"
echo "║    • NSG            : $NSG_NAME"
echo "║    • VM             : $VM_NAME ($VM_SIZE)"
echo "║    • App Service    : $APP_PLAN ($SKU_APP)"
echo "║    • Web App        : $APP_NAME"
echo "║    • Front Door     : $AFD_PROFILE"
echo "║    • FD Endpoint    : $AFD_ENDPOINT"
echo "║    • Origin Group   : $AFD_ORIGIN_GROUP"
echo "║    • Origins        : $AFD_ORIGIN_WEBAPP, $AFD_ORIGIN_VM"
echo "║    • Route          : $AFD_ROUTE"
echo "╠══════════════════════════════════════════════════════════════════════════╣"
echo "║  Endpoints:                                                             ║"
echo "║    Front Door URL : https://$AFD_HOSTNAME"
echo "║      (backend pool load-balances between the WebApp and the VM)"
echo "║    Web App URL    : https://$WEBAPP_HOSTNAME"
echo "║    VM Public IP   : http://$VM_PUBLIC_IP"
echo "║    SSH to VM      : ssh $ADMIN_USER@$VM_PUBLIC_IP"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
