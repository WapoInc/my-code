#!/bin/bash
# Reference: https://docs.microsoft.com/en-us/azure/virtual-wan/scenario-route-through-nva
# https://github.com/dmauser/azure-virtualwan/blob/main/inter-region-nvabgp/media/inter-region-nvabgp.drawio
# https://github.com/dmauser/azure-virtualwan/blob/main/inter-region-nvabgp/README.md
# This lab deploys two Linux NVAs on Spoke2 and Spoke4 with ILB.
# v8: Optimised for parallel resource creation to reduce deployment time.
#     Hub waits, NVA deployments, VPN GW waits, and many other build steps
#     now run concurrently via bash background jobs (&) and subshells.

# Pre-Requisite
# Check if virtual wan extension is installed if not install it
if ! az extension list | grep -q virtual-wan; then
    echo "virtual-wan extension is not installed, installing it now..."
    az extension add --name virtual-wan --only-show-errors
fi

# Parameters (make changes based on your requirements)
region1=southafricanorth
region2=northeurope
rg=lab2-vwan-nvabgp-v9
vwanname=vwan-nvabgp
hub1name=hub1
hub2name=hub2
username=azureuser
password="P@ssw0rd123!" #Please change your password
vmsize=Standard_B2s #Standard_B1s

#Variables
mypip=$(curl -4 ifconfig.io -s)

# Adding script starting time and finish time
start=`date +%s`
echo "Script started at $(date)"

# Creating rg
az group create -n $rg -l $region1 --output none

# Creating virtual wan (synchronous - required before hubs can be created)
echo "Creating vWAN..."
az network vwan create -g $rg -n $vwanname --branch-to-branch-traffic true --location $region1 --type Standard --output none

# Start both hubs with --no-wait (they take 20-30 min; run concurrently from here)
echo "Creating both vWAN hubs in parallel (--no-wait)..."
az network vhub create -g $rg --name $hub1name --address-prefix 192.168.1.0/24 --vwan $vwanname --location $region1 --sku Standard --no-wait
az network vhub create -g $rg --name $hub2name --address-prefix 192.168.2.0/24 --vwan $vwanname --location $region2 --sku Standard --no-wait

# ─── WAVE 1: Create ALL VNETs in parallel ───────────────────────────────────
echo "Creating all VNETs in parallel (branch + spoke)..."
az network vnet create --address-prefixes 10.100.0.0/16 -n branch1 -g $rg -l $region1 --subnet-name main --subnet-prefixes 10.100.0.0/24 --output none &
az network vnet create --address-prefixes 10.200.0.0/16 -n branch2 -g $rg -l $region2 --subnet-name main --subnet-prefixes 10.200.0.0/24 --output none &
az network vnet create --address-prefixes 10.1.0.0/24  -n spoke1 -g $rg -l $region1 --subnet-name main --subnet-prefixes 10.1.0.0/27  --output none &
az network vnet create --address-prefixes 10.2.0.0/24  -n spoke2 -g $rg -l $region1 --subnet-name main --subnet-prefixes 10.2.0.0/27  --output none &
az network vnet create --address-prefixes 10.2.1.0/24  -n spoke5 -g $rg -l $region1 --subnet-name main --subnet-prefixes 10.2.1.0/27  --output none &
az network vnet create --address-prefixes 10.2.2.0/24  -n spoke6 -g $rg -l $region1 --subnet-name main --subnet-prefixes 10.2.2.0/27  --output none &
az network vnet create --address-prefixes 10.3.0.0/24  -n spoke3 -g $rg -l $region2 --subnet-name main --subnet-prefixes 10.3.0.0/27  --output none &
az network vnet create --address-prefixes 10.4.0.0/24  -n spoke4 -g $rg -l $region2 --subnet-name main --subnet-prefixes 10.4.0.0/27  --output none &
az network vnet create --address-prefixes 10.4.1.0/24  -n spoke7 -g $rg -l $region2 --subnet-name main --subnet-prefixes 10.4.1.0/27  --output none &
az network vnet create --address-prefixes 10.4.2.0/24  -n spoke8 -g $rg -l $region2 --subnet-name main --subnet-prefixes 10.4.2.0/27  --output none &
wait
echo "All VNETs created."

