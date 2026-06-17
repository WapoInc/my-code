#!/usr/bin/env bash
#
# demo-storage-service-endpoints.sh
# -----------------------------------------------------------------------------
# Demonstrates restricting access to an Azure Storage account using VNet
# SERVICE ENDPOINTS (Microsoft.Storage).
#
# What it builds:
#   - Resource group
#   - VNet + subnet with the Microsoft.Storage service endpoint enabled
#   - Storage account whose firewall denies all traffic EXCEPT:
#       * the subnet above (via the service endpoint)
#       * your current public IP (so you can still manage/verify it)
#   - A container + test blob (proves the allowed path works)
#   - (optional) A Windows test VM inside the subnet that proves access works
#     from inside the VNet via the service endpoint, while it is denied
#     everywhere else.
#
# Requires: az CLI logged in (`az login`) with rights to create resources,
#           plus openssl and curl on the machine running this script.
#
# Run:      chmod +x demo-storage-service-endpoints.sh
#           ./demo-storage-service-endpoints.sh
# -----------------------------------------------------------------------------

set -euo pipefail

############################################
# Configuration  (edit as needed)
############################################
LOCATION="southafricanorth"
RG="rg-se-demo"

VNET="vnet-se-demo"
VNET_PREFIX="10.10.0.0/16"
SUBNET="snet-app"
SUBNET_PREFIX="10.10.1.0/24"

# Storage account names: globally unique, 3-24 chars, lowercase letters + digits.
RAND="$(openssl rand -hex 3)"
STORAGE="stsedemo${RAND}"
CONTAINER="demo"

# Windows test VM (set to false to skip it and only build the locked-down storage)
CREATE_VM=true
VM_NAME="vm-se-test"
VM_IMAGE="Win2022Datacenter"
VM_ADMIN="azureuser"
VM_SIZE="Standard_B2s"
# Windows password rules: 12-123 chars, 3 of {lower, upper, digit, symbol},
# and must not contain the admin username. You will be prompted for it below.

echo "==> Storage account name for this run: ${STORAGE}"

############################################
# 1. Resource group
############################################
echo "==> [1/6] Creating resource group ${RG} in ${LOCATION}"
az group create --name "$RG" --location "$LOCATION" --output none

############################################
# 2. VNet + subnet, then enable the storage service endpoint on the subnet
############################################
echo "==> [2/6] Creating VNet ${VNET} and subnet ${SUBNET}"
az network vnet create \
  --resource-group "$RG" \
  --name "$VNET" \
  --address-prefix "$VNET_PREFIX" \
  --subnet-name "$SUBNET" \
  --subnet-prefix "$SUBNET_PREFIX" \
  --output none

echo "==> Enabling the Microsoft.Storage service endpoint on ${SUBNET}"
az network vnet subnet update \
  --resource-group "$RG" \
  --vnet-name "$VNET" \
  --name "$SUBNET" \
  --service-endpoints Microsoft.Storage \
  --output none

############################################
# 3. Storage account
############################################
echo "==> [3/6] Creating storage account ${STORAGE}"
az storage account create \
  --resource-group "$RG" \
  --name "$STORAGE" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2 \
  --tags SecurityControl=Ignore \
  --output none

############################################
# 4. Network rules
#    IMPORTANT ORDER: add the ALLOW rules BEFORE flipping the default to Deny,
#    so you never lock yourself out of data-plane access mid-script.
############################################
echo "==> [4/6] Adding network rule: allow subnet ${SUBNET}"
az storage account network-rule add \
  --resource-group "$RG" \
  --account-name "$STORAGE" \
  --vnet-name "$VNET" \
  --subnet "$SUBNET" \
  --output none

MY_IP="$(curl -s https://api.ipify.org)"
echo "==> Adding network rule: allow your current public IP ${MY_IP}"
az storage account network-rule add \
  --resource-group "$RG" \
  --account-name "$STORAGE" \
  --ip-address "$MY_IP" \
  --output none

echo "==> Setting default action to Deny (and keeping trusted Azure services bypass)"
az storage account update \
  --resource-group "$RG" \
  --name "$STORAGE" \
  --default-action Deny \
  --bypass AzureServices \
  --output none

############################################
# 5. Verify the ALLOWED path works (from your whitelisted IP)
############################################
echo "==> [5/6] Verifying access from your allowed IP"
echo "    (network rules can take a minute or two to propagate)"
sleep 30

KEY="$(az storage account keys list -g "$RG" -n "$STORAGE" --query "[0].value" -o tsv)"

az storage container create \
  --account-name "$STORAGE" \
  --name "$CONTAINER" \
  --account-key "$KEY" \
  --output none

