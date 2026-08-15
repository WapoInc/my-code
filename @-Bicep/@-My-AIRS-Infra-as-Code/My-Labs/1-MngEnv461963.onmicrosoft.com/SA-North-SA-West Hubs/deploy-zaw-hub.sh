#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="$SCRIPT_DIR/ZAW-Hub-resources-rg.bicep"

# --- Selectable deployment regions ---
region_options=(
  "southafricanorth"
  "southafricawest"
  "westeurope"
  "northeurope"
  "uksouth"
  "ukwest"
)

# --- Selectable subscriptions (label | subscription id | tenant id) ---
subscription_labels=(
  "MngEnv461963 (5cba78fe tenant)"
  "MngEnvMCAP056429 (b91a5236 tenant)"
  "MngEnvMCAP158201 (2b8e427b tenant)"
)
subscription_ids=(
  "0cfd0d2a-2b38-4c93-ba14-cf79185bc683"
  "29df7078-c53c-4638-81c1-e4bc8566d423"
  "2ac21ef0-69db-49ec-a554-2cac36ec75f4"
)
subscription_tenants=(
  "5cba78fe-cc40-479a-9ee1-255423641bc9"
  "b91a5236-cd06-4bc7-889b-db71c19230ae"
  "2b8e427b-9e78-4589-9338-f870c84292ca"
)

if ! command -v az >/dev/null 2>&1; then
  echo "Azure CLI is not installed or is not in PATH." >&2
  exit 1
fi

echo
echo "Select the Azure subscription for this deployment:"
PS3="Enter selection (1-${#subscription_ids[@]}): "

