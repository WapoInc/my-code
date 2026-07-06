#!/bin/bash
# Deploy "Hello WapoInc" behind Azure Front Door (Standard), with two
# load-balanced origins in one origin group ("backend pool"):
#   1. A Linux App Service (WebApp)
#   2. An Ubuntu VM running Apache
#
# NOTE: Azure Front Door (classic) stopped accepting new profile creation
# on 2025-03-31, so this uses Azure Front Door Standard (`az afd ...`),
# the current supported tier. Its "origin group" is the direct successor
# to classic Front Door's "backend pool" concept used here.
#
# Every step below checks whether its resource already exists and skips
# creation if so, so the script is safe to re-run after a partial failure.
set -euo pipefail

# ─── Shared Variables ────────────────────────────────────────────────────────
RG="rg-wapoinc-v2"
LOCATION="southafricanorth"
# Deterministic suffix (not $RANDOM) so re-running the script targets the
# same WebApp / Front Door endpoint names instead of creating new ones.
SUFFIX=$(az account show --query id -o tsv | tr -d '-' | cut -c1-8)

# WebApp
APP_PLAN="plan-wapoinc"
APP_NAME="app-wapoinc-$SUFFIX"
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
AFD_ENDPOINT="wapoinc-$SUFFIX"   # must be globally unique
AFD_ORIGIN_GROUP="og-wapoinc"    # backend pool equivalent
AFD_ORIGIN_WEBAPP="origin-webapp"
AFD_ORIGIN_VM="origin-vm"
AFD_ROUTE="route-wapoinc"

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
if az group show --name "$RG" &>/dev/null; then
  echo "Resource group $RG already exists — skipping."
else
  echo "Creating resource group: $RG"
  az group create \
    --name "$RG" \
    --location "$LOCATION" \
    --output table
fi

# ─── VNet + Subnet ───────────────────────────────────────────────────────────
if az network vnet show --resource-group "$RG" --name "$VNET_NAME" &>/dev/null; then
  echo "VNet $VNET_NAME already exists — skipping."
else
  echo "Creating VNet: $VNET_NAME"
  az network vnet create \
    --name "$VNET_NAME" \
    --resource-group "$RG" \
    --location "$LOCATION" \
    --address-prefix "10.0.0.0/16" \
    --subnet-name "$SUBNET_NAME" \
    --subnet-prefix "10.0.1.0/24" \
    --output table
fi

# ─── Public IP for VM ────────────────────────────────────────────────────────
if az network public-ip show --resource-group "$RG" --name "$PUBLIC_IP_NAME" &>/dev/null; then
  echo "Public IP $PUBLIC_IP_NAME already exists — skipping."
else
  echo "Creating public IP: $PUBLIC_IP_NAME"
  az network public-ip create \
    --name "$PUBLIC_IP_NAME" \
    --resource-group "$RG" \
    --location "$LOCATION" \
    --sku Standard \
    --allocation-method Static \
    --output table
fi

# ─── NSG with SSH + HTTP rules ───────────────────────────────────────────────
if az network nsg show --resource-group "$RG" --name "$NSG_NAME" &>/dev/null; then
  echo "NSG $NSG_NAME already exists — skipping."
else
  echo "Creating NSG: $NSG_NAME"
  az network nsg create \
    --name "$NSG_NAME" \
    --resource-group "$RG" \
    --location "$LOCATION" \
    --output table
fi

if az network nsg rule show --resource-group "$RG" --nsg-name "$NSG_NAME" --name "Allow-SSH" &>/dev/null; then
  echo "NSG rule Allow-SSH already exists — skipping."
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
fi

if az network nsg rule show --resource-group "$RG" --nsg-name "$NSG_NAME" --name "Allow-HTTP" &>/dev/null; then
  echo "NSG rule Allow-HTTP already exists — skipping."
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
fi

# ─── VM ──────────────────────────────────────────────────────────────────────
if az vm show --resource-group "$RG" --name "$VM_NAME" &>/dev/null; then
  echo "VM $VM_NAME already exists — skipping."
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

  echo "Creating VM: $VM_NAME"
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
fi

VM_PUBLIC_IP=$(az network public-ip show \
  --name "$PUBLIC_IP_NAME" \
  --resource-group "$RG" \
  --query "ipAddress" \
  --output tsv)

# ─── App Service Plan ────────────────────────────────────────────────────────
if az appservice plan show --resource-group "$RG" --name "$APP_PLAN" &>/dev/null; then
  echo "App Service Plan $APP_PLAN already exists — skipping."
else
  echo "Creating App Service Plan: $APP_PLAN"
  az appservice plan create \
    --name "$APP_PLAN" \
    --resource-group "$RG" \
    --location "$LOCATION" \
    --sku "$SKU_APP" \
    --is-linux \
    --output table
