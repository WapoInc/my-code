#!/bin/bash

# Azure CLI Script to create Load Balancer with 3 VMs in different Availability Zones
# Set variables
RESOURCE_GROUP="Claude-Az-LB-2-VMs"
LOCATION="East US 2"
VNET_NAME="claude-vnet"
VNET_CIDR="10.20.0.0/24"
SUBNET_NAME="default"
SUBNET_CIDR="10.20.0.0/26"
NSG_NAME="claude-nsg"
LB_NAME="claude-load-balancer"
PUBLIC_IP_NAME="claude-lb-public-ip"
BACKEND_POOL_NAME="BackendPool"
HEALTH_PROBE_NAME="HTTPProbe"
LB_RULE_NAME="HTTPRule"
VM_SIZE="Standard_B2s"
ADMIN_USERNAME="azureuser"
ADMIN_PASSWORD="YourSecurePassword123!"  # Change this to a secure password

# VM Names and their corresponding Availability Zones
declare -a VM_NAMES=("Az1-Ubuntu" "Az2-Ubuntu" "Az3-Ubuntu")
declare -a AZ_ZONES=("1" "2" "3")

echo "Starting Azure infrastructure deployment..."

# 1. Create Resource Group
echo "Creating Resource Group: $RESOURCE_GROUP"
az group create \
  --name $RESOURCE_GROUP \
  --location "$LOCATION"

# 2. Create Network Security Group
echo "Creating Network Security Group: $NSG_NAME"
az network nsg create \
  --resource-group $RESOURCE_GROUP \
  --name $NSG_NAME \
  --location "$LOCATION"

# 3. Create NSG Rules
echo "Creating NSG rules for SSH and HTTP"
az network nsg rule create \
  --resource-group $RESOURCE_GROUP \
  --nsg-name $NSG_NAME \
  --name SSH \
  --protocol tcp \
  --priority 1001 \
  --destination-port-range 22 \
  --access allow

az network nsg rule create \
  --resource-group $RESOURCE_GROUP \
  --nsg-name $NSG_NAME \
  --name HTTP \
  --protocol tcp \
  --priority 1002 \
  --destination-port-range 80 \
  --access allow

# 4. Create Virtual Network
echo "Creating Virtual Network: $VNET_NAME"
az network vnet create \
  --resource-group $RESOURCE_GROUP \
  --name $VNET_NAME \
  --address-prefix $VNET_CIDR \
  --subnet-name $SUBNET_NAME \
  --subnet-prefix $SUBNET_CIDR \
  --location "$LOCATION"

# 5. Associate NSG with Subnet
echo "Associating NSG with subnet"
az network vnet subnet update \
  --resource-group $RESOURCE_GROUP \
  --vnet-name $VNET_NAME \
  --name $SUBNET_NAME \
  --network-security-group $NSG_NAME

# 6. Create Public IP for Load Balancer (Standard SKU, Zone Redundant)
echo "Creating Public IP: $PUBLIC_IP_NAME"
az network public-ip create \
  --resource-group $RESOURCE_GROUP \
  --name $PUBLIC_IP_NAME \
  --sku Standard \
  --allocation-method Static \
  --zone 1 2 3 \
  --location "$LOCATION"

# 7. Create Load Balancer (Standard SKU)
echo "Creating Load Balancer: $LB_NAME"
az network lb create \
  --resource-group $RESOURCE_GROUP \
  --name $LB_NAME \
  --sku Standard \
  --public-ip-address $PUBLIC_IP_NAME \
  --frontend-ip-name LoadBalancerFrontEnd \
  --backend-pool-name $BACKEND_POOL_NAME \
  --location "$LOCATION"

# 8. Create Health Probe
echo "Creating Health Probe: $HEALTH_PROBE_NAME"
az network lb probe create \
  --resource-group $RESOURCE_GROUP \
  --lb-name $LB_NAME \
  --name $HEALTH_PROBE_NAME \
  --protocol http \
  --port 80 \
  --path / \
  --interval 5 \
  --threshold 2

# 9. Create Load Balancer Rule
echo "Creating Load Balancer Rule: $LB_RULE_NAME"
az network lb rule create \
  --resource-group $RESOURCE_GROUP \
  --lb-name $LB_NAME \
  --name $LB_RULE_NAME \
  --protocol tcp \
  --frontend-port 80 \
  --backend-port 80 \
  --frontend-ip-name LoadBalancerFrontEnd \
  --backend-pool-name $BACKEND_POOL_NAME \
  --probe-name $HEALTH_PROBE_NAME \
  --idle-timeout 5

# 10. Create custom script for VM initialization
cat > cloud-init.txt << 'EOF'
#!/bin/bash
apt update
apt install -y nginx
systemctl start nginx
systemctl enable nginx

