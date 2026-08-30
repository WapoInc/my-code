#!/usr/bin/env bash
#
# Deploys storage account + blob/file private endpoints into southafricanorth.
#
# Usage:
#   ./infra_deploy.sh                 # deploy
#   ./infra_deploy.sh --what-if       # preview changes only
#   ./infra_deploy.sh --validate      # validate template only
#
# Overridable via environment variables:
#   SUBSCRIPTION_ID, RG, LOCATION, VNET_NAME, VNET_RG, SUBNET_NAME, SUBNET_PREFIX,
#   STORAGE_ACCOUNT_NAME, TEMPLATE_FILE
#
set -euo pipefail

# ---------------------------------------------------------------- config ----
SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-}"
RG="${RG:-southafricanorth-region}"
LOCATION="${LOCATION:-southafricanorth}"
VNET_NAME="${VNET_NAME:-southafricanorth-vnet}"
VNET_RG="${VNET_RG:-$RG}"
SUBNET_NAME="${SUBNET_NAME:-Priv-end-points}"
SUBNET_PREFIX="${SUBNET_PREFIX:-10.10.4.0/24}"
STORAGE_ACCOUNT_NAME="${STORAGE_ACCOUNT_NAME:-litstorageacc1}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="${TEMPLATE_FILE:-$SCRIPT_DIR/main.bicep}"
DEPLOYMENT_NAME="stg-pe-$(date -u +%Y%m%d-%H%M%S)"

MODE="deploy"
case "${1:-}" in
  --what-if)  MODE="what-if" ;;
  --validate) MODE="validate" ;;
  "")         ;;
  *) echo "Unknown argument: $1" >&2; exit 1 ;;
esac

# --------------------------------------------------------------- helpers ----
log()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

# ------------------------------------------------------------ preflight -----
log "Preflight checks"

command -v az >/dev/null 2>&1 || die "Azure CLI not found. https://aka.ms/azure-cli"
az bicep version >/dev/null 2>&1 || { warn "Installing Bicep CLI..."; az bicep install; }

[[ -f "$TEMPLATE_FILE" ]] || die "Template not found: $TEMPLATE_FILE"

az account show >/dev/null 2>&1 || die "Not logged in. Run 'az login' first."

if [[ -n "$SUBSCRIPTION_ID" ]]; then
  az account set --subscription "$SUBSCRIPTION_ID"
fi
echo "Subscription : $(az account show --query name -o tsv)"
echo "Resource grp : $RG ($LOCATION)"
echo "VNet/Subnet  : $VNET_NAME / $SUBNET_NAME (rg: $VNET_RG)"
echo "Storage      : $STORAGE_ACCOUNT_NAME"

# storage account name must be globally unique
AVAILABLE=$(az storage account check-name --name "$STORAGE_ACCOUNT_NAME" \
  --query nameAvailable -o tsv)
if [[ "$AVAILABLE" != "true" ]]; then
  if az storage account show -n "$STORAGE_ACCOUNT_NAME" -g "$RG" >/dev/null 2>&1; then
    warn "Storage account '$STORAGE_ACCOUNT_NAME' already exists in $RG — will be updated."
  else
    die "Storage account name '$STORAGE_ACCOUNT_NAME' is taken by another tenant. Choose another."
  fi
fi

# ------------------------------------------------------- resource group -----
log "Ensuring resource group '$RG'"
az group create -n "$RG" -l "$LOCATION" -o none

# ------------------------------------------------------------- network -----
log "Validating VNet and subnet"
az network vnet show -g "$VNET_RG" -n "$VNET_NAME" -o none 2>/dev/null \
  || die "VNet '$VNET_NAME' not found in resource group '$VNET_RG'."

if ! az network vnet subnet show -g "$VNET_RG" --vnet-name "$VNET_NAME" -n "$SUBNET_NAME" -o none 2>/dev/null; then
  log "Creating subnet '$SUBNET_NAME' ($SUBNET_PREFIX)"
  az network vnet subnet create -g "$VNET_RG" --vnet-name "$VNET_NAME" -n "$SUBNET_NAME" \
    --address-prefixes "$SUBNET_PREFIX" --private-endpoint-network-policies Disabled -o none
fi

POLICY=$(az network vnet subnet show -g "$VNET_RG" --vnet-name "$VNET_NAME" -n "$SUBNET_NAME" \
  --query privateEndpointNetworkPolicies -o tsv)

if [[ "$POLICY" != "Disabled" ]]; then
  log "Disabling private endpoint network policies on '$SUBNET_NAME'"
  az network vnet subnet update -g "$VNET_RG" --vnet-name "$VNET_NAME" -n "$SUBNET_NAME" \
    --private-endpoint-network-policies Disabled -o none
else
  echo "Private endpoint network policies already disabled."
fi

# -------------------------------------------------------------- deploy -----
COMMON_ARGS=(
  --resource-group "$RG"
  --template-file "$TEMPLATE_FILE"
  --parameters location="$LOCATION"
               vnetName="$VNET_NAME"
               vnetResourceGroupName="$VNET_RG"
               subnetName="$SUBNET_NAME"
               storageAccountName="$STORAGE_ACCOUNT_NAME"
)

case "$MODE" in
  validate)
    log "Validating deployment"
    az deployment group validate "${COMMON_ARGS[@]}" -o table
    exit 0
    ;;
  what-if)
    log "Running what-if (no changes applied)"
    az deployment group what-if "${COMMON_ARGS[@]}"
    exit 0
    ;;
esac

log "Deploying '$DEPLOYMENT_NAME'"
az deployment group create --name "$DEPLOYMENT_NAME" "${COMMON_ARGS[@]}" -o none

# ------------------------------------------------------------- results -----
log "Deployment complete"

az deployment group show -g "$RG" -n "$DEPLOYMENT_NAME" \
  --query properties.outputs -o json

echo
log "Private endpoint IP assignments"
for SUB in blob file; do
  PE="pe-${STORAGE_ACCOUNT_NAME}-${SUB}"
  NIC_ID=$(az network private-endpoint show -g "$RG" -n "$PE" \
    --query 'networkInterfaces[0].id' -o tsv 2>/dev/null || true)
  if [[ -n "$NIC_ID" ]]; then
    IP=$(az network nic show --ids "$NIC_ID" \
      --query 'ipConfigurations[0].privateIPAddress' -o tsv)
    printf '  %-40s %s\n' "${STORAGE_ACCOUNT_NAME}.${SUB}.core.windows.net" "$IP"
  else
    warn "Could not resolve NIC for $PE"
  fi
done

cat <<EOF

Next steps
----------
From a VM inside '$VNET_NAME', confirm DNS resolves to the private IPs above:

  nslookup ${STORAGE_ACCOUNT_NAME}.blob.core.windows.net
  nslookup ${STORAGE_ACCOUNT_NAME}.file.core.windows.net

Public network access is disabled, so data-plane calls from outside the
VNet (including this shell) will fail with AuthorizationFailure / 403.
EOF