echo "hello from an allowed network" > /tmp/se-demo.txt
az storage blob upload \
  --account-name "$STORAGE" \
  --container-name "$CONTAINER" \
  --name test.txt \
  --file /tmp/se-demo.txt \
  --account-key "$KEY" \
  --overwrite \
  --output none

echo "    SUCCESS: container created and blob uploaded from your IP."

# ---- Negative test (manual) -------------------------------------------------
# To see the firewall actually deny you, remove your IP and retry a data op:
#
#   az storage account network-rule remove -g "$RG" --account-name "$STORAGE" --ip-address "$MY_IP"
#   az storage blob list --account-name "$STORAGE" --container-name "$CONTAINER" --account-key "$KEY"
#
# Expect HTTP 403 with error code "AuthorizationFailure" -> blocked by the
# network rule. Re-add your IP afterwards to keep managing the account.
# -----------------------------------------------------------------------------

############################################
# 6. (Optional) Prove access from INSIDE the subnet via the service endpoint
############################################
if [ "$CREATE_VM" = true ]; then
  echo "==> [6/6] Creating Windows test VM ${VM_NAME} inside ${SUBNET}"
  echo -n "    Enter an admin password for the Windows VM: "
  read -rs VM_PASSWORD
  echo ""

  az vm create \
    --resource-group "$RG" \
    --name "$VM_NAME" \
    --image "$VM_IMAGE" \
    --size "$VM_SIZE" \
    --admin-username "$VM_ADMIN" \
    --admin-password "$VM_PASSWORD" \
    --vnet-name "$VNET" \
    --subnet "$SUBNET" \
    --assign-identity \
    --public-ip-sku Standard \
    --output none

  echo "==> Granting the VM's managed identity 'Storage Blob Data Reader'"
  VM_PRINCIPAL="$(az vm identity show -g "$RG" -n "$VM_NAME" --query principalId -o tsv)"
  STORAGE_ID="$(az storage account show -g "$RG" -n "$STORAGE" --query id -o tsv)"
  az role assignment create \
    --assignee-object-id "$VM_PRINCIPAL" \
    --assignee-principal-type ServicePrincipal \
    --role "Storage Blob Data Reader" \
    --scope "$STORAGE_ID" \
    --output none

  echo "==> Waiting for role assignment + service endpoint to settle"
  sleep 60

  echo "==> Running an in-VM PowerShell test (managed identity -> Blob REST API)"
  # The script runs INSIDE the Windows VM. It:
  #   1. asks the Instance Metadata Service for a managed-identity token for storage
  #   2. calls the Blob "list container" REST API
  # From inside the subnet (service endpoint + allowed subnet rule) this succeeds.
  # From anywhere else it returns 403 AuthorizationFailure (blocked by the firewall).
  az vm run-command invoke \
    --resource-group "$RG" \
    --name "$VM_NAME" \
    --command-id RunPowerShellScript \
    --scripts \
      "\$ErrorActionPreference='Stop'" \
      "\$res='https://storage.azure.com/'" \
      "\$tok=(Invoke-RestMethod -Headers @{Metadata='true'} -Uri \"http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=\$res\").access_token" \
      "\$uri='https://${STORAGE}.blob.core.windows.net/${CONTAINER}?restype=container&comp=list'" \
      "try { \$r = Invoke-RestMethod -Uri \$uri -Headers @{ Authorization=\"Bearer \$tok\"; 'x-ms-version'='2021-08-06' }; Write-Output 'ACCESS ALLOWED - blob listing succeeded from inside the subnet:'; \$r.EnumerationResults.Blobs.Blob.Name } catch { Write-Output ('ACCESS BLOCKED - ' + \$_.Exception.Message) }" \
    --query "value[0].message" -o tsv

  echo ""
  echo "    'ACCESS ALLOWED' + test.txt  => the service endpoint path works."
  echo "    The same call from outside the subnet returns 403 (ACCESS BLOCKED)."
else
  echo "==> [6/6] Skipping VM demo (set CREATE_VM=true to enable it)"
fi

############################################
# Summary
############################################
echo ""
echo "============================================================"
echo " Done."
echo "   Resource group : ${RG}"
echo "   Storage account: ${STORAGE}"
echo "   Allowed subnet : ${VNET}/${SUBNET} (Microsoft.Storage endpoint)"
echo "   Allowed IP     : ${MY_IP}"
echo "   Default action : Deny"
echo "   Tag            : SecurityControl=Ignore"
echo ""
echo " Inspect the rules with:"
echo "   az storage account network-rule list -g ${RG} --account-name ${STORAGE} -o jsonc"
echo ""
echo " Tear everything down with:"
echo "   az group delete --name ${RG} --yes --no-wait"
echo "============================================================"
