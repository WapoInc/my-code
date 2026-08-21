#!/usr/bin/env bash
set -euo pipefail

# ---- Configuration ----
RESOURCE_GROUP="vmr-WebApp"
LOCATION="southafricanorth"
TEMPLATE_FILE="main.bicep"
WEB_APP_NAME_PREFIX="wapoinc-webapp"
WEB_APP_NAME="${WEB_APP_NAME:-}"
CUSTOM_DOMAINS=("wapoinc.tech" "www.wapoinc.tech" "802dot1x.net" "www.802dot1x.net")
APP_SERVICE_PLAN_SKU="B1"

# ---- Login check ----
if ! az account show >/dev/null 2>&1; then
  echo "Not logged in to Azure. Running 'az login'..."
  az login
fi

if [[ -z "$WEB_APP_NAME" ]]; then
  SUBSCRIPTION_ID=$(az account show --query id --output tsv)
  WEB_APP_NAME="${WEB_APP_NAME_PREFIX}-${SUBSCRIPTION_ID:0:8}"
fi
echo "Using globally unique Web App name '$WEB_APP_NAME'."

# ---- Create resource group ----
echo "Creating resource group '$RESOURCE_GROUP' in '$LOCATION'..."
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION"

# ---- Validate the Bicep template ----
echo "Validating Bicep template..."
az deployment group validate \
  --resource-group "$RESOURCE_GROUP" \
  --template-file "$TEMPLATE_FILE" \
  --parameters webAppName="$WEB_APP_NAME" location="$LOCATION" appServicePlanSkuName="$APP_SERVICE_PLAN_SKU"

# ---- Deploy the Bicep template ----
echo "Deploying Bicep template with App Service Plan SKU '$APP_SERVICE_PLAN_SKU'..."
az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file "$TEMPLATE_FILE" \
  --parameters webAppName="$WEB_APP_NAME" location="$LOCATION" appServicePlanSkuName="$APP_SERVICE_PLAN_SKU" \
  --name "wapoinc-deployment-$(date +%Y%m%d%H%M%S)"

# ---- Configure custom domains and managed certificates ----
for hostname in "${CUSTOM_DOMAINS[@]}"; do
  HOSTNAME_EXISTS=$(az webapp config hostname list \
    --resource-group "$RESOURCE_GROUP" \
    --webapp-name "$WEB_APP_NAME" \
    --query "length([?name=='$hostname'])" --output tsv)

  if [[ "$HOSTNAME_EXISTS" == "0" ]]; then
    echo "Adding custom hostname '$hostname'..."
    az webapp config hostname add \
      --resource-group "$RESOURCE_GROUP" \
      --webapp-name "$WEB_APP_NAME" \
      --hostname "$hostname"
  fi

  SSL_STATE=$(az webapp config hostname list \
    --resource-group "$RESOURCE_GROUP" \
    --webapp-name "$WEB_APP_NAME" \
    --query "[?name=='$hostname'].sslState | [0]" --output tsv)

  if [[ "$SSL_STATE" != "SniEnabled" ]]; then
    CERTIFICATE_NAME="${WEB_APP_NAME}-${hostname//./-}"
    THUMBPRINT=$(az webapp config ssl list \
      --resource-group "$RESOURCE_GROUP" \
      --query "[?subjectName=='$hostname'].thumbprint | [0]" --output tsv)

    if [[ -z "$THUMBPRINT" ]]; then
      if ! az webapp config ssl show \
        --resource-group "$RESOURCE_GROUP" \
        --certificate-name "$CERTIFICATE_NAME" \
        --output none 2>/dev/null; then
        echo "Creating free managed certificate for '$hostname'..."
        az webapp config ssl create \
          --resource-group "$RESOURCE_GROUP" \
          --name "$WEB_APP_NAME" \
          --hostname "$hostname" \
          --certificate-name "$CERTIFICATE_NAME" \
          --output none
      fi

      echo "Waiting for managed certificate '$CERTIFICATE_NAME'..."
      ATTEMPT=0
      while [[ -z "$THUMBPRINT" && "$ATTEMPT" -lt 30 ]]; do
        THUMBPRINT=$(az webapp config ssl show \
          --resource-group "$RESOURCE_GROUP" \
          --certificate-name "$CERTIFICATE_NAME" \
          --query thumbprint --output tsv 2>/dev/null || true)
        ATTEMPT=$((ATTEMPT + 1))
        if [[ -z "$THUMBPRINT" ]]; then
          sleep 10
        fi
      done

      if [[ -z "$THUMBPRINT" ]]; then
        echo "Managed certificate '$CERTIFICATE_NAME' did not finish provisioning within 5 minutes." >&2
        exit 1
      fi
    fi

    echo "Binding managed certificate to '$hostname' with SNI..."
    az webapp config ssl bind \
      --resource-group "$RESOURCE_GROUP" \
      --name "$WEB_APP_NAME" \
      --hostname "$hostname" \
      --certificate-thumbprint "$THUMBPRINT" \
      --ssl-type SNI
  fi
done

az webapp update \
  --resource-group "$RESOURCE_GROUP" \
  --name "$WEB_APP_NAME" \
  --https-only true \
  --output none

# ---- Deploy home page content ----
echo "Deploying home page content..."
SITE_TMP_DIR=$(mktemp -d -t wapoinc-site)
SITE_ZIP="$SITE_TMP_DIR/site.zip"
trap 'rm -rf "$SITE_TMP_DIR"' EXIT
(cd "$(dirname "$0")" && zip -q "$SITE_ZIP" index.html ieee-8021x.jpg 802dot1x-logo-transparent.png)
az webapp deploy \
  --resource-group "$RESOURCE_GROUP" \
  --name "$WEB_APP_NAME" \
  --src-path "$SITE_ZIP" \
  --type zip
rm -rf "$SITE_TMP_DIR"
trap - EXIT

# ---- Restart the Web App ----
echo "Restarting Web App '$WEB_APP_NAME'..."
az webapp restart \
  --resource-group "$RESOURCE_GROUP" \
  --name "$WEB_APP_NAME"

# ---- Output results ----
echo ""
echo "Deployment complete. Fetching Web App details..."
DEFAULT_HOST=$(az webapp show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$WEB_APP_NAME" \
  --query defaultHostName --output tsv)

VERIFICATION_ID=$(az webapp show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$WEB_APP_NAME" \
  --query customDomainVerificationId --output tsv)

INBOUND_IP=$(az webapp show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$WEB_APP_NAME" \
  --query inboundIpAddress --output tsv)

echo "-------------------------------------------------"
echo "Default hostname:            $DEFAULT_HOST"
echo "Domain verification ID (TXT): $VERIFICATION_ID"
echo "Inbound IP (A record):        $INBOUND_IP"
echo "-------------------------------------------------"
echo "HTTPS enabled for:           ${CUSTOM_DOMAINS[*]}"