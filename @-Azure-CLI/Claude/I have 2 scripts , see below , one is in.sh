I have 2 scripts , see below , one is in uksouth , the other is in southafricanorth 

copy the expressroute connection creation section into the script that is for the southafricanorth region and adapt to that region,



#!/bin/bash

# Azure ExpressRoute Gateway and Ubuntu VM Configuration Script
# This script creates all necessary resources for an ExpressRoute gateway and Ubuntu VM

# Variables - Modify these as needed
RESOURCE_GROUP="Claude-rg4"
LOCATION="uksouth"
VNET_NAME="uksouth-vnet-azure-hub"
VNET_PREFIX="10.51.0.0/22"
GATEWAY_SUBNET_PREFIX="10.51.0.0/27"
INTERNAL_SUBNET_NAME="subnet-internal"
INTERNAL_SUBNET_PREFIX="10.51.1.0/24"
EXPRESSROUTE_GATEWAY_NAME="uksouth-ergw-azure-hub"
EXPRESSROUTE_GATEWAY_PIP_NAME="uksouth-pip-ergw-hub"

# VM Configuration
VM_NAME="uksouth-ubuntu2204-vm"
VM_SIZE="Standard_B2s"
ADMIN_USERNAME="azureuser"
IMAGE="Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest"
NIC_NAME="${VM_NAME}-nic"

# ExpressRoute Configuration
ER_RESOURCE_GROUP="ER-LTSA-RG"
ER_CIRCUIT_NAME="ER-LIT-SA-North"
ER_CONNECTION_NAME="${LOCATION}-er-conn"

echo "Starting Azure ExpressRoute Gateway and Ubuntu VM deployment..."
echo "================================================================"

# Create Resource Group
echo "Creating Resource Group..."
az group create \
    --name $RESOURCE_GROUP \
    --location $LOCATION

# Create Virtual Network
echo "Creating Virtual Network..."
az network vnet create \
    --resource-group $RESOURCE_GROUP \
    --name $VNET_NAME \
    --address-prefix $VNET_PREFIX \
    --location $LOCATION

# Create Gateway Subnet (must be named 'GatewaySubnet')
echo "Creating Gateway Subnet..."
az network vnet subnet create \
    --resource-group $RESOURCE_GROUP \
    --vnet-name $VNET_NAME \
    --name GatewaySubnet \
    --address-prefix $GATEWAY_SUBNET_PREFIX

# Create Internal Subnet (for VMs/resources in Azure)
echo "Creating Internal Subnet..."
az network vnet subnet create \
    --resource-group $RESOURCE_GROUP \
    --vnet-name $VNET_NAME \
    --name $INTERNAL_SUBNET_NAME \
    --address-prefix $INTERNAL_SUBNET_PREFIX

# Create Public IP for ExpressRoute Gateway
echo "Creating Public IP for ExpressRoute Gateway..."
az network public-ip create \
    --resource-group $RESOURCE_GROUP \
    --name $EXPRESSROUTE_GATEWAY_PIP_NAME \
    --allocation-method Static \
    --sku Standard \
    --location $LOCATION

# Create ExpressRoute Gateway (This takes 30-45 minutes!)
echo "Creating ExpressRoute Gateway (this will take 30-45 minutes)..."
az network vnet-gateway create \
    --resource-group $RESOURCE_GROUP \
    --name $EXPRESSROUTE_GATEWAY_NAME \
    --vnet $VNET_NAME \
    --public-ip-address $EXPRESSROUTE_GATEWAY_PIP_NAME \
    --gateway-type ExpressRoute \
    --sku Standard \
    --location $LOCATION \
    --no-wait

# Create Network Interface for VM
echo "Creating Network Interface for Ubuntu VM..."
az network nic create \
    --resource-group $RESOURCE_GROUP \
    --name $NIC_NAME \
    --location $LOCATION \
    --subnet $INTERNAL_SUBNET_NAME \
    --vnet-name $VNET_NAME

