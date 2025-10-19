
# Use to build an App GW with 2x Ubuntu VM's showing /images and /videos get routed to different backend VM's
# YouTube video :: https://youtu.be/reIsDqDnDHk

$grp="AppGateway-PoC-rg"
$location="SouthAfricaNorth"
$vnetName="vmr-VNET"
$subnetName="VM-SubNet"
$AppGWsubnetname ="AppGW-SubNet"
$vmName="IMAGE_VM"
$vmName2="VIDEO_VM"

# CREATE RESOURCE GROUP
az group create --name $grp --location $location

# CREATE VIRTUAL NETWORK
az network vnet create --address-prefixes 10.30.0.0/16 --name $vnetName --resource-group $grp

# CREATING SUBNET for App Gateway
az network vnet subnet create -g $grp --vnet-name $vnetName -n $subnetName --address-prefixes 10.30.2.0/24

# CREATING SUBNET for VM's
az network vnet subnet create -g $grp --vnet-name $vnetName -n $AppGWsubnetname --address-prefixes 10.30.1.0/24



# CREATING VMs
az vm create --resource-group $grp --name $vmName --image ubuntults --vnet-name $vnetName --subnet $subnetName --admin-username kamal --admin-password Hello@12345#
az vm create --resource-group $grp --name $vmName2 --image ubuntults --vnet-name $vnetName --subnet $subnetName --admin-username kamal --admin-password Hello@12345#


# SETTING UP WEB SERVERS
apt-get update -y
apt-get upgrade -y
# Run the next line after the first 2
apt-get install apache2 -y


echo "Hello World -- See all of your IMAGES here!" > /var/www/html/index.html
echo "Hello World -- See all of your VIDEOS here!" > /var/www/html/index.html

mkdir /var/www/html/images
mv /var/www/html/index.html /var/www/html/images/index.html

mkdir /var/www/html/videos
mv /var/www/html/index.html /var/www/html/videos/index.html