# ─── WAVE 2: Kick off all VMs immediately (VNETs exist; VMs deploy in background) ───
# Branch and spoke VMs are started here so Azure can provision them in parallel
# with all remaining network setup steps below.
echo "Launching all branch and spoke VMs with --no-wait..."
az vm create -n branch1VM -g $rg --image Ubuntu2204 --public-ip-sku Standard --size $vmsize -l $region1 --subnet main --vnet-name branch1 --admin-username $username --admin-password $password --nsg "" --no-wait --only-show-errors
az vm create -n branch2VM -g $rg --image Ubuntu2204 --public-ip-sku Standard --size $vmsize -l $region2 --subnet main --vnet-name branch2 --admin-username $username --admin-password $password --nsg "" --no-wait --only-show-errors
az vm create -n spoke1VM  -g $rg --image Ubuntu2204 --public-ip-sku Standard --size $vmsize -l $region1 --subnet main --vnet-name spoke1  --admin-username $username --admin-password $password --nsg "" --no-wait --only-show-errors
az vm create -n spoke3VM  -g $rg --image Ubuntu2204 --public-ip-sku Standard --size $vmsize -l $region2 --subnet main --vnet-name spoke3  --admin-username $username --admin-password $password --nsg "" --no-wait --only-show-errors
az vm create -n spoke5VM  -g $rg --image Ubuntu2204 --public-ip-sku Standard --size $vmsize -l $region1 --subnet main --vnet-name spoke5  --admin-username $username --admin-password $password --nsg "" --no-wait --only-show-errors
az vm create -n spoke6VM  -g $rg --image Ubuntu2204 --public-ip-sku Standard --size $vmsize -l $region1 --subnet main --vnet-name spoke6  --admin-username $username --admin-password $password --nsg "" --no-wait --only-show-errors
az vm create -n spoke7VM  -g $rg --image Ubuntu2204 --public-ip-sku Standard --size $vmsize -l $region2 --subnet main --vnet-name spoke7  --admin-username $username --admin-password $password --nsg "" --no-wait --only-show-errors
az vm create -n spoke8VM  -g $rg --image Ubuntu2204 --public-ip-sku Standard --size $vmsize -l $region2 --subnet main --vnet-name spoke8  --admin-username $username --admin-password $password --nsg "" --no-wait --only-show-errors

# ─── WAVE 3: VNET peerings + NSG creation + GatewaySubnets + PIPs (all parallel) ───
echo "Creating VNET peerings, NSGs, GatewaySubnets, and PIPs in parallel..."

# VNET peerings (8 peerings in parallel)
az network vnet peering create -g $rg -n spoke2-to-spoke5 --vnet-name spoke2 --allow-vnet-access --allow-forwarded-traffic --remote-vnet $(az network vnet show -g $rg -n spoke5 --query id --out tsv) --output none &
az network vnet peering create -g $rg -n spoke5-to-spoke2 --vnet-name spoke5 --allow-vnet-access --allow-forwarded-traffic --remote-vnet $(az network vnet show -g $rg -n spoke2 --query id --out tsv) --output none &
az network vnet peering create -g $rg -n spoke2-to-spoke6 --vnet-name spoke2 --allow-vnet-access --allow-forwarded-traffic --remote-vnet $(az network vnet show -g $rg -n spoke6 --query id --out tsv) --output none &
az network vnet peering create -g $rg -n spoke6-to-spoke2 --vnet-name spoke6 --allow-vnet-access --allow-forwarded-traffic --remote-vnet $(az network vnet show -g $rg -n spoke2 --query id --out tsv) --output none &
az network vnet peering create -g $rg -n spoke4-to-spoke7 --vnet-name spoke4 --allow-vnet-access --allow-forwarded-traffic --remote-vnet $(az network vnet show -g $rg -n spoke7 --query id --out tsv) --output none &
az network vnet peering create -g $rg -n spoke7-to-spoke4 --vnet-name spoke7 --allow-vnet-access --allow-forwarded-traffic --remote-vnet $(az network vnet show -g $rg -n spoke4 --query id --out tsv) --output none &
az network vnet peering create -g $rg -n spoke4-to-spoke8 --vnet-name spoke4 --allow-vnet-access --allow-forwarded-traffic --remote-vnet $(az network vnet show -g $rg -n spoke8 --query id --out tsv) --output none &
az network vnet peering create -g $rg -n spoke8-to-spoke4 --vnet-name spoke8 --allow-vnet-access --allow-forwarded-traffic --remote-vnet $(az network vnet show -g $rg -n spoke4 --query id --out tsv) --output none &

# NSG creation (both regions in parallel)
az network nsg create --resource-group $rg --name default-nsg-$region1 --location $region1 -o none &
az network nsg create --resource-group $rg --name default-nsg-$region2 --location $region2 -o none &

# GatewaySubnets and branch VPN GW PIPs (all 4 in parallel)
az network vnet subnet create -g $rg --vnet-name branch1 -n GatewaySubnet --address-prefixes 10.100.100.0/26 --output none &
az network vnet subnet create -g $rg --vnet-name branch2 -n GatewaySubnet --address-prefixes 10.200.100.0/26 --output none &
az network public-ip create -n branch1-vpngw-pip -g $rg --location $region1 --sku Standard --allocation-method Static --zone 1 2 3 --output none &
az network public-ip create -n branch2-vpngw-pip -g $rg --location $region2 --sku Standard --allocation-method Static --zone 1 2 3 --output none &
wait
echo "VNET peerings, NSGs, GatewaySubnets, and PIPs complete."

