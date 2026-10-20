#!/usr/bin/env bash
set -Eeuo pipefail

SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-0cfd0d2a-2b38-4c93-ba14-cf79185bc683}"
RESOURCE_GROUP="${RESOURCE_GROUP:-za-east-southafricanorth}"
TEMPLATE_FILE="${TEMPLATE_FILE:-$(cd "$(dirname "$0")" && pwd)/main.bicep}"
DEPLOYMENT_NAME="${DEPLOYMENT_NAME:-vnet-peering-spoke-5-6-$(date +%Y%m%d%H%M%S)}"
KEY_VAULT_NAME="${KEY_VAULT_NAME:-hub-vpn-kv-0cfd0d2a}"
KEY_VAULT_RESOURCE_GROUP="${KEY_VAULT_RESOURCE_GROUP:-$RESOURCE_GROUP}"
VPN_PSK_SECRET_NAME="${VPN_PSK_SECRET_NAME:-vpn-shared-key}"
VM_PASSWORD_SECRET_NAME="${VM_PASSWORD_SECRET_NAME:-vm-admin-password}"

fail() {
	printf 'ERROR: %s\n' "$*" >&2
	exit 1
}

command -v az >/dev/null 2>&1 || fail "Azure CLI is not installed."
[[ -f "$TEMPLATE_FILE" ]] || fail "Template '$TEMPLATE_FILE' not found."

az account show --subscription "$SUBSCRIPTION_ID" --output none 2>/dev/null \
	|| fail "Sign in with 'az login' and ensure access to subscription '$SUBSCRIPTION_ID'."
az group show --subscription "$SUBSCRIPTION_ID" --name "$RESOURCE_GROUP" --output none 2>/dev/null \
	|| fail "Resource group '$RESOURCE_GROUP' does not exist."

KEY_VAULT_ID="$(az keyvault show \
	--subscription "$SUBSCRIPTION_ID" \
	--resource-group "$KEY_VAULT_RESOURCE_GROUP" \
	--name "$KEY_VAULT_NAME" \
	--query id --output tsv)" \
	|| fail "Unable to resolve Key Vault '$KEY_VAULT_NAME' in '$KEY_VAULT_RESOURCE_GROUP'."

set +x
IFS= read -r -s -p 'VM administrator password: ' VM_ADMIN_PASSWORD \
	|| fail "Unable to read VM administrator password."
printf '\n'
IFS= read -r -s -p 'Confirm VM administrator password: ' VM_ADMIN_PASSWORD_CONFIRM \
	|| fail "Unable to read password confirmation."
printf '\n'
[[ "$VM_ADMIN_PASSWORD" == "$VM_ADMIN_PASSWORD_CONFIRM" ]] || fail "Passwords do not match."
[[ ${#VM_ADMIN_PASSWORD} -ge 12 && ${#VM_ADMIN_PASSWORD} -le 72 ]] \
	|| fail "VM password must contain 12 to 72 characters."

printf '%s' "$VM_ADMIN_PASSWORD" | az keyvault secret set \
	--subscription "$SUBSCRIPTION_ID" \
	--vault-name "$KEY_VAULT_NAME" \
	--name "$VM_PASSWORD_SECRET_NAME" \
	--file /dev/stdin \
	--encoding utf-8 \
	--output none
unset VM_ADMIN_PASSWORD VM_ADMIN_PASSWORD_CONFIRM

VPN_PARAMETERS="$(printf '{"vpnSharedKey":{"reference":{"keyVault":{"id":"%s"},"secretName":"%s"}},"vmAdminPassword":{"reference":{"keyVault":{"id":"%s"},"secretName":"%s"}}}' \
	"$KEY_VAULT_ID" "$VPN_PSK_SECRET_NAME" "$KEY_VAULT_ID" "$VM_PASSWORD_SECRET_NAME")"

printf 'Using Key Vault secret %s/%s for vpnSharedKey.\n' "$KEY_VAULT_NAME" "$VPN_PSK_SECRET_NAME"
printf 'Using Key Vault secret %s/%s for vmAdminPassword.\n' "$KEY_VAULT_NAME" "$VM_PASSWORD_SECRET_NAME"

az deployment group what-if \
	--subscription "$SUBSCRIPTION_ID" \
	--resource-group "$RESOURCE_GROUP" \
	--name "$DEPLOYMENT_NAME" \
	--template-file "$TEMPLATE_FILE" \
	--parameters "$VPN_PARAMETERS"

az deployment group create \
	--subscription "$SUBSCRIPTION_ID" \
	--resource-group "$RESOURCE_GROUP" \
	--name "$DEPLOYMENT_NAME" \
	--template-file "$TEMPLATE_FILE" \
	--parameters "$VPN_PARAMETERS" \
	--output table

printf '\nDeployment %s complete.\n' "$DEPLOYMENT_NAME"
printf 'The hub VPN gateway and FortiGate site-to-site VPN connection are provisioned.\n'
printf 'Ubuntu VMs are provisioned in the hub and both spokes; see deployment output vmConnectionDetails for addresses.\n'
printf 'Verify the tunnel is connected and the FortiGate has return routes for the hub and spoke CIDRs.\n'
