# VPN Tunnel Building Code Reference

This document provides a comprehensive guide to all VPN tunnel building code in this repository.

## Overview

This repository contains multiple implementations for building Azure VPN tunnels using different tools and approaches:
- **PowerShell scripts** for Azure PowerShell automation
- **Azure CLI (Bash) scripts** for command-line automation
- **Bicep templates** for Infrastructure as Code (IaC)

---

## 1. Site-to-Site (S2S) VPN Connections

### 1.1 Azure CLI Scripts

#### Primary S2S VPN Script
**File:** `@-Azure-CLI/Claude/S2S-VPN-GW-LNG-v2.sh`

This script creates a complete Site-to-Site VPN connection including:
- Resource Group
- Virtual Network with Gateway Subnet
- VPN Gateway (takes 30-45 minutes)
- Local Network Gateway (represents on-premises network)
- VPN Connection with IPSec tunnel

**Key Features:**
- Configurable VPN Gateway SKU
- Static Public IP for VPN Gateway
- IPSec tunnel with shared key
- Local network gateway for on-premises connectivity

**Usage:**
```bash
# Edit variables in the script
RESOURCE_GROUP="Claude-rg4"
LOCATION="southafricanorth"
LOCAL_GATEWAY_PUBLIC_IP="156.155.28.158"
LOCAL_NETWORK_PREFIX="192.168.2.0/24"
SHARED_KEY="YourSharedKey"

# Run the script
bash @-Azure-CLI/Claude/S2S-VPN-GW-LNG-v2.sh
```

---

#### Comprehensive On-Premises to Azure S2S VPN
**File:** `@-Azure-CLI/Infra-as-Code/OnPrem-to-Azure-S2S-v6.sh`

This is the most comprehensive script that creates:
- Two VNets (simulating on-premises and Azure)
- VPN Gateways on both sides
- Multiple VMs for testing connectivity
- Azure Firewall integration
- Multiple CIDR blocks and subnets
- Parallel deployment of resources for faster provisioning

**Key Features:**
- Dual VPN Gateway setup (both sides of the tunnel)
- Parallel resource deployment
- Azure Firewall integration
- Multiple VMs for testing
- Comprehensive timing and progress reporting
- Support for multiple CIDR blocks

**Network Configuration:**
- On-Premises: 192.168.0.0/22, 192.168.4.0/22
- Azure: 10.70.0.0/22
- Firewall Subnet: 10.70.3.0/26

---

### 1.2 PowerShell Scripts

#### S2S VPN Connection Management
**File:** `@-PowerShell/3-Create and manage S2S VPN connections.ps1`

PowerShell script for creating and managing Site-to-Site VPN connections with:
- Local Network Gateway creation
- VPN Gateway connection with IPSec
- BGP configuration support
- Custom IPsec/IKE policy configuration
- Shared key management

**Key Components:**
```powershell
# Variables
$RG1 = "TestRG1"
$VNet1 = "VNet1"
$LNG1 = "VPNsite1"
$LNGIP1 = "5.4.3.2"  # On-premises VPN device public IP
$Connection1 = "VNet1ToSite1"

# Create Local Network Gateway
New-AzLocalNetworkGateway -Name $LNG1 -ResourceGroupName $RG1 `
  -Location 'East US' -GatewayIpAddress $LNGIP1 -AddressPrefix $LNGprefix1,$LNGprefix2

# Create S2S VPN Connection
New-AzVirtualNetworkGatewayConnection -Name $Connection1 -ResourceGroupName $RG1 `
  -Location $Location1 -VirtualNetworkGateway1 $vng1 -LocalNetworkGateway2 $lng1 `
  -ConnectionType IPsec -SharedKey "Azure@!b2C3" -ConnectionProtocol IKEv2
```

**Advanced Features:**
- BGP (Border Gateway Protocol) support
- Custom IPsec/IKE policy with configurable algorithms:
  - IKEv2: AES256, SHA256, DHGroup14
  - IPsec: AES128, SHA1, PFS14
- Shared key rotation
- Connection protocol configuration

---

### 1.3 Bicep Templates

#### Complete S2S VPN with Local Network Gateway
**File:** `@-Bicep/Infra-as-Code/Networking/@4-S2S+LNG+Connection+VPN-GW.bicep`

Infrastructure as Code template for deploying:
- Virtual Network with Gateway Subnet
- VPN Gateway with configurable SKU
- Local Network Gateway
- IPSec Connection

**Parameters:**
- `vpnType`: RouteBased or PolicyBased
- `localGatewayIpAddress`: Public IP of on-premises VPN device
- `localAddressPrefix`: CIDR blocks of on-premises network
- `gatewaySku`: VPN Gateway SKU (VpnGw1-5, Standard, HighPerformance)
- `sharedKey`: Pre-shared key for IPSec tunnel (secure parameter)

**Deployment:**
```bash
az deployment group create \
  --resource-group YourRG \
  --template-file @-Bicep/Infra-as-Code/Networking/@4-S2S+LNG+Connection+VPN-GW.bicep \
  --parameters sharedKey='YourSecureKey' localGatewayIpAddress='1.2.3.4'
