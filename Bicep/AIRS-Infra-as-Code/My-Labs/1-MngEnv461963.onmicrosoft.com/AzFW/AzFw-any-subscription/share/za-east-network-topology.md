# ZA-East network topology (southafricanorth)

Subscription `29df7078-…` · Resource group `za-east-southafricanorth`. Shows the
hub-and-spoke network, Azure Firewall Basic, the route-based VPN gateway, and the
site-to-site IPsec tunnel to the on-premises FortiGate.

```mermaid
%%{init: {'flowchart': {'curve': 'step'}}}%%
flowchart TB
  subgraph OnPrem["On-premises site"]
    LAN["LAN<br/>192.168.2.0/24"]
    FG["FortiGate<br/>WAN wan2 = 169.0.216.146<br/>LAN int = b"]
    LAN --- FG
  end

  INET(("Internet"))

  subgraph AZ["Azure — RG za-east-southafricanorth"]
    subgraph HUB["Hub VNet za-east-southafricanorth-vnet · 10.20.0.0/16"]
      GWSUB["GatewaySubnet<br/>10.20.0.0/24"]
      HUBSUB["ZA-East-Hub 10.20.1.0/24<br/>+ default NSG"]
      FWSUB["AzureFirewallSubnet<br/>10.20.6.64/26"]
      FWMGSUB["AzureFirewallManagementSubnet<br/>10.20.7.0/24"]
      PINGSUB["Ping-test<br/>10.20.8.0/24"]
    end

    VPNPIP["VPN gateway Public IP<br/>20.87.106.128<br/>Standard · zones 1/2/3"]
    VPNGW["VPN gateway<br/>za-east-southafricanorth-vpngw<br/>Basic · RouteBased · Gen1"]
    CONN["Connection<br/>za-east-southafricanorth-to-fortigate<br/>IPsec · IKEv2 · PSK"]
    LNG["Local network gateway<br/>za-east-southafricanorth-fortigate-lng<br/>169.0.216.146 · 192.168.2.0/24"]

    AZFW["Azure Firewall Basic<br/>AzFW-ZA-East-vDC"]
    FWPIP["Firewall data Public IP"]
    FWMGPIP["Firewall mgmt Public IP"]
    POLICY["Firewall policy<br/>app + network rules"]
    LAW["Log Analytics<br/>AzFW-Basic-LA"]

    subgraph SPOKES["Spoke VNets"]
      S1["spoke-1-vnet 10.21.0.0/24<br/>Subnet-1"]
      S2["spoke-2-vnet 10.22.0.0/24<br/>Subnet-1"]
      S3["spoke-3-vnet 10.23.0.0/24<br/>Subnet-1"]
    end
  end

  %% Site-to-site VPN path
  FG === INET
  INET === VPNPIP
  VPNPIP --- VPNGW
  VPNGW --- GWSUB
  VPNGW --- CONN
  CONN --- LNG
  LNG -. represents on-prem .-> FG

  %% Firewall attachments
  FWPIP --- AZFW
  FWMGPIP --- AZFW
  POLICY --- AZFW
  AZFW --- FWSUB
  AZFW --- FWMGSUB
  AZFW -. diagnostics .-> LAW
  AZFW === INET

  %% Forced tunneling via UDRs (next hop = firewall private IP)
  HUBSUB -->|UDR next hop| AZFW
  PINGSUB -->|UDR next hop| AZFW
  S1 -->|UDR next hop| AZFW
  S2 -->|UDR next hop| AZFW
  S3 -->|UDR next hop| AZFW

  %% VNet peerings
  HUB <-->|peering| S1
  HUB <-->|peering| S2
  HUB <-->|peering| S3

  %% Peering links drawn in orange (link indices 19-21)
  linkStyle 19,20,21 stroke:#ff9800,stroke-width:2px;

  classDef onprem fill:#fde7b3,stroke:#b8860b,color:#000;
  classDef vpn fill:#dcedc8,stroke:#558b2f,color:#000;
  classDef fw fill:#bbdefb,stroke:#1565c0,color:#000;
  classDef spoke fill:#e1bee7,stroke:#6a1b9a,color:#000;

  class LAN,FG onprem;
  class VPNPIP,VPNGW,CONN,LNG vpn;
  class AZFW,FWPIP,FWMGPIP,POLICY,LAW fw;
  class S1,S2,S3 spoke;
```

## Resource inventory

| Resource | Type | Key detail |
|---|---|---|
| `za-east-southafricanorth-vnet` | Virtual network | Hub `10.20.0.0/16` |
| `GatewaySubnet` | Subnet | `10.20.0.0/24` — hosts VPN gateway |
| `ZA-East-Hub` | Subnet | `10.20.1.0/24` + default NSG |
| `AzureFirewallSubnet` | Subnet | `10.20.6.64/26` |
| `AzureFirewallManagementSubnet` | Subnet | `10.20.7.0/24` |
| `Ping-test` | Subnet | `10.20.8.0/24` |
| `za-east-spoke-1/2/3-vnet` | Virtual networks | `10.21/22/23.0.0/24`, peered to hub |
| `AzFW-ZA-East-vDC` | Azure Firewall Basic | Data + mgmt public IPs, policy |
| `AzFW-Basic-LA` | Log Analytics workspace | Firewall diagnostics |
| `za-east-southafricanorth-vpngw` | VPN gateway | Basic, RouteBased, Gen1 |
| `za-east-southafricanorth-vpngw-pip` | Public IP | `20.87.106.128`, Standard, zones 1/2/3 |
| `za-east-southafricanorth-fortigate-lng` | Local network gateway | `169.0.216.146`, `192.168.2.0/24` |
| `za-east-southafricanorth-to-fortigate` | Connection | IPsec, IKEv2, PSK |
| On-prem FortiGate | External device | `wan2` = `169.0.216.146`, LAN int `b` |
```