# Create Ubuntu 22.04 VM
echo "Creating Ubuntu 22.04 VM..."
az vm create \
    --resource-group $RESOURCE_GROUP \
    --name $VM_NAME \
    --location $LOCATION \
    --nics $NIC_NAME \
    --size $VM_SIZE \
    --image $IMAGE \
    --admin-username $ADMIN_USERNAME \
    --generate-ssh-keys \
    --os-disk-name "${VM_NAME}-osdisk" \
    --os-disk-caching ReadWrite \
    --os-disk-size-gb 30 \
    --storage-sku Premium_LRS

# Configure Network Security Group for the VM
echo "Configuring Network Security Group..."
az network nsg rule create \
    --resource-group $RESOURCE_GROUP \
    --nsg-name "${NIC_NAME}NSG" \
    --name AllowSSH \
    --priority 1000 \
    --source-address-prefixes '*' \
    --destination-port-ranges 22 \
    --access Allow \
    --protocol Tcp \
    --description "Allow SSH access"

# Optional: Configure auto-shutdown to save costs
echo "Configuring auto-shutdown for VM (7 PM daily)..."
az vm auto-shutdown \
    --resource-group $RESOURCE_GROUP \
    --name $VM_NAME \
    --time 1900

# Wait for ExpressRoute Gateway to be provisioned
echo "Waiting for ExpressRoute Gateway to be fully provisioned..."
az network vnet-gateway wait \
    --resource-group $RESOURCE_GROUP \
    --name $EXPRESSROUTE_GATEWAY_NAME \
    --created

# Get ExpressRoute Gateway details
echo "Getting ExpressRoute Gateway details..."
az network vnet-gateway show \
    --resource-group $RESOURCE_GROUP \
    --name $EXPRESSROUTE_GATEWAY_NAME \
    --query "{Name:name, ProvisioningState:provisioningState, GatewayType:gatewayType, SKU:sku.name}" \
    --output table

# Get VM details
echo "Getting VM details..."
az vm show \
    --resource-group $RESOURCE_GROUP \
    --name $VM_NAME \
    --show-details \
    --query "{Name:name, PowerState:powerState, PrivateIP:privateIps, Size:hardwareProfile.vmSize, OS:storageProfile.osDisk.osType}" \
    --output table

# Get Private IP of the VM
PRIVATE_IP=$(az vm show -d \
    --resource-group $RESOURCE_GROUP \
    --name $VM_NAME \
    --query privateIps \
    --output tsv)

# Create ExpressRoute Connection
echo "Creating ExpressRoute Connection..."
echo "Getting ExpressRoute Circuit Resource ID..."

# Get the ExpressRoute circuit resource ID
ER_CIRCUIT_ID=$(az network express-route show \
    --resource-group $ER_RESOURCE_GROUP \
    --name $ER_CIRCUIT_NAME \
    --query id \
    --output tsv)

if [ -z "$ER_CIRCUIT_ID" ]; then
    echo "Error: Could not find ExpressRoute circuit $ER_CIRCUIT_NAME in resource group $ER_RESOURCE_GROUP"
    echo "Please verify the ExpressRoute circuit exists and is accessible."
    exit 1
fi

echo "ExpressRoute Circuit ID: $ER_CIRCUIT_ID"
echo "Creating connection $ER_CONNECTION_NAME..."

# Create the ExpressRoute connection
az network vpn-connection create \
    --name $ER_CONNECTION_NAME \
    --resource-group $RESOURCE_GROUP \
    --vnet-gateway1 $EXPRESSROUTE_GATEWAY_NAME \
    --express-route-circuit2 $ER_CIRCUIT_ID \
    --location $LOCATION

# Verify the connection was created successfully
echo "Verifying ExpressRoute connection..."
az network vpn-connection show \
    --resource-group $RESOURCE_GROUP \
    --name $ER_CONNECTION_NAME \
    --query "{Name:name, ProvisioningState:provisioningState, ConnectionStatus:connectionStatus, ExpressRouteCircuit:expressRouteGatewayBypass}" \
    --output table

