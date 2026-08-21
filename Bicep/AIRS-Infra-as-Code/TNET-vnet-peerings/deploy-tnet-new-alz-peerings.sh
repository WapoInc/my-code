#!/usr/bin/env bash
set -Eeuo pipefail

SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-b628c9d5-8a2c-4e24-ba7f-6a8921f9179a}"
LOCATION="${LOCATION:-southafricanorth}"
DEPLOYMENT_NAME="${DEPLOYMENT_NAME:-tnet-new-alz-peerings}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE_FILE="${TEMPLATE_FILE:-$SCRIPT_DIR/tnet-new-alz-peerings.bicep}"
PARAM_FILE="${PARAM_FILE:-$SCRIPT_DIR/tnet-new-alz-peerings.bicepparam}"

fail() {
	printf 'ERROR: %s\n' "$*" >&2
	exit 1
}

command -v az >/dev/null 2>&1 || fail "Azure CLI is not installed."
[[ -f "$TEMPLATE_FILE" ]] || fail "Template '$TEMPLATE_FILE' not found."
[[ -f "$PARAM_FILE" ]] || fail "Parameter file '$PARAM_FILE' not found."

az account show --subscription "$SUBSCRIPTION_ID" --output none 2>/dev/null \
	|| fail "Sign in with 'az login' and ensure access to subscription '$SUBSCRIPTION_ID'."

az deployment sub what-if \
	--name "$DEPLOYMENT_NAME" \
	--location "$LOCATION" \
	--subscription "$SUBSCRIPTION_ID" \
	--template-file "$TEMPLATE_FILE" \
	--parameters "$PARAM_FILE"

az deployment sub create \
	--name "$DEPLOYMENT_NAME" \
	--location "$LOCATION" \
	--subscription "$SUBSCRIPTION_ID" \
	--template-file "$TEMPLATE_FILE" \
	--parameters "$PARAM_FILE" \
	--output table

printf '\nDeployment %s complete.\n' "$DEPLOYMENT_NAME"