# ─── WAVE 4: NSG rules, then NSG subnet associations, then branch VPN GWs ────
# IMPORTANT: NSG subnet association must complete BEFORE branch VPN GWs are
# started with --no-wait. Azure locks the entire VNET into "Updating" state
# while a VPN Gateway is provisioning, which causes subnet updates to fail.
echo "Adding NSG rules..."
az network nsg rule create -g $rg --nsg-name default-nsg-$region1 -n 'default-allow-ssh' --direction Inbound --priority 100 --source-address-prefixes $mypip --source-port-ranges '*' --destination-address-prefixes '*' --destination-port-ranges 22 --access Allow --protocol Tcp --description "Allow inbound SSH" --output none &
az network nsg rule create -g $rg --nsg-name default-nsg-$region2 -n 'default-allow-ssh' --direction Inbound --priority 100 --source-address-prefixes $mypip --source-port-ranges '*' --destination-address-prefixes '*' --destination-port-ranges 22 --access Allow --protocol Tcp --description "Allow inbound SSH" --output none &
wait
echo "NSG rules added."

# NSG association to spoke/branch subnets (must complete before VPN GWs start)
echo "Associating NSGs to VNET subnets in parallel..."
az network vnet subnet update --id $(az network vnet list -g $rg --query '[?location==`'$region1'`].{id:subnets[0].id}' -o tsv) --network-security-group default-nsg-$region1 -o none &
az network vnet subnet update --id $(az network vnet list -g $rg --query '[?location==`'$region2'`].{id:subnets[0].id}' -o tsv) --network-security-group default-nsg-$region2 -o none &
wait
echo "NSG associations complete."

# Branch VPN Gateways (GatewaySubnets, PIPs, and NSG associations now complete)
echo "Creating VPN Gateways in both branches (--no-wait)..."
az network vnet-gateway create -n branch1-vpngw --public-ip-addresses branch1-vpngw-pip -g $rg --vnet branch1 --asn 65510 --gateway-type Vpn -l $region1 --sku VPNGW1AZ --vpn-gateway-generation Generation1 --no-wait
az network vnet-gateway create -n branch2-vpngw --public-ip-addresses branch2-vpngw-pip -g $rg --vnet branch2 --asn 65509 --gateway-type Vpn -l $region2 --sku VPNGW1AZ --vpn-gateway-generation Generation1 --no-wait

# ─── WAVE 5: Wait for BOTH hubs simultaneously, then create hub VPN GWs + spoke connections ───
echo "Waiting for Hub1 and Hub2 provisioning in parallel..."
(
    prState=''
    rtState=''
    while [[ $prState != 'Succeeded' ]]; do
        prState=$(az network vhub show -g $rg -n $hub1name --query 'provisioningState' -o tsv)
        echo "$hub1name provisioningState=$prState"
        sleep 5
    done
    while [[ $rtState != 'Provisioned' ]]; do
        rtState=$(az network vhub show -g $rg -n $hub1name --query 'routingState' -o tsv)
        echo "$hub1name routingState=$rtState"
        sleep 5
    done
) &
(
    prState=''
    rtState=''
    while [[ $prState != 'Succeeded' ]]; do
        prState=$(az network vhub show -g $rg -n $hub2name --query 'provisioningState' -o tsv)
        echo "$hub2name provisioningState=$prState"
        sleep 5
    done
    while [[ $rtState != 'Provisioned' ]]; do
        rtState=$(az network vhub show -g $rg -n $hub2name --query 'routingState' -o tsv)
        echo "$hub2name routingState=$rtState"
        sleep 5
    done
) &
wait
echo "Both hubs are provisioned."

# Both hubs ready — create hub VPN GWs and spoke connections
echo "Creating Hub VPN Gateways (--no-wait)..."
az network vpn-gateway create -n $hub1name-vpngw -g $rg --location $region1 --vhub $hub1name --no-wait
az network vpn-gateway create -n $hub2name-vpngw -g $rg --location $region2 --vhub $hub2name --no-wait

echo "Creating spoke connections to their respective hubs (--no-wait)..."
az network vhub connection create -n spoke1conn --remote-vnet spoke1 -g $rg --vhub-name $hub1name --no-wait
az network vhub connection create -n spoke2conn --remote-vnet spoke2 -g $rg --vhub-name $hub1name --no-wait
az network vhub connection create -n spoke3conn --remote-vnet spoke3 -g $rg --vhub-name $hub2name --no-wait
az network vhub connection create -n spoke4conn --remote-vnet spoke4 -g $rg --vhub-name $hub2name --no-wait