echo ""
echo "================================================"
echo "Deployment Summary:"
echo "================================================"
echo "Resource Group: $RESOURCE_GROUP"
echo "Location: $LOCATION"
echo "Virtual Network: $VNET_NAME ($VNET_PREFIX)"
echo "ExpressRoute Gateway: $EXPRESSROUTE_GATEWAY_NAME"
echo "ExpressRoute Connection: $ER_CONNECTION_NAME"
echo "ExpressRoute Circuit: $ER_CIRCUIT_NAME (RG: $ER_RESOURCE_GROUP)"
echo "Ubuntu VM: $VM_NAME"
echo "VM Private IP: $PRIVATE_IP"
echo "VM Size: $VM_SIZE"
echo "VM Admin Username: $ADMIN_USERNAME"
echo ""
echo "ExpressRoute Connection Status:"
az network vpn-connection show \
    --resource-group $RESOURCE_GROUP \
    --name $ER_CONNECTION_NAME \
    --query "connectionStatus" \
    --output tsv
echo ""
echo "Next Steps:"
echo "1. Verify ExpressRoute circuit is provisioned and configured by your service provider"
echo "2. SSH to the VM using: ssh $ADMIN_USERNAME@$PRIVATE_IP"
echo "3. Test connectivity between on-premises and Azure through the ExpressRoute connection"
echo ""
echo "To check connection status later, use:"
echo "az network vpn-connection show --resource-group $RESOURCE_GROUP --name $ER_CONNECTION_NAME"
echo ""
echo "Deployment complete!"





#!/bin/bash

# Azure ExpressRoute Gateway and Ubuntu VM Configuration Script
# This script creates all necessary resources for an ExpressRoute gateway and Ubuntu VM

# Variables - Modify these as needed
RESOURCE_GROUP="Claude-rg4"
LOCATION="southafricanorth"
VNET_NAME="zan-vnet-azure-hub"
VNET_PREFIX="10.53.0.0/22"
GATEWAY_SUBNET_PREFIX="10.53.0.0/27"
INTERNAL_SUBNET_NAME="subnet-internal"
INTERNAL_SUBNET_PREFIX="10.53.1.0/24"
EXPRESSROUTE_GATEWAY_NAME="zan-ergw-azure-hub"
EXPRESSROUTE_GATEWAY_PIP_NAME="zan-pip-ergw-hub"

# VM Configuration
VM_NAME="zan-ubuntu2204-vm"
VM_SIZE="Standard_B2s"
ADMIN_USERNAME="azureuser"
IMAGE="Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest"
NIC_NAME="${VM_NAME}-nic"

echo "Starting Azure ExpressRoute Gateway and Ubuntu VM deployment..."
echo "================================================================"

# Create Resource Group
echo "Creating Resource Group..."
az group create \
    --name $RESOURCE_GROUP \
    --location $LOCATION

# Create Virtual Network
echo "Creating Virtual Network..."
az network vnet create \
    --resource-group $RESOURCE_GROUP \
    --name $VNET_NAME \
    --address-prefix $VNET_PREFIX \
    --location $LOCATION

# Create Gateway Subnet (must be named 'GatewaySubnet')
echo "Creating Gateway Subnet..."
az network vnet subnet create \
    --resource-group $RESOURCE_GROUP \
    --vnet-name $VNET_NAME \
    --name GatewaySubnet \
    --address-prefix $GATEWAY_SUBNET_PREFIX

# Create Internal Subnet (for VMs/resources in Azure)
echo "Creating Internal Subnet..."
az network vnet subnet create \
    --resource-group $RESOURCE_GROUP \
    --vnet-name $VNET_NAME \
    --name $INTERNAL_SUBNET_NAME \
    --address-prefix $INTERNAL_SUBNET_PREFIX

# Create Public IP for ExpressRoute Gateway
echo "Creating Public IP for ExpressRoute Gateway..."
az network public-ip create \
    --resource-group $RESOURCE_GROUP \
    --name $EXPRESSROUTE_GATEWAY_PIP_NAME \
    --allocation-method Static \
    --sku Standard \
    --location $LOCATION

# Create ExpressRoute Gateway (This takes 30-45 minutes!)
echo "Creating ExpressRoute Gateway (this will take 30-45 minutes)..."
az network vnet-gateway create \
    --resource-group $RESOURCE_GROUP \
    --name $EXPRESSROUTE_GATEWAY_NAME \
    --vnet $VNET_NAME \
    --public-ip-address $EXPRESSROUTE_GATEWAY_PIP_NAME \
    --gateway-type ExpressRoute \
    --sku Standard \
    --location $LOCATION \
    --no-wait