```

---

#### S2S VPN with BGP
**File:** `@-Bicep/Infra-as-Code/Networking/2-vpn-gw-S2S-IPSec-with-bgp.bicep`

VNet-to-VNet connection with BGP enabled:
- Two Virtual Networks
- VPN Gateways on both sides
- BGP configuration with ASN numbers
- Bidirectional VPN connections

**Key Features:**
- BGP enabled for dynamic routing
- Configurable ASN (Autonomous System Number)
- Bidirectional connections
- VNet-to-VNet topology

---

## 2. VPN Gateway Configuration

### 2.1 VPN Gateway with Express Route Coexistence

**File:** `@-PowerShell/Build ER GW in same VNET as VPN GW sharing same GateWay Subnet.ps1`

This script demonstrates how to configure both VPN Gateway and ExpressRoute Gateway in the same VNet:
- Shared Gateway Subnet
- Coexistence configuration
- Multiple gateway types in same network

---

### 2.2 VPN Gateway with Multiple Subnets

**File:** `@-PowerShell/2-Config a VPN GW with 2 SubNets GW Subnet and Pub-IP.ps1`

Creates a VPN Gateway with:
- Gateway Subnet configuration
- Public IP assignment
- Multiple subnet support

---

## 3. Advanced VPN Scenarios

### 3.1 Virtual WAN with VPN

**Files:**
- `@-Azure-CLI/Claude/vWAN-Site+S2S-VPN.sh`
- `@-Azure-CLI/Claude/Claude-vWAN-VPN-GW+ER-GW-v1.sh`
- `@-Azure-CLI/Claude/Claude-vWAN-2-hubs-2-vnets-2VM-VPN-GW+ER-GW-v2.sh`

These scripts create Virtual WAN (vWAN) configurations with:
- Multiple hubs
- Multiple VNets
- Site-to-Site VPN connections
- ExpressRoute Gateway integration
- VM deployments for testing

**Key Features:**
- Hub-and-spoke topology
- Multiple regions
- Scalable architecture
- Integrated routing

---

### 3.2 VPN Gateway with BGP

**File:** `@-PowerShell/BGP-LTSA-VPN-GW-test- Config a VPN GW in same GateWay SubNet as ER GW.ps1`

BGP-enabled VPN Gateway configuration for:
- Dynamic routing
- BGP peering
- ASN configuration
- Route propagation

---

## 4. VPN Diagnostics and Troubleshooting

### 4.1 VPN Gateway Packet Capture

**Files:**
- `@-PowerShell/VPN Tunnel Packet Capture/Daniel-Mauser-vWAN-VPN-Packet-Capture.ps1`
- `@-Azure-CLI/vpn-gw-packet-capture/azure-vpngw-packet-capture_Version2.ps1`
- `@-Azure-CLI/vpn-gw-packet-capture/azure-vpngw-packet-capture_Version2.sh`

These scripts enable packet capture on VPN Gateway for troubleshooting:
- Start/Stop packet capture
- Filter configuration
- SAS URL for storing captures
- Analysis of VPN traffic

**Usage Example:**
```powershell
# Start VPN Gateway packet capture
Start-AzVpnGatewayPacketCapture -ResourceGroupName $RG -Name $GWName -FilterData $Filter

# Stop and retrieve capture
Stop-AzVpnGatewayPacketCapture -ResourceGroupName $RG -Name $GWName -SasUrl $SAStokenURL
```

---

### 4.2 VPN Gateway Route Diagnostics

**Files:**
- `@-PowerShell/@-ER GW+ VPN GW debug commands/ER - VPN GW Learned Routes List and Count.ps1`
- `@-PowerShell/@-ER GW+ VPN GW debug commands/@-Use own VARIABLEs -- ER - VPN GW Learned Routes List and Count.ps1`

Scripts for viewing and analyzing:
- BGP learned routes
- Route counts
- Gateway routing tables
- Connection status

---

## 5. Quick Reference Scripts

### 5.1 Sandbox Testing Script

**File:** `Sandbox/S2S-VPN-Connection.sh`

A simplified script for quick testing and learning VPN configurations.

---

## 6. On-Premises Device Configuration

### 6.1 MikroTik RouterOS Configuration

**File:** `@-Azure-CLI/Claude/# MikroTik RouterOS v7 IPSec VPN Config.ini`

Configuration file for MikroTik RouterOS devices to connect to Azure VPN Gateway.

---

## Key Concepts

### VPN Gateway SKUs
- **Basic**: Legacy SKU, limited features
- **VpnGw1**: Standard performance, recommended for most workloads
- **VpnGw2**: Higher bandwidth requirements
- **VpnGw3**: High-performance scenarios
- **VpnGw4-5**: Premium performance tiers