# ─── WAVE 6: Wait for spoke2conn and spoke4conn in parallel ─────────────────
echo "Waiting for spoke2conn and spoke4conn provisioning in parallel..."
(
    prState=''
    while [[ $prState != 'Succeeded' ]]; do
        prState=$(az network vhub connection show -n spoke2conn --vhub-name $hub1name -g $rg --query 'provisioningState' -o tsv)
        echo "spoke2conn provisioningState=$prState"
        sleep 5
    done
) &
(
    prState=''
    while [[ $prState != 'Succeeded' ]]; do
        prState=$(az network vhub connection show -n spoke4conn --vhub-name $hub2name -g $rg --query 'provisioningState' -o tsv)
        echo "spoke4conn provisioningState=$prState"
        sleep 5
    done
) &
wait
echo "Spoke connections ready."

# ─── WAVE 7: Deploy NVAs for spoke2 (region1) and spoke4 (region2) in parallel ───
echo "Deploying Linux NVA BGP routers on spoke2 and spoke4 in parallel..."

# === Spoke2 NVA Deployment (region1, hub1) ===
(
    nvavnetname=spoke2
    instances=2
    nvaintname=linux-nva
    nvasubnetname=nvasubnet
    hubtopeer=$hub1name
    asn_frr=65002
    bgp_network1="10.2.0.0/16"

    echo "Creating spoke2 nvasubnet..."
    az network vnet subnet create -g $rg --vnet-name $nvavnetname -n $nvasubnetname --address-prefixes 10.2.0.32/28 --output none

    nvanames=$(i=1; while [ $i -le $instances ]; do echo ${nvavnetname}-${nvaintname}${i}; ((i++)); done)

    for nvaname in $nvanames; do
        az network public-ip create --name $nvaname-pip --resource-group $rg --location $region1 --sku Standard --output none --only-show-errors
        az network nic create --name $nvaname-nic --resource-group $rg --subnet $nvasubnetname --vnet $nvavnetname --public-ip-address $nvaname-pip --ip-forwarding true --location $region1 -o none
        az vm create --resource-group $rg --location $region1 --name $nvaname --size $vmsize --nics $nvaname-nic --image Ubuntu2204 --admin-username $username --admin-password $password -o none --only-show-errors

        bgp_routerId=$(az network nic show --name $nvaname-nic --resource-group $rg --query ipConfigurations[0].privateIPAddress -o tsv)
        routeserver_IP1=$(az network vhub show -n $hubtopeer -g $rg --query virtualRouterIps[0] -o tsv)
        routeserver_IP2=$(az network vhub show -n $hubtopeer -g $rg --query virtualRouterIps[1] -o tsv)

        scripturi="https://raw.githubusercontent.com/dmauser/AzureVM-Router/master/scripts/linuxrouterbgpfrr.sh"
        az vm extension set --resource-group $rg --vm-name $nvaname --name customScript --publisher Microsoft.Azure.Extensions \
        --protected-settings "{\"fileUris\": [\"$scripturi\"],\"commandToExecute\": \"./linuxrouterbgpfrr.sh $asn_frr $bgp_routerId $bgp_network1 $routeserver_IP1 $routeserver_IP2\"}" \
        --no-wait

        az network vhub bgpconnection create --resource-group $rg \
        --vhub-name $hubtopeer \
        --name $nvaname \
        --peer-asn $asn_frr \
        --peer-ip $(az network nic show --name $nvaname-nic --resource-group $rg --query ipConfigurations[0].privateIPAddress -o tsv) \
        --vhub-conn $(az network vhub connection show --name ${nvavnetname}conn --resource-group $rg --vhub-name $hubtopeer --query id -o tsv) \
        --output none
    done

    echo "Creating ILB for spoke2..."
    az network lb create -g $rg --name ${nvavnetname}-${nvaintname}-ilb --sku Standard --frontend-ip-name frontendip1 --backend-pool-name nvabackend --vnet-name $nvavnetname --subnet=$nvasubnetname --location $region1 --output none --only-show-errors
    az network lb probe create -g $rg --lb-name ${nvavnetname}-${nvaintname}-ilb --name sshprobe --protocol tcp --port 22 --output none
    az network lb rule create -g $rg --lb-name ${nvavnetname}-${nvaintname}-ilb --name haportrule1 --protocol all --frontend-ip-name frontendip1 --backend-pool-name nvabackend --probe-name sshprobe --frontend-port 0 --backend-port 0 --output none

    for nvaname in $nvanames; do
        az network nic ip-config address-pool add \
        --address-pool nvabackend \
        --ip-config-name ipconfig1 \
        --nic-name $nvaname-nic \
        --resource-group $rg \
        --lb-name ${nvavnetname}-${nvaintname}-ilb \
        --output none
    done
    echo "Spoke2 NVA deployment complete."
) &

