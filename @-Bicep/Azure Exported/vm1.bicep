# Create a resource group
az group create --name MyResourceGroup --location southafricanorth

# Create a virtual machine
az vm create \
    --resource-group MyResourceGroup \
    --name MyUbuntuVM \
    --image UbuntuLTS \
    --admin-username azureuser \
    --generate-ssh-keys \
    --location southafricanorth

# Open port 22 for SSH access
az vm open-port --port 22 --resource-group MyResourceGroup --name MyUbuntuVM
