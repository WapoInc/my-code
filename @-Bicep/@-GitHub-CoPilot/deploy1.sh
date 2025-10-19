# Set variables
RESOURCE_GROUP="ubuntu-vm-rg"
LOCATION="southafricanorth"
ADMIN_PASSWORD="P@ssw0rd123!"

# Create resource group
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION

# Deploy the Bicep template
az deployment group create \
  --name ubuntu-vm-dep1 \
  --resource-group $RESOURCE_GROUP \
  --template-file vm-deployment.bicep \
  --parameters adminPassword="$ADMIN_PASSWORD" \
  --parameters adminUsername='rootadmin' \
  --parameters vmName='ubuntu-vm' \
  --parameters location='southafricanorth'

# Get the outputs
az deployment group show \
  --name ubuntu-vm-dep1 \
  --resource-group $RESOURCE_GROUP \
  --query properties.outputs