# === Spoke4 NVA Deployment (region2, hub2) ===
(
    nvavnetname=spoke4
    instances=2
    nvaintname=linux-nva
    nvasubnetname=nvasubnet
    hubtopeer=$hub2name
    asn_frr=65004
    bgp_network1="10.4.0.0/16"

    echo "Creating spoke4 nvasubnet..."
    az network vnet subnet create -g $rg --vnet-name $nvavnetname -n $nvasubnetname --address-prefixes 10.4.0.32/28 --output none

    nvanames=$(i=1; while [ $i -le $instances ]; do echo ${nvavnetname}-${nvaintname}${i}; ((i++)); done)

    for nvaname in $nvanames; do
        az network public-ip create --name $nvaname-pip --resource-group $rg --location $region2 --sku Standard --output none --only-show-errors
        az network nic create --name $nvaname-nic --resource-group $rg --subnet $nvasubnetname --vnet $nvavnetname --public-ip-address $nvaname-pip --ip-forwarding true --location $region2 -o none
        az vm create --resource-group $rg --location $region2 --name $nvaname --size $vmsize --nics $nvaname-nic --image Ubuntu2204 --admin-username $username --admin-password $password -o none --only-show-errors

        bgp_routerId=$(az network nic show --name $nvaname-nic --resource-group $rg --query ipConfigurations[0].privateIPAddress -o tsv)
        routeserver_IP1=$(az network vhub show -n $hubtopeer -g $rg --query virtualRouterIps[0] -o tsv)
        routeserver_IP2=$(az network vhub show -n $hubtopeer -g $rg --query virtualRouterIps[1] -o tsv)

        scripturi="https://raw.githubusercontent.com/dmauser/AzureVM-Router/master/scripts/linuxrouterbgpfrr.sh"
        az vm extension set --resource-group $rg --vm-name $nvaname --name customScript --publisher Microsoft.Azure.Extensions \
        --protected-settings "{\"fileUris\": [\"$scripturi\"],\"commandToExecute\": \"./linuxrouterbgpfrr.sh $asn_frr $bgp_routerId $bgp_network1 $routeserver_IP1 $routeserver_IP2\"}" \
        --no-wait

        az network vhub bgpconnection create --resource-group $rg \
        --vhub-name $hubtopeer \
        --name $nvaname \
        --peer-asn $asn_frr \
        --peer-ip $(az network nic show --name $nvaname-nic --resource-group $rg --query ipConfigurations[0].privateIPAddress -o tsv) \
        --vhub-conn $(az network vhub connection show --name ${nvavnetname}conn --resource-group $rg --vhub-name $hubtopeer --query id -o tsv) \
        --output none
    done

    echo "Creating ILB for spoke4..."
    az network lb create -g $rg --name ${nvavnetname}-${nvaintname}-ilb --sku Standard --frontend-ip-name frontendip1 --backend-pool-name nvabackend --vnet-name $nvavnetname --subnet=$nvasubnetname --location $region2 --output none --only-show-errors
    az network lb probe create -g $rg --lb-name ${nvavnetname}-${nvaintname}-ilb --name sshprobe --protocol tcp --port 22 --output none
    az network lb rule create -g $rg --lb-name ${nvavnetname}-${nvaintname}-ilb --name haportrule1 --protocol all --frontend-ip-name frontendip1 --backend-pool-name nvabackend --probe-name sshprobe --frontend-port 0 --backend-port 0 --output none

    for nvaname in $nvanames; do
        az network nic ip-config address-pool add \
        --address-pool nvabackend \
        --ip-config-name ipconfig1 \
        --nic-name $nvaname-nic \
        --resource-group $rg \
        --lb-name ${nvavnetname}-${nvaintname}-ilb \
        --output none
    done
    echo "Spoke4 NVA deployment complete."
) &

wait
echo "Both NVA deployments complete."

# Associate NSG to NVA subnets in parallel
echo "Associating NSGs to NVA subnets..."
az network vnet subnet update --id $(az network vnet subnet show -g $rg --vnet-name spoke2 --name nvasubnet --query id -o tsv) --network-security-group default-nsg-$region1 -o none &
az network vnet subnet update --id $(az network vnet subnet show -g $rg --vnet-name spoke4 --name nvasubnet --query id -o tsv) --network-security-group default-nsg-$region2 -o none &
wait