### Connection Types
- **IPsec**: Site-to-Site VPN tunnel
- **Vnet2Vnet**: Azure VNet-to-VNet connection
- **ExpressRoute**: Dedicated private connection (coexists with VPN)

### VPN Types
- **RouteBased**: Dynamic routing, supports multiple tunnels (recommended)
- **PolicyBased**: Static routing, single tunnel

### BGP Support
- Dynamic route exchange
- Automatic failover
- Multi-site connectivity
- Route aggregation

---

## Common Variables Used Across Scripts

```bash
# Resource Group
RESOURCE_GROUP="vpn-demo-rg"
LOCATION="southafricanorth"

# Network Configuration
VNET_PREFIX="10.0.0.0/16"
GATEWAY_SUBNET_PREFIX="10.0.0.0/27"
WORKLOAD_SUBNET_PREFIX="10.0.1.0/24"

# VPN Gateway
VPN_GATEWAY_NAME="vpn-gateway"
VPN_GATEWAY_SKU="VpnGw1"
GATEWAY_PUBLIC_IP_NAME="vpn-gateway-pip"

# Local Network Gateway (On-Premises)
LOCAL_GATEWAY_NAME="local-gateway"
LOCAL_GATEWAY_PUBLIC_IP="x.x.x.x"
LOCAL_NETWORK_PREFIX="192.168.0.0/16"

# Connection
CONNECTION_NAME="azure-to-onprem"
SHARED_KEY="YourSecureSharedKey"

# BGP (Optional)
ASN="65515"
BGP_PEER_IP="10.0.0.254"
```

---

## Deployment Time Estimates

- **VPN Gateway Creation**: 30-45 minutes
- **Azure Firewall**: 10-15 minutes
- **VNet Peering**: 1-2 minutes
- **VM Creation**: 5-10 minutes
- **Connection Establishment**: 2-5 minutes

**Total S2S VPN Deployment**: Approximately 45-60 minutes

---

## Security Best Practices

1. **Use Strong Shared Keys**: Minimum 20 characters, mix of upper/lower/numbers/symbols
2. **Enable BGP**: For dynamic routing and automatic failover
3. **Use Route-Based VPN**: More flexible than Policy-Based
4. **Implement Network Security Groups**: Control traffic flow
5. **Use Latest VPN Gateway SKUs**: Better performance and features
6. **Enable Gateway Diagnostics**: For troubleshooting
7. **Implement Azure Firewall**: For additional security layer
8. **Regular Key Rotation**: Change shared keys periodically
9. **Monitor Connection Health**: Use Azure Monitor
10. **Use IKEv2 Protocol**: More secure than IKEv1

---

## Testing Connectivity

After deployment, test VPN tunnel connectivity:

```bash
# Check connection status
az network vpn-connection show \
  --resource-group $RESOURCE_GROUP \
  --name $CONNECTION_NAME \
  --query connectionStatus

# Test connectivity from VM
ssh user@vm-ip
ping <remote-vm-private-ip>

# Check BGP routes
az network vnet-gateway list-bgp-peer-status \
  --resource-group $RESOURCE_GROUP \
  --name $VPN_GATEWAY_NAME
```

---

## Additional Resources

### Microsoft Documentation
- [VPN Gateway Documentation](https://docs.microsoft.com/azure/vpn-gateway/)
- [Site-to-Site VPN Connections](https://docs.microsoft.com/azure/vpn-gateway/vpn-gateway-howto-site-to-site-resource-manager-portal)
- [BGP with VPN Gateway](https://docs.microsoft.com/azure/vpn-gateway/vpn-gateway-bgp-overview)

### Related Scripts in Repository
- Azure Firewall: `@-PowerShell/@-AzFW/`
- ExpressRoute: `@-PowerShell/1-LTSA- Config a ER GW with 2 SubNets GW Subnet and Pub-IP.ps1`
- Virtual WAN: `@-PowerShell/Fabrizio/vWAN Power Shell Scripts/`

---

## Summary

This repository contains extensive VPN tunnel building code covering:
- ✅ Basic Site-to-Site VPN configurations
- ✅ Advanced BGP-enabled VPN setups
- ✅ Virtual WAN integration
- ✅ Multiple deployment methods (PowerShell, Azure CLI, Bicep)
- ✅ Diagnostic and troubleshooting tools
- ✅ Production-ready templates with security best practices
- ✅ Testing and validation scripts

Choose the appropriate script based on your requirements:
- **Quick Setup**: `@-Azure-CLI/Claude/S2S-VPN-GW-LNG-v2.sh`
- **Comprehensive Demo**: `@-Azure-CLI/Infra-as-Code/OnPrem-to-Azure-S2S-v6.sh`
- **Infrastructure as Code**: Bicep templates in `@-Bicep/Infra-as-Code/`
- **PowerShell Automation**: Scripts in `@-PowerShell/`
