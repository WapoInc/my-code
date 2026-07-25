#!/usr/bin/env bash
###############################################################################
# South Africa North HLD deployment
#
#   [ active VM ] --> [ App Gateway (WAF) ] --> [ Storage static website ]
#
# IDEMPOTENT: every resource is checked first. If it already exists the script
# prints [FOUND] and skips creation.
#
# Run:   chmod +x deploy-san-hld-no-Appservice-noWebApp.sh && ./deploy-san-hld-no-Appservice-noWebApp.sh
# Needs: az CLI >= 2.55, logged in (az login), correct subscription selected.
###############################################################################
set -euo pipefail

###############################################################################
# 0. CORE SETTINGS  -- edit these
###############################################################################
LOCATION="southafricanorth"
SUBSCRIPTION=""                       # optional; leave "" to use current default
RG="mneu-rg-prod-mrk-001-v2"

###############################################################################
# 1. RESOURCE NAMES
###############################################################################
AGW_NAME="mneu-agw-prod-mrk-001-v2"
STORAGE_ACCT="mneustprodmkt001v2"       # hosts the Hello Shemo static website
VM_NAME="mneu-vm-prod-mrk-001-v2"

###############################################################################
# 2. NETWORKING
###############################################################################
VNET="mneu-vnet-prod-mrk-001-v2"
VNET_CIDR="10.20.0.0/16"
SUBNET_AGW="snet-agw";       SUBNET_AGW_CIDR="10.20.1.0/24"   # App Gateway
SUBNET_WORKLOAD="snet-workload"; SUBNET_WORKLOAD_CIDR="10.20.4.0/24"  # VM
AGW_PRIVATE_IP="10.20.1.10"
WAF_POLICY="mneu-wafpol-prod-mrk-001-v2"

###############################################################################
# 3. VM
###############################################################################
VM_SIZE="Standard_B2s"
VM_IMAGE="Win2022Datacenter"
VM_ADMIN="adminroot"
VM_ADMIN_PASSWORD='P@ssw0rd123!'
VM_PIP="mneu-pip-vm-prod-mrk-001-v2"
VM_NSG="mneu-nsg-vm-prod-mrk-001-v2"
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

say "Subnet: $SUBNET_WORKLOAD (VM)"
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

###############################################################################
# STORAGE: create account, enable static website, upload page, lock firewall
###############################################################################
say "Storage account: $STORAGE_ACCT"
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

STORAGE_KEY=$(az storage account keys list -g "$RG" -n "$STORAGE_ACCT" \
  --query "[0].value" -o tsv)

say "Enable static website on $STORAGE_ACCT"
az storage blob service-properties update \
  --account-name "$STORAGE_ACCT" --account-key "$STORAGE_KEY" \
  --static-website --index-document index.html --404-document index.html -o none
made "Static website enabled"

say "Upload index.html to \$web"
cat > /tmp/poc-index.html <<'HTML'
<!DOCTYPE html>
<html lang="en"><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Hello Shemo</title>
<style>
  body { margin:0; height:100vh; display:flex; align-items:center;
         justify-content:center; font-family:system-ui,sans-serif;
         background:#0b1a2b; color:#fff; }
  h1 { font-size:clamp(2rem,8vw,5rem); }
</style>
</head><body>
  <h1>Hello Shemo</h1>
</body></html>
HTML
# Temporarily open firewall so this script (running outside the VNet) can upload
az storage account update -g "$RG" -n "$STORAGE_ACCT" --default-action Allow -o none
az storage blob upload \
  --account-name "$STORAGE_ACCT" --account-key "$STORAGE_KEY" \
  -c '$web' -f /tmp/poc-index.html -n index.html \
  --content-type "text/html" --overwrite -o none
rm -f /tmp/poc-index.html
made "index.html uploaded"

# Get the static website FQDN (needed for AGW backend)
STATIC_SITE_URL=$(az storage account show -g "$RG" -n "$STORAGE_ACCT" \
  --query "primaryEndpoints.web" -o tsv)
STATIC_SITE_FQDN=$(echo "$STATIC_SITE_URL" | sed 's|https://||;s|/||')
made "Static site FQDN: $STATIC_SITE_FQDN"

say "Storage firewall: allow only AGW + VM subnets"
# Microsoft.Storage service endpoint on both subnets so traffic goes via Azure backbone
az network vnet subnet update -g "$RG" --vnet-name "$VNET" -n "$SUBNET_AGW" \
  --service-endpoints Microsoft.Storage -o none
az network vnet subnet update -g "$RG" --vnet-name "$VNET" -n "$SUBNET_WORKLOAD" \
  --service-endpoints Microsoft.Storage -o none
az storage account network-rule add -g "$RG" --account-name "$STORAGE_ACCT" \
  --vnet-name "$VNET" --subnet "$SUBNET_AGW" -o none
az storage account network-rule add -g "$RG" --account-name "$STORAGE_ACCT" \
  --vnet-name "$VNET" --subnet "$SUBNET_WORKLOAD" -o none
az storage account update -g "$RG" -n "$STORAGE_ACCT" \
  --default-action Deny --bypass AzureServices -o none
made "Storage firewall: allow $SUBNET_AGW + $SUBNET_WORKLOAD only"

###############################################################################
# APP GATEWAY: private frontend, backend = storage static website
###############################################################################
say "Application Gateway (WAF_v2, PRIVATE frontend -> Storage static site): $AGW_NAME"
if exists az network application-gateway show -g "$RG" -n "$AGW_NAME"; then
  found "App Gateway $AGW_NAME"
else
  az network application-gateway create -g "$RG" -n "$AGW_NAME" -l "$LOCATION" \
    --sku WAF_v2 --capacity 2 \
    --vnet-name "$VNET" --subnet "$SUBNET_AGW" \
    --private-ip-address "$AGW_PRIVATE_IP" \
    --waf-policy "$WAF_POLICY" \
    --servers "$STATIC_SITE_FQDN" \
    --priority 100 -o none
  made "App Gateway $AGW_NAME created"
fi
waitmsg "App Gateway $AGW_NAME to finish provisioning"
az network application-gateway wait -g "$RG" -n "$AGW_NAME" --created -o none

# Health probe: HTTPS to the storage static website FQDN
if exists az network application-gateway probe show -g "$RG" --gateway-name "$AGW_NAME" -n agw-storage-probe; then
  found "Health probe agw-storage-probe"
else
  az network application-gateway probe create \
    -g "$RG" --gateway-name "$AGW_NAME" -n agw-storage-probe \
    --protocol Https --host "$STATIC_SITE_FQDN" \
    --path "/" --interval 30 --timeout 30 --threshold 3 -o none
  made "Health probe agw-storage-probe created"
fi

# Backend HTTP settings: HTTPS:443, host header = storage FQDN, attach probe
az network application-gateway http-settings update \
  -g "$RG" --gateway-name "$AGW_NAME" -n appGatewayBackendHttpSettings \
  --protocol Https --port 443 --host-name-from-backend-pool true \
  --probe agw-storage-probe -o none
made "Backend HTTP settings: HTTPS:443 -> $STATIC_SITE_FQDN"

# Update backend pool to current storage FQDN (idempotent on re-runs)
az network application-gateway address-pool update \
  -g "$RG" --gateway-name "$AGW_NAME" -n appGatewayBackendPool \
  --servers "$STATIC_SITE_FQDN" -o none
made "Backend pool updated to $STATIC_SITE_FQDN"

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
    --computer-name "mneu-vm-v2" \
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
echo "Static site:  ${STATIC_SITE_URL}  (served via AGW -> Hello Shemo)"
