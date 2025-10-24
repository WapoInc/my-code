# VPN Tunnel Quick Start Guide

This guide will help you quickly get started with building a VPN tunnel using the code in this repository.

## 🚀 Quick Start - Site-to-Site VPN

### Option 1: Azure CLI (Recommended for Quick Setup)

**Prerequisites:**
- Azure CLI installed and configured
- Active Azure subscription
- On-premises VPN device public IP address

**Steps:**

1. **Navigate to the script:**
```bash
cd @-Azure-CLI/Claude/
```

2. **Edit the script variables:**
```bash
nano S2S-VPN-GW-LNG-v2.sh
```

3. **Update these key variables:**
```bash
RESOURCE_GROUP="your-rg-name"
LOCATION="your-azure-region"
LOCAL_GATEWAY_PUBLIC_IP="your-onprem-device-ip"
LOCAL_NETWORK_PREFIX="your-onprem-network-cidr"
SHARED_KEY="your-secure-shared-key"
```

4. **Run the script:**
```bash
bash S2S-VPN-GW-LNG-v2.sh
```

5. **Wait for deployment** (approximately 45 minutes for VPN Gateway)

6. **Verify connection:**
```bash
az network vpn-connection show \
  --resource-group your-rg-name \
  --name conn-azure-to-onprem \
  --query connectionStatus
```

---

### Option 2: PowerShell

**Prerequisites:**
- Azure PowerShell module installed
- Authenticated to Azure (`Connect-AzAccount`)
- Existing VNet with Gateway

**Steps:**

1. **Navigate to the script:**
```powershell
cd @-PowerShell/
```

2. **Open the script:**
```powershell
notepad "3-Create and manage S2S VPN connections.ps1"
```

3. **Update variables at the top:**
```powershell
$RG1 = "YourResourceGroup"
$VNet1 = "YourVNetName"
$LNG1 = "YourLocalNetworkGateway"
$LNGIP1 = "YourOnPremPublicIP"
$Connection1 = "YourConnectionName"
```

4. **Run the script:**
```powershell
.\3-Create and manage S2S VPN connections.ps1
```

---

### Option 3: Bicep (Infrastructure as Code)

**Prerequisites:**
- Azure CLI with Bicep support
- Basic understanding of Bicep templates

**Steps:**

1. **Navigate to templates:**
```bash
cd @-Bicep/Infra-as-Code/Networking/
```

2. **Deploy the template:**
```bash
az deployment group create \
  --resource-group your-rg-name \
  --template-file @4-S2S+LNG+Connection+VPN-GW.bicep \
  --parameters \
    sharedKey='YourSecureKey123!' \
    localGatewayIpAddress='1.2.3.4' \
    location='southafricanorth'
```

---

## 📋 Common Configuration Values

### VPN Gateway SKUs

| SKU | Max Tunnels | Bandwidth | Use Case |
|-----|------------|-----------|----------|
| VpnGw1 | 30 | 650 Mbps | Small-medium workloads |
| VpnGw2 | 30 | 1 Gbps | Medium workloads |
| VpnGw3 | 30 | 1.25 Gbps | Large workloads |
| VpnGw4 | 100 | 5 Gbps | Enterprise |
| VpnGw5 | 100 | 10 Gbps | High-performance |

### Recommended Shared Key Format
- Minimum 20 characters
- Mix of uppercase, lowercase, numbers, and symbols
- Example: `Secure@VPN!Key#2024$Azure%`

### Common Azure Regions
- `eastus` - East US
- `westus2` - West US 2
- `southafricanorth` - South Africa North
- `westeurope` - West Europe
- `northeurope` - North Europe

---

## 🔍 Testing Your VPN Connection

### 1. Check Connection Status

**Azure CLI:**
```bash
az network vpn-connection show \
  --resource-group <rg-name> \
  --name <connection-name> \
  --query '{Status:connectionStatus, EgressBytes:egressBytesTransferred, IngressBytes:ingressBytesTransferred}'
```

**PowerShell:**
```powershell
Get-AzVirtualNetworkGatewayConnection -Name <connection-name> -ResourceGroupName <rg-name>
```

### 2. Test Connectivity from Azure VM

```bash
# SSH into Azure VM
ssh azureuser@<vm-public-ip>

# Ping on-premises private IP
ping <onprem-private-ip>

# Test specific port
nc -zv <onprem-private-ip> 22
```

