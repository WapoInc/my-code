BASH


Set the resource group context (if you're working with a specific resource group): Azure CLI does not have a built-in context set for resource groups, but you can define your resource group in each command or as an environment variable:

export AZURE_RG="<Your-Resource-Group-Name>"

az login
az account show --output table
az account list --output table
az account set --subscription "<Subscription-ID-or-Name>"


# Define variables
RESOURCE_GROUP="ER-LTSA-RG"
LOCATION="southafricanorth"
CIRCUIT_NAME="ER-Created-by-code"
SERVICE_PROVIDER="Teraco"   # Replace with your provider
BANDWIDTH="50"              # ExpressRoute bandwidth in Mbps
SKU="Standard"               # Options: Standard, Premium
PEERING_LOCATION="Johannesburg"  # Check with provider for available locations


# Create ExpressRoute Circuit
az network express-route create \
  --name $CIRCUIT_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --bandwidth $BANDWIDTH \
  --provider $SERVICE_PROVIDER \
  --peering-location $PEERING_LOCATION \
  --sku-tier $SKU

# Output ExpressRoute Circuit details
az network express-route show \
  --name $CIRCUIT_NAME \
  --resource-group $RESOURCE_GROUP \
  --output table
