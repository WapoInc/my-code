# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains Azure CLI shell scripts for deploying ExpressRoute infrastructure for Shoprite across multiple Azure regions. The scripts automate the creation of ExpressRoute gateways, virtual networks, Ubuntu VMs, and ExpressRoute connections.

## Commands

### Running Scripts
All scripts are executable and can be run directly:
```bash
# Deploy infrastructure in a specific region
./SR-1-West-EU-ER-GW-ER-Conn-Ubuntu-VM.sh
./SR-2-ZAW-ER-GW-ER-Conn-Ubuntu-VM.sh
./SR-3-ZAN-ER-GW-ER-Conn-Ubuntu-VM.sh
./SR-4-UK-South-ER-GW-ER-Conn-Ubuntu-VM.sh

# Connect ExpressRoute gateway to circuit
./SR-ER-Connections.sh
```

### Prerequisites
Scripts require Azure CLI to be installed and authenticated:
```bash
az login
az account set --subscription <subscription-id>
```

## Architecture

### Script Structure
- **Regional deployment scripts**: Create complete infrastructure stack including VNet, ExpressRoute gateway, and Ubuntu VM
- **Connection script**: Links ExpressRoute gateway to existing ExpressRoute circuit

### Key Components
Each regional script deploys:
- Resource Group
- Virtual Network with Gateway and Internal subnets
- ExpressRoute Gateway (Standard SKU) - takes 30-45 minutes
- Ubuntu 22.04 LTS VM with SSH access
- Network Security Group with SSH rules
- Auto-shutdown configuration for VMs

### Regional Configuration
- **SR-1**: West Europe (westeurope) - 10.51.0.0/22
- **SR-2**: South Africa West (southafricawest) - 10.52.0.0/22  
- **SR-3**: South Africa North (southafricanorth) - 10.53.0.0/22
- **SR-4**: UK South (uksouth) - 10.54.0.0/22

### ExpressRoute Configuration
All scripts reference the same ExpressRoute circuit:
- **Circuit**: ER-LIT-SA-North
- **Circuit Resource Group**: ER-LTSA-RG
- **Target Resource Group**: Claude-rg4

### Naming Conventions
Resources follow consistent naming pattern:
- VNets: `{region}-vnet-azure-hub`
- Gateways: `{region}-ergw-azure-hub` 
- VMs: `{region}-ubuntu2204-vm`
- PIPs: `{region}-pip-ergw-hub`

### Important Notes
- ExpressRoute gateway provisioning takes 30-45 minutes
- Scripts include wait conditions and status checks
- VM auto-shutdown configured for 7 PM daily to save costs
- SSH keys are auto-generated during VM creation
- All deployments target the same resource group (Claude-rg4)