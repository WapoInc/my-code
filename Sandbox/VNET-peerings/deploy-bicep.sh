#!/usr/bin/env bash
set -Eeuo pipefail

SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-0cfd0d2a-2b38-4c93-ba14-cf79185bc683}"
RESOURCE_GROUP="${RESOURCE_GROUP:-za-east-southafricanorth}"
TEMPLATE_FILE="${TEMPLATE_FILE:-$(cd "$(dirname "$0")" && pwd)/main.bicep}"
DEPLOYMENT_NAME="${DEPLOYMENT_NAME:-vnet-peering-spoke-5-6-$(date +%Y%m%d%H%M%S)}"

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

az deployment group what-if \
	--subscription "$SUBSCRIPTION_ID" \
	--resource-group "$RESOURCE_GROUP" \
	--name "$DEPLOYMENT_NAME" \
	--template-file "$TEMPLATE_FILE"

az deployment group create \
	--subscription "$SUBSCRIPTION_ID" \
	--resource-group "$RESOURCE_GROUP" \
	--name "$DEPLOYMENT_NAME" \
	--template-file "$TEMPLATE_FILE" \
	--output table

printf '\nDeployment %s complete.\n' "$DEPLOYMENT_NAME"
printf 'Ensure the site-to-site VPN and on-premises router have return routes for the spoke CIDRs.\n'