# Create Network Interface for VM
echo "Creating Network Interface for Ubuntu VM..."
az network nic create \
    --resource-group $RESOURCE_GROUP \
    --name $NIC_NAME \
    --location $LOCATION \
    --subnet $INTERNAL_SUBNET_NAME \
    --vnet-name $VNET_NAME

# Create Ubuntu 22.04 VM
echo "Creating Ubuntu 22.04 VM..."
az vm create \
    --resource-group $RESOURCE_GROUP \
    --name $VM_NAME \
    --location $LOCATION \
    --nics $NIC_NAME \
    --size $VM_SIZE \
    --image $IMAGE \
    --admin-username $ADMIN_USERNAME \
    --generate-ssh-keys \
    --os-disk-name "${VM_NAME}-osdisk" \
    --os-disk-caching ReadWrite \
    --os-disk-size-gb 30 \
    --storage-sku Premium_LRS

# Configure Network Security Group for the VM
echo "Configuring Network Security Group..."
az network nsg rule create \
    --resource-group $RESOURCE_GROUP \
    --nsg-name "${NIC_NAME}NSG" \
    --name AllowSSH \
    --priority 1000 \
    --source-address-prefixes '*' \
    --destination-port-ranges 22 \
    --access Allow \
    --protocol Tcp \
    --description "Allow SSH access"

# Optional: Configure auto-shutdown to save costs
echo "Configuring auto-shutdown for VM (7 PM daily)..."
az vm auto-shutdown \
    --resource-group $RESOURCE_GROUP \
    --name $VM_NAME \
    --time 1900

# Wait for ExpressRoute Gateway to be provisioned
echo "Waiting for ExpressRoute Gateway to be fully provisioned..."
az network vnet-gateway wait \
    --resource-group $RESOURCE_GROUP \
    --name $EXPRESSROUTE_GATEWAY_NAME \
    --created

# Get ExpressRoute Gateway details
echo "Getting ExpressRoute Gateway details..."
az network vnet-gateway show \
    --resource-group $RESOURCE_GROUP \
    --name $EXPRESSROUTE_GATEWAY_NAME \
    --query "{Name:name, ProvisioningState:provisioningState, GatewayType:gatewayType, SKU:sku.name}" \
    --output table

# Get VM details
echo "Getting VM details..."
az vm show \
    --resource-group $RESOURCE_GROUP \
    --name $VM_NAME \
    --show-details \
    --query "{Name:name, PowerState:powerState, PrivateIP:privateIps, Size:hardwareProfile.vmSize, OS:storageProfile.osDisk.osType}" \
    --output table

# Get Private IP of the VM
PRIVATE_IP=$(az vm show -d \
    --resource-group $RESOURCE_GROUP \
    --name $VM_NAME \
    --query privateIps \
    --output tsv)

echo ""
echo "================================================"
echo "Deployment Summary:"
echo "================================================"
echo "Resource Group: $RESOURCE_GROUP"
echo "Location: $LOCATION"
echo "Virtual Network: $VNET_NAME ($VNET_PREFIX)"
echo "ExpressRoute Gateway: $EXPRESSROUTE_GATEWAY_NAME"
echo "Ubuntu VM: $VM_NAME"
echo "VM Private IP: $PRIVATE_IP"
echo "VM Size: $VM_SIZE"
echo "VM Admin Username: $ADMIN_USERNAME"
echo ""
echo "Next Steps:"
echo "1. Connect to the ExpressRoute circuit when available"
echo "2. SSH to the VM using: ssh $ADMIN_USERNAME@$PRIVATE_IP"
echo "3. Note: SSH access requires connectivity through ExpressRoute or a bastion host"
echo ""
echo "To connect an ExpressRoute circuit to this gateway later, use:"
echo "az network vpn-connection create \\"
echo "    --name <connection-name> \\"
echo "    --resource-group $RESOURCE_GROUP \\"
echo "    --vnet-gateway1 $EXPRESSROUTE_GATEWAY_NAME \\"
echo "    --express-route-circuit2 <circuit-id>"
echo ""
echo "Deployment complete!"




