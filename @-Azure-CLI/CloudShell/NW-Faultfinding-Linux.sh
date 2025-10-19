=========================================================================================================
// Enter the correct info from your Azure Subscription
=========================================================================================================
# Get variables
az group list --output table
az network vnet list -o table
=========================================================================================================
# Enter variables
=========================================================================================================
rg="ZA-East-vDC"
location="SouthAfricaNorth"
vnet="ZA-East-vDC-vnet"
subnet="Ping-test"
vmName="jumpbox-ubuntu3"

=========================================================================================================
# List all subnets in the specified VNet
az network vnet subnet list --resource-group "$rg" --vnet-name "$vnet" --output table
=========================================================================================================
# Create VM with cleaner table output
=========================================================================================================
echo "Creating VM: $vmName..."
az vm create \
 --resource-group $rg \
 --name $vmName \
 --image Ubuntu2204 \
 --vnet-name $vnet \
 --subnet $subnet \
 --admin-username azureadmin \
 --generate-ssh-keys \
 --location $location \
 --output table

echo ""
echo "VM Details:"
az vm show --resource-group $rg --name $vmName --show-details \
 --query "{Name:name, Location:location, PowerState:powerState, PrivateIP:privateIps, PublicIP:publicIps, Size:hardwareProfile.vmSize, OS:storageProfile.imageReference.offer}" \
 --output table

echo ""
echo ""
echo ""
=========================================================================================================
# Enable VM diagnostics
=========================================================================================================
az vm boot-diagnostics enable --name $vmName --resource-group $ResourceGroup
az vm list-ip-addresses --name $vmName -o table
=========================================================================================================
# SSH to VM
=========================================================================================================
ssh azureadmin@4.221.116.25
sudo passwd azureadmin


===========
| sudo su |
===========

sudo apt update
sudo apt install -y hping3

sudo apt install inetutils-traceroute
sudo apt install -y traceroute

tcpdump -ni eth0 icmp
tcpdump -ni eth0 src host 192.168.2.1
curl ifconfig.io

#=========================================================================================================
# List all effective routes on a NIC
#=========================================================================================================
vmNic=$(az vm show --resource-group "$rg" --name "$vmName" --query "networkProfile.networkInterfaces[0].id" --output tsv | awk -F'/' '{print $NF}')
echo $vmNic
az network nic show-effective-route-table --resource-group $rg --name $vmNic  -o table
#=========================================================================================================
# List all VM's IP addresses
#=========================================================================================================
az vm list-ip-addresses --output table


===========================
| hping3 -S -p 22 x.x.x.x |
| hping3 --icmp x.x.x.x   |
===========================