# Install nettools on all Ubuntu VMs (--no-wait - fast loop)
echo "Installing nettools on all VMs..."
nettoolsuri="https://raw.githubusercontent.com/dmauser/azure-vm-net-tools/main/script/nettools.sh"
for vm in $(az vm list -g $rg --query "[?contains(storageProfile.imageReference.publisher,'Canonical')].name" -o tsv); do
    az vm extension set \
    --resource-group $rg \
    --vm-name $vm \
    --name customScript \
    --force-update \
    --publisher Microsoft.Azure.Extensions \
    --protected-settings "{\"fileUris\": [\"$nettoolsuri\"],\"commandToExecute\": \"./nettools.sh\"}" \
    --no-wait
done

# Wait for ALL VMs to finish provisioning before reading IPs for UDRs
echo "Waiting for all VMs to complete provisioning..."
az vm wait -g $rg --created --ids $(az vm list -g $rg --query '[].{id:id}' -o tsv) --only-show-errors -o none

# Read NVA and LB IPs (needed for UDRs)
spk2nvaip=$(az network nic show -n spoke2-linux-nva1-nic -g $rg --query 'ipConfigurations[0].privateIPAddress' -o tsv)
spk2nvalbip=$(az network lb show -g $rg -n spoke2-linux-nva-ilb --query frontendIPConfigurations[0].privateIPAddress -o tsv)
spk4nvaip=$(az network nic show -n spoke4-linux-nva1-nic -g $rg --query 'ipConfigurations[0].privateIPAddress' -o tsv)
spk4nvalbip=$(az network lb show -g $rg -n spoke4-linux-nva-ilb --query frontendIPConfigurations[0].privateIPAddress -o tsv)

# ─── WAVE 8: UDRs for both regions in parallel ───────────────────────────────
echo "Creating UDRs for indirect spokes in parallel..."
(
    # UDRs for Spoke 5 and 6 (via spoke2 NVA ILB)
    az network route-table create --name RT-to-spoke2-NVA --resource-group $rg --location $region1 --disable-bgp-route-propagation true --output none
    az network route-table route create --resource-group $rg --name Default-to-NVA --route-table-name RT-to-spoke2-NVA \
    --address-prefix 0.0.0.0/0 --next-hop-type VirtualAppliance --next-hop-ip-address $spk2nvalbip --output none
    az network vnet subnet update -n main -g $rg --vnet-name spoke5 --route-table RT-to-spoke2-NVA --output none
    az network vnet subnet update -n main -g $rg --vnet-name spoke6 --route-table RT-to-spoke2-NVA --output none
) &
(
    # UDRs for Spoke 7 and 8 (via spoke4 NVA ILB)
    az network route-table create --name RT-to-Spoke4-NVA --resource-group $rg --location $region2 --disable-bgp-route-propagation true --output none
    az network route-table route create --resource-group $rg --name Default-to-NVA --route-table-name RT-to-Spoke4-NVA \
    --address-prefix 0.0.0.0/0 --next-hop-type VirtualAppliance --next-hop-ip-address $spk4nvalbip --output none
    az network vnet subnet update -n main -g $rg --vnet-name spoke7 --route-table RT-to-Spoke4-NVA --output none
    az network vnet subnet update -n main -g $rg --vnet-name spoke8 --route-table RT-to-Spoke4-NVA --output none
) &
wait
echo "UDRs created."