fi

# ─── Web App ─────────────────────────────────────────────────────────────────
if az webapp show --resource-group "$RG" --name "$APP_NAME" &>/dev/null; then
  echo "Web App $APP_NAME already exists — skipping create."
else
  echo "Creating Web App: $APP_NAME"
  az webapp create \
    --name "$APP_NAME" \
    --resource-group "$RG" \
    --plan "$APP_PLAN" \
    --runtime "$RUNTIME" \
    --output table
fi

# ─── Deploy HTML page to Web App via Node static server ────────────────────
# Always (re)deploy so the page content stays current even if the app exists.
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

echo "Deploying WapoInc page to Web App via ZIP deploy..."
az webapp deploy \
  --name "$APP_NAME" \
  --resource-group "$RG" \
  --src-path "$ZIP_PATH" \
  --type zip \
  --output table

rm -rf "$TMPDIR_APP"

WEBAPP_HOSTNAME=$(az webapp show \
  --name "$APP_NAME" \
  --resource-group "$RG" \
  --query "defaultHostName" \
  --output tsv)

# ─── Azure Front Door (Standard) ─────────────────────────────────────────────
if az afd profile show --resource-group "$RG" --profile-name "$AFD_PROFILE" &>/dev/null; then
  echo "Front Door profile $AFD_PROFILE already exists — skipping."
else
  echo "Creating Front Door profile: $AFD_PROFILE"
  az afd profile create \
    --resource-group "$RG" \
    --profile-name "$AFD_PROFILE" \
    --sku Standard_AzureFrontDoor \
    --output table
fi

if az afd endpoint show --resource-group "$RG" --profile-name "$AFD_PROFILE" --endpoint-name "$AFD_ENDPOINT" &>/dev/null; then
  echo "Front Door endpoint $AFD_ENDPOINT already exists — skipping."
else
  echo "Creating Front Door endpoint: $AFD_ENDPOINT"
  az afd endpoint create \
    --resource-group "$RG" \
    --profile-name "$AFD_PROFILE" \
    --endpoint-name "$AFD_ENDPOINT" \
    --enabled-state Enabled \
    --output table
fi

if az afd origin-group show --resource-group "$RG" --profile-name "$AFD_PROFILE" --origin-group-name "$AFD_ORIGIN_GROUP" &>/dev/null; then
  echo "Origin group $AFD_ORIGIN_GROUP already exists — skipping."
else
  echo "Creating origin group (backend pool): $AFD_ORIGIN_GROUP"
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
fi

if az afd origin show --resource-group "$RG" --profile-name "$AFD_PROFILE" --origin-group-name "$AFD_ORIGIN_GROUP" --origin-name "$AFD_ORIGIN_WEBAPP" &>/dev/null; then
  echo "Origin $AFD_ORIGIN_WEBAPP already exists — skipping."
else
  echo "Adding Web App as an origin: $AFD_ORIGIN_WEBAPP"
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
fi

if az afd origin show --resource-group "$RG" --profile-name "$AFD_PROFILE" --origin-group-name "$AFD_ORIGIN_GROUP" --origin-name "$AFD_ORIGIN_VM" &>/dev/null; then
  echo "Origin $AFD_ORIGIN_VM already exists — skipping."
else
  echo "Adding Ubuntu VM as an origin: $AFD_ORIGIN_VM"
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
fi

if az afd route show --resource-group "$RG" --profile-name "$AFD_PROFILE" --endpoint-name "$AFD_ENDPOINT" --route-name "$AFD_ROUTE" &>/dev/null; then
  echo "Route $AFD_ROUTE already exists — skipping."
else
  echo "Creating route: $AFD_ROUTE"
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
echo "Waiting for Front Door endpoint https://$AFD_HOSTNAME/ to go live..."
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

# ─── Output ──────────────────────────────────────────────────────────────────
echo ""
echo "==========================================="
if [ "$FD_READY" = true ]; then
  echo " Deployment complete! Front Door is live."
else
  echo " Deployment complete, but Front Door hadn't gone live after 20 minutes."
  echo " This can happen after back-to-back config changes (up to 40 min)."
  echo " Re-check with: curl -I https://$AFD_HOSTNAME/"
fi
echo " Front Door URL : https://$AFD_HOSTNAME"
echo "   (backend pool load-balances between the WebApp and the VM)"
echo " Web App URL    : https://$WEBAPP_HOSTNAME"
echo " VM Public IP   : http://$VM_PUBLIC_IP"
echo " SSH to VM      : ssh $ADMIN_USER@$VM_PUBLIC_IP"
echo "==========================================="