### 3. View BGP Routes (if BGP enabled)

```bash
az network vnet-gateway list-bgp-peer-status \
  --resource-group <rg-name> \
  --name <gateway-name>
```

---

## 🛠️ Troubleshooting

### Connection Status is "Not Connected"

1. **Verify shared keys match on both sides**
```bash
az network vpn-connection show-shared-key \
  --resource-group <rg-name> \
  --name <connection-name>
```

2. **Check on-premises firewall allows:**
   - UDP port 500 (IKE)
   - UDP port 4500 (IPsec NAT-T)
   - IP Protocol 50 (ESP)

3. **Verify gateway public IP**
```bash
az network public-ip show \
  --resource-group <rg-name> \
  --name <gateway-pip-name> \
  --query ipAddress
```

### Slow Performance

1. **Check VPN Gateway SKU** - Upgrade if needed
2. **Enable BGP** for better routing
3. **Check bandwidth utilization** in Azure Monitor
4. **Verify no packet loss** on network path

### Enable Packet Capture

For advanced troubleshooting:
```bash
# Use the packet capture script
cd @-Azure-CLI/vpn-gw-packet-capture/
bash azure-vpngw-packet-capture_Version2.sh
```

---

## 📊 Deployment Timeline

Typical deployment times:

| Component | Time | Notes |
|-----------|------|-------|
| Resource Group | < 1 min | Instant |
| Virtual Network | < 1 min | Quick |
| Gateway Subnet | < 1 min | Quick |
| Public IP | < 1 min | Quick |
| **VPN Gateway** | **30-45 min** | **Longest wait** |
| Local Network Gateway | < 1 min | Quick |
| VPN Connection | 2-5 min | Quick |
| Connection Active | 2-5 min | After creation |

**Total: ~45-60 minutes** (mostly waiting for VPN Gateway)

💡 **Tip:** Use `--no-wait` flag in Azure CLI to start deployment asynchronously and continue with other tasks.

---

## 🔐 Security Checklist

Before going to production:

- ✅ Use strong shared key (20+ characters)
- ✅ Enable BGP for redundancy
- ✅ Use Route-Based VPN (not Policy-Based)
- ✅ Implement Network Security Groups
- ✅ Use VpnGw1 or higher SKU (not Basic)
- ✅ Enable VPN Gateway diagnostics
- ✅ Set up Azure Monitor alerts
- ✅ Document configuration
- ✅ Test failover scenarios
- ✅ Regular key rotation schedule

---

## 📚 Next Steps

After basic VPN is working:

1. **Add BGP** - See `2-vpn-gw-S2S-IPSec-with-bgp.bicep`
2. **Add Azure Firewall** - See `OnPrem-to-Azure-S2S-v6.sh`
3. **Configure Custom IPsec Policy** - See PowerShell script examples
4. **Set up Monitoring** - Use Azure Monitor and diagnostics
5. **Test Failover** - Verify redundancy and failover times

---

## 💡 Pro Tips

1. **Parallel Deployments**: Deploy VPN Gateways in parallel to save time
   ```bash
   az network vnet-gateway create ... --no-wait &
   ```

2. **Gateway Sizing**: Start with VpnGw1, scale up if needed

3. **BGP is Your Friend**: Enable BGP for better failover and routing

4. **Test Before Production**: Use the comprehensive test script in `OnPrem-to-Azure-S2S-v6.sh` to simulate your environment

5. **Monitor Everything**: Set up alerts for connection status, throughput, and packet drops

---

## 🆘 Need More Help?

- **Full Reference**: See [VPN-TUNNEL-CODE-REFERENCE.md](VPN-TUNNEL-CODE-REFERENCE.md)
- **Diagnostic Scripts**: Check `@-PowerShell/@-ER GW+ VPN GW debug commands/`
- **Packet Capture**: See `@-PowerShell/VPN Tunnel Packet Capture/`

---

## 📞 Support Resources

- [Azure VPN Gateway Documentation](https://docs.microsoft.com/azure/vpn-gateway/)
- [Troubleshooting Guide](https://docs.microsoft.com/azure/vpn-gateway/vpn-gateway-troubleshoot)
- [BGP Configuration](https://docs.microsoft.com/azure/vpn-gateway/vpn-gateway-bgp-overview)

---

**Remember:** VPN Gateway deployment takes 30-45 minutes. Plan accordingly and be patient! ⏰
