#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DEPLOYMENT_NAME="${DEPLOYMENT_NAME:-tnalz01-remediation}"
TEST_DEPLOYMENT_NAME="${TEST_DEPLOYMENT_NAME:-tnalz01-test-env}"
LOCATION="${LOCATION:-southafricanorth}"
DEPLOY_FIREWALL="${DEPLOY_FIREWALL:-true}"

if ! command -v az >/dev/null 2>&1; then
  echo "Error: Azure CLI (az) is not installed or is not on PATH." >&2
  exit 1
fi

if ! az account show >/dev/null 2>&1; then
  echo "Error: Not signed in to Azure CLI. Run 'az login' first." >&2
  exit 1
fi

SUBSCRIPTION_ID="$(az account show --query id --output tsv)"

echo "Using active subscription: $SUBSCRIPTION_ID"
echo "Deploying the baseline test environment..."

az deployment sub create \
  --name "$TEST_DEPLOYMENT_NAME" \
  --location "$LOCATION" \
  --template-file "$SCRIPT_DIR/test/test-environment.bicep" \
  --parameters deployFirewall="$DEPLOY_FIREWALL" \
  --confirm-with-what-if

echo "Applying the route-table remediation..."
az deployment sub create \
  --name "$DEPLOYMENT_NAME" \
  --location "$LOCATION" \
  --template-file "$SCRIPT_DIR/main.bicep" \
  --confirm-with-what-if \
  "$@"