selected_index=""
select selected_label in "${subscription_labels[@]}" "Cancel"; do
  if [[ "$selected_label" == "Cancel" ]]; then
    echo "Deployment cancelled."
    exit 0
  fi

  if [[ -n "$selected_label" && "$REPLY" =~ ^[0-9]+$ ]] && (( REPLY <= ${#subscription_ids[@]} )); then
    selected_index=$((REPLY - 1))
    break
  fi

  echo "Invalid selection. Choose a number from 1 to $((${#subscription_ids[@]} + 1))."
done

selected_subscription_id="${subscription_ids[$selected_index]}"
selected_tenant_id="${subscription_tenants[$selected_index]}"

echo
echo "Select the deployment region:"
PS3="Enter selection (1-${#region_options[@]}): "

LOCATION=""
select selected_region in "${region_options[@]}" "Cancel"; do
  if [[ "$selected_region" == "Cancel" ]]; then
    echo "Deployment cancelled."
    exit 0
  fi

  if [[ -n "$selected_region" && "$REPLY" =~ ^[0-9]+$ ]] && (( REPLY <= ${#region_options[@]} )); then
    LOCATION="$selected_region"
    break
  fi

  echo "Invalid selection. Choose a number from 1 to $((${#region_options[@]} + 1))."
done

ADMIN_PASSWORD="P@ssw0rd123!"

# --- Prompt for ZAW-Hub-resources-rg.bicep parameters (Enter accepts default) ---
read -r -p "Resource group name [${LOCATION}-region]: " RESOURCE_GROUP_NAME
RESOURCE_GROUP_NAME="${RESOURCE_GROUP_NAME:-${LOCATION}-region}"

read -r -p "Create ExpressRoute connection? (true/false) [true]: " DEPLOY_ER_CONNECTION
DEPLOY_ER_CONNECTION="${DEPLOY_ER_CONNECTION:-true}"

# ExpressRoute circuit is fixed to where it actually lives, independent of the
# chosen deployment subscription/region.
CIRCUIT_NAME="ER-LTSA-SA-West"
CIRCUIT_RESOURCE_GROUP_NAME="ER-LTSA-rg"
CIRCUIT_SUBSCRIPTION_ID="0cfd0d2a-2b38-4c93-ba14-cf79185bc683"

echo
echo "Deployment target:"
echo "  Subscription:   ${subscription_labels[$selected_index]}"
echo "  ID:             $selected_subscription_id"
echo "  Tenant:         $selected_tenant_id"
echo "  Location:       $LOCATION"
echo "  Resource grp:   $RESOURCE_GROUP_NAME"
echo "  ER connection:  $DEPLOY_ER_CONNECTION"
echo "  ER circuit:     $CIRCUIT_NAME (rg: $CIRCUIT_RESOURCE_GROUP_NAME)"
echo "  ER circuit sub: $CIRCUIT_SUBSCRIPTION_ID"
echo "  Template:       $TEMPLATE_FILE"
echo

read -r -p "Continue with this subscription? [y/N] " confirmation
if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
  echo "Deployment cancelled."
  exit 0
fi

# Ensure signed in to the correct tenant and that the subscription is visible.
if ! az account show --subscription "$selected_subscription_id" >/dev/null 2>&1; then
  echo "Signing in to tenant $selected_tenant_id..."
  az login --tenant "$selected_tenant_id" >/dev/null
fi

az account set --subscription "$selected_subscription_id"

# The circuit's subscription always lives in this tenant.
CIRCUIT_TENANT_ID="5cba78fe-cc40-479a-9ee1-255423641bc9"

AUTHORIZATION_KEY=""
if [[ "$DEPLOY_ER_CONNECTION" == "true" ]]; then
  if [[ "$CIRCUIT_TENANT_ID" == "$selected_tenant_id" ]]; then
    echo "ER gateway and circuit are in the same tenant - using the standard ExpressRoute connection (no authorization key)."
  else
    ER_GW_NAME="ER-GateWay-${LOCATION}-Standard"
    AUTH_NAME="AuthKey-to-${ER_GW_NAME}"
    echo "ER gateway and circuit are in different tenants - creating authorization '$AUTH_NAME' on circuit $CIRCUIT_NAME..."

    # Access the circuit's subscription (sign in to its tenant if needed).
    if ! az account show --subscription "$CIRCUIT_SUBSCRIPTION_ID" >/dev/null 2>&1; then
      echo "Signing in to the circuit's tenant ($CIRCUIT_TENANT_ID)..."
      az login --tenant "$CIRCUIT_TENANT_ID" >/dev/null
    fi

    # Create the authorization (reuse the key if it already exists).
    AUTHORIZATION_KEY="$(az network express-route auth create \
      -g "$CIRCUIT_RESOURCE_GROUP_NAME" --circuit-name "$CIRCUIT_NAME" \
      -n "$AUTH_NAME" --subscription "$CIRCUIT_SUBSCRIPTION_ID" \
      --query authorizationKey -o tsv 2>/dev/null || true)"
    if [[ -z "$AUTHORIZATION_KEY" ]]; then
      AUTHORIZATION_KEY="$(az network express-route auth show \
        -g "$CIRCUIT_RESOURCE_GROUP_NAME" --circuit-name "$CIRCUIT_NAME" \
        -n "$AUTH_NAME" --subscription "$CIRCUIT_SUBSCRIPTION_ID" \
        --query authorizationKey -o tsv 2>/dev/null || true)"
    fi

    # Return to the deployment subscription.
    az account set --subscription "$selected_subscription_id"

    if [[ -z "$AUTHORIZATION_KEY" ]]; then
      echo "Could not create or read the authorization key - skipping the ExpressRoute connection." >&2
      DEPLOY_ER_CONNECTION="false"
    else
      echo "Authorization key '$AUTH_NAME' obtained."
    fi
  fi
fi

az deployment sub create \
  --name "zaw-hub-$(date -u +%Y%m%d-%H%M%S)" \
  --location "$LOCATION" \
  --template-file "$TEMPLATE_FILE" \
  --parameters \
    adminPassword="$ADMIN_PASSWORD" \
    location="$LOCATION" \
    resourceGroupName="$RESOURCE_GROUP_NAME" \
    deployExpressRouteConnection="$DEPLOY_ER_CONNECTION" \
    circuitName="$CIRCUIT_NAME" \
    circuitResourceGroupName="$CIRCUIT_RESOURCE_GROUP_NAME" \
    circuitSubscriptionId="$CIRCUIT_SUBSCRIPTION_ID" \
    authorizationKey="$AUTHORIZATION_KEY" \
  --subscription "$selected_subscription_id"