# ─── WAVE 9: Validate all 4 VPN Gateways in parallel ────────────────────────
echo "Validating vHub and Branch VPN Gateways in parallel..."
(
    prState=$(az network vpn-gateway show -g $rg -n $hub1name-vpngw --query provisioningState -o tsv)
    if [[ $prState == 'Failed' ]]; then
        echo "$hub1name-vpngw is in failed state. Deleting and rebuilding..."
        az network vpn-gateway delete -n $hub1name-vpngw -g $rg
        az network vpn-gateway create -n $hub1name-vpngw -g $rg --location $region1 --vhub $hub1name --no-wait
        sleep 5
    fi
    prState=''
    while [[ $prState != 'Succeeded' ]]; do
        prState=$(az network vpn-gateway show -g $rg -n $hub1name-vpngw --query provisioningState -o tsv)
        echo "$hub1name-vpngw provisioningState=$prState"
        sleep 5
    done
) &
(
    prState=$(az network vpn-gateway show -g $rg -n $hub2name-vpngw --query provisioningState -o tsv)
    if [[ $prState == 'Failed' ]]; then
        echo "$hub2name-vpngw is in failed state. Deleting and rebuilding..."
        az network vpn-gateway delete -n $hub2name-vpngw -g $rg
        az network vpn-gateway create -n $hub2name-vpngw -g $rg --location $region2 --vhub $hub2name --no-wait
        sleep 5
    fi
    prState=''
    while [[ $prState != 'Succeeded' ]]; do
        prState=$(az network vpn-gateway show -g $rg -n $hub2name-vpngw --query provisioningState -o tsv)
        echo "$hub2name-vpngw provisioningState=$prState"
        sleep 5
    done
) &
(
    prState=$(az network vnet-gateway show -g $rg -n branch1-vpngw --query provisioningState -o tsv)
    if [[ $prState == 'Failed' ]]; then
        echo "branch1-vpngw is in failed state. Deleting and rebuilding..."
        az network vnet-gateway delete -n branch1-vpngw -g $rg
        az network vnet-gateway create -n branch1-vpngw --public-ip-addresses branch1-vpngw-pip -g $rg --vnet branch1 --asn 65510 --gateway-type Vpn -l $region1 --sku VPNGW1AZ --vpn-gateway-generation Generation1 --no-wait
        sleep 5
    fi
    prState=''
    while [[ $prState != 'Succeeded' ]]; do
        prState=$(az network vnet-gateway show -g $rg -n branch1-vpngw --query provisioningState -o tsv)
        echo "branch1-vpngw provisioningState=$prState"
        sleep 5
    done
) &
(
    prState=$(az network vnet-gateway show -g $rg -n branch2-vpngw --query provisioningState -o tsv)
    if [[ $prState == 'Failed' ]]; then
        echo "branch2-vpngw is in failed state. Deleting and rebuilding..."
        az network vnet-gateway delete -n branch2-vpngw -g $rg
        az network vnet-gateway create -n branch2-vpngw --public-ip-addresses branch2-vpngw-pip -g $rg --vnet branch2 --asn 65509 --gateway-type Vpn -l $region2 --sku VPNGW1AZ --vpn-gateway-generation Generation1 --no-wait
        sleep 5
    fi
    prState=''
    while [[ $prState != 'Succeeded' ]]; do
        prState=$(az network vnet-gateway show -g $rg -n branch2-vpngw --query provisioningState -o tsv)
        echo "branch2-vpngw provisioningState=$prState"
        sleep 5
    done
) &
wait
echo "All VPN Gateways provisioned."

# Collect BGP/IP details for all gateways (sequential - fast read-only queries)
echo "Collecting VPN Gateway BGP settings..."
bgp1=$(az network vnet-gateway show -n branch1-vpngw -g $rg --query 'bgpSettings.bgpPeeringAddresses[0].defaultBgpIpAddresses[0]' -o tsv)
pip1=$(az network vnet-gateway show -n branch1-vpngw -g $rg --query 'bgpSettings.bgpPeeringAddresses[0].tunnelIpAddresses[0]' -o tsv)
vwanh1gwbgp1=$(az network vpn-gateway show -n $hub1name-vpngw -g $rg --query 'bgpSettings.bgpPeeringAddresses[0].defaultBgpIpAddresses[0]' -o tsv)
vwanh1gwpip1=$(az network vpn-gateway show -n $hub1name-vpngw -g $rg --query 'bgpSettings.bgpPeeringAddresses[0].tunnelIpAddresses[0]' -o tsv)
vwanh1gwbgp2=$(az network vpn-gateway show -n $hub1name-vpngw -g $rg --query 'bgpSettings.bgpPeeringAddresses[1].defaultBgpIpAddresses[0]' -o tsv)
vwanh1gwpip2=$(az network vpn-gateway show -n $hub1name-vpngw -g $rg --query 'bgpSettings.bgpPeeringAddresses[1].tunnelIpAddresses[0]' -o tsv)

bgp2=$(az network vnet-gateway show -n branch2-vpngw -g $rg --query 'bgpSettings.bgpPeeringAddresses[0].defaultBgpIpAddresses[0]' -o tsv)
pip2=$(az network vnet-gateway show -n branch2-vpngw -g $rg --query 'bgpSettings.bgpPeeringAddresses[0].tunnelIpAddresses[0]' -o tsv)
vwanh2gwbgp1=$(az network vpn-gateway show -n $hub2name-vpngw -g $rg --query 'bgpSettings.bgpPeeringAddresses[0].defaultBgpIpAddresses[0]' -o tsv)
vwanh2gwpip1=$(az network vpn-gateway show -n $hub2name-vpngw -g $rg --query 'bgpSettings.bgpPeeringAddresses[0].tunnelIpAddresses[0]' -o tsv)
vwanh2gwbgp2=$(az network vpn-gateway show -n $hub2name-vpngw -g $rg --query 'bgpSettings.bgpPeeringAddresses[1].defaultBgpIpAddresses[0]' -o tsv)
vwanh2gwpip2=$(az network vpn-gateway show -n $hub2name-vpngw -g $rg --query 'bgpSettings.bgpPeeringAddresses[1].tunnelIpAddresses[0]' -o tsv)

