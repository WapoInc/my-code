#Install the Az module

Install-Module Az -Force -AllowClobber

#Get BGP learned routes from ER or VPN GateWay

az network vnet-gateway list-learned-routes --resource-group ER-LTSA-RG  --name LTSA-ER-GateWay-SA-North -o table


#BGP Peer Status

az network vnet-gateway list-bgp-peer-status --resource-group ER-LTSA-RG --name LTSA-ER-GateWay-SA-North -o table