# Get the VM's availability zone
AZ_ZONE=$(curl -s -H Metadata:true "http://169.254.169.254/metadata/instance/compute/zone?api-version=2021-02-01&format=text")
HOSTNAME=$(hostname)

# Create custom webpage
cat > /var/www/html/index.html << HTML
<!DOCTYPE html>
<html>
<head>
    <title>Azure Load Balancer Test</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background-color: #f0f8ff; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; background-color: white; border-radius: 10px; box-shadow: 0 0 10px rgba(0,0,0,0.1); }
        h1 { color: #0066cc; text-align: center; }
        .info { background-color: #e6f3ff; padding: 15px; border-radius: 5px; margin: 20px 0; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Welcome to Azure Load Balancer</h1>
        <div class="info">
            <p><strong>Server:</strong> $HOSTNAME</p>
            <p><strong>Availability Zone:</strong> $AZ_ZONE</p>
            <p><strong>Status:</strong> Server is healthy and responding</p>
            <p><strong>Timestamp:</strong> $(date)</p>
        </div>
        <p>This page is served from VM <strong>$HOSTNAME</strong> located in Availability Zone <strong>$AZ_ZONE</strong>.</p>
    </div>
</body>
</html>
HTML

# Restart nginx to ensure everything is working
systemctl restart nginx
EOF

# 11. Create VMs in different Availability Zones
for i in "${!VM_NAMES[@]}"; do
    VM_NAME="${VM_NAMES[$i]}"
    AZ_ZONE="${AZ_ZONES[$i]}"
    NIC_NAME="${VM_NAME}-nic"
    
    echo "Creating VM $((i+1))/3: $VM_NAME in Availability Zone $AZ_ZONE"
    
    # Create Network Interface
    echo "  Creating NIC: $NIC_NAME"
    az network nic create \
      --resource-group $RESOURCE_GROUP \
      --name $NIC_NAME \
      --vnet-name $VNET_NAME \
      --subnet $SUBNET_NAME \
      --lb-name $LB_NAME \
      --lb-address-pools $BACKEND_POOL_NAME \
      --location "$LOCATION"
    
    # Create Virtual Machine
    echo "  Creating VM: $VM_NAME"
    az vm create \
      --resource-group $RESOURCE_GROUP \
      --name $VM_NAME \
      --zone $AZ_ZONE \
      --nics $NIC_NAME \
      --image "Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest" \
      --size $VM_SIZE \
      --admin-username $ADMIN_USERNAME \
      --admin-password "$ADMIN_PASSWORD" \
      --custom-data cloud-init.txt \
      --no-wait
    
    echo "  VM $VM_NAME creation initiated in zone $AZ_ZONE"
done

# 12. Wait for all VMs to be created
echo "Waiting for all VMs to be created and running..."
for VM_NAME in "${VM_NAMES[@]}"; do
    echo "Waiting for $VM_NAME to be running..."
    az vm wait --resource-group $RESOURCE_GROUP --name $VM_NAME --created
    echo "$VM_NAME is now running"
done

# 13. Get Load Balancer Public IP
echo "Getting Load Balancer Public IP address..."
LB_PUBLIC_IP=$(az network public-ip show \
  --resource-group $RESOURCE_GROUP \
  --name $PUBLIC_IP_NAME \
  --query ipAddress \
  --output tsv)

# 14. Display deployment summary
echo "=================================="
echo "DEPLOYMENT COMPLETED SUCCESSFULLY!"
echo "=================================="
echo "Resource Group: $RESOURCE_GROUP"
echo "Location: $LOCATION"
echo "Virtual Network: $VNET_NAME ($VNET_CIDR)"
echo "Load Balancer: $LB_NAME"
echo "Load Balancer Public IP: $LB_PUBLIC_IP"
echo ""
echo "Virtual Machines:"
for i in "${!VM_NAMES[@]}"; do
    VM_NAME="${VM_NAMES[$i]}"
    AZ_ZONE="${AZ_ZONES[$i]}"
    echo "  - $VM_NAME (Availability Zone $AZ_ZONE)"
done
echo ""
echo "Test your load balancer:"
echo "curl http://$LB_PUBLIC_IP"
echo "or visit: http://$LB_PUBLIC_IP in your browser"
echo ""
echo "SSH to VMs (replace <VM_NAME> with actual VM name):"
echo "az network public-ip create --resource-group $RESOURCE_GROUP --name <VM_NAME>-pip --allocation-method Static --sku Standard"
echo "az network nic ip-config update --resource-group $RESOURCE_GROUP --nic-name <VM_NAME>-nic --name ipconfig1 --public-ip-address <VM_NAME>-pip"
echo "ssh $ADMIN_USERNAME@<PUBLIC_IP>"
echo ""

# Clean up temporary file
rm -f cloud-init.txt

echo "Deployment script completed!"