# ─── WAVE 10: VPN site creation + hub-side connections in parallel ───────────
echo "Building VPN connections from VPN Gateways to the respective Branches..."
echo "Creating VPN sites in parallel..."
az network vpn-site create --ip-address $pip1 -n site-branch1 -g $rg --asn 65510 --bgp-peering-address $bgp1 -l $region1 --virtual-wan $vwanname --device-model 'Azure' --device-vendor 'Microsoft' --link-speed '50' --with-link true --output none &
az network vpn-site create --ip-address $pip2 -n site-branch2 -g $rg --asn 65509 --bgp-peering-address $bgp2 -l $region2 --virtual-wan $vwanname --device-model 'Azure' --device-vendor 'Microsoft' --link-speed '50' --with-link true --output none &
wait

echo "Creating hub-side VPN gateway connections in parallel..."
az network vpn-gateway connection create --gateway-name $hub1name-vpngw -n site-branch1-conn -g $rg --enable-bgp true --remote-vpn-site site-branch1 --internet-security --shared-key 'abc123' --output none &
az network vpn-gateway connection create --gateway-name $hub2name-vpngw -n site-branch2-conn -g $rg --enable-bgp true --remote-vpn-site site-branch2 --internet-security --shared-key 'abc123' --output none &
wait

# Wait for both hub-side VPN connections to succeed (in parallel)
echo "Waiting for site-branch1-conn and site-branch2-conn in parallel..."
(
    prState=''
    while [[ $prState != 'Succeeded' ]]; do
        prState=$(az network vpn-gateway connection show \
            --gateway-name $hub1name-vpngw \
            -n site-branch1-conn \
            -g $rg \
            --query 'provisioningState' -o tsv)
        echo "site-branch1-conn provisioningState=$prState"
        sleep 5
    done
) &
(
    prState=''
    while [[ $prState != 'Succeeded' ]]; do
        prState=$(az network vpn-gateway connection show \
            --gateway-name $hub2name-vpngw \
            -n site-branch2-conn \
            -g $rg \
            --query 'provisioningState' -o tsv)
        echo "site-branch2-conn provisioningState=$prState"
        sleep 5
    done
) &
wait
echo "Hub-side VPN connections succeeded."

# ─── WAVE 11: Local gateways in parallel, then branch-side VPN connections in parallel ───
echo "Creating local gateways in parallel..."
az network local-gateway create -g $rg -n lng-$hub1name-gw1 --gateway-ip-address $vwanh1gwpip1 --asn 65515 --bgp-peering-address $vwanh1gwbgp1 -l $region1 --output none &
az network local-gateway create -g $rg -n lng-$hub1name-gw2 --gateway-ip-address $vwanh1gwpip2 --asn 65515 --bgp-peering-address $vwanh1gwbgp2 -l $region1 --output none &
az network local-gateway create -g $rg -n lng-$hub2name-gw1 --gateway-ip-address $vwanh2gwpip1 --asn 65515 --bgp-peering-address $vwanh2gwbgp1 -l $region2 --output none &
az network local-gateway create -g $rg -n lng-$hub2name-gw2 --gateway-ip-address $vwanh2gwpip2 --asn 65515 --bgp-peering-address $vwanh2gwbgp2 -l $region2 --output none &
wait

echo "Creating branch-side VPN connections in parallel..."
az network vpn-connection create -n branch1-to-$hub1name-gw1 -g $rg -l $region1 --vnet-gateway1 branch1-vpngw --local-gateway2 lng-$hub1name-gw1 --enable-bgp --shared-key 'abc123' --output none &
az network vpn-connection create -n branch1-to-$hub1name-gw2 -g $rg -l $region1 --vnet-gateway1 branch1-vpngw --local-gateway2 lng-$hub1name-gw2 --enable-bgp --shared-key 'abc123' --output none &
az network vpn-connection create -n branch2-to-$hub2name-gw1 -g $rg -l $region2 --vnet-gateway1 branch2-vpngw --local-gateway2 lng-$hub2name-gw1 --enable-bgp --shared-key 'abc123' --output none &
az network vpn-connection create -n branch2-to-$hub2name-gw2 -g $rg -l $region2 --vnet-gateway1 branch2-vpngw --local-gateway2 lng-$hub2name-gw2 --enable-bgp --shared-key 'abc123' --output none &
wait

echo "Deployment has finished"
# Add script ending time but hours, minutes and seconds
end=`date +%s`
runtime=$((end-start))
echo "Script finished at $(date)"
echo "Total script execution time: $(($runtime / 3600)) hours $((($runtime / 60) % 60)) minutes and $(($runtime % 60)) seconds."
