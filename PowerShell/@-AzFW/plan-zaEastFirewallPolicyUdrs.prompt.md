## Plan: ZA-East Firewall Policy and UDRs

Extend the existing ZA-East Bicep deployment to create a new Azure Firewall Basic named `AzFW-ZA-East-vDC` and Basic Firewall Policy named `AzFW-ZA-East-vDC-Policy-1` in resource group `za-east-southafricanorth`. Route all three spoke workload subnets and all live-confirmed hub VM workload subnets through the firewall for spoke-to-spoke, hub-to-spoke, and Azure-to-on-premises traffic. Add reciprocal routes on `GatewaySubnet` so on-premises return traffic reaches hub and spoke networks through the firewall.

**Selected topology**

| Network | Prefix | Routed workload subnet |
|---|---:|---|
| Hub VNet `za-east-southafricanorth-vnet` | `10.20.0.0/16` | `ZA-East-Hub` `10.20.1.0/24`, `Ping-test` `10.20.8.0/24`, plus other subnets that live inventory confirms contain VMs |
| Spoke 1 `za-east-spoke-1-vnet` | `10.21.0.0/24` | `Subnet-1` `10.21.0.0/25` |
| Spoke 2 `za-east-spoke-2-vnet` | `10.22.0.0/24` | `Subnet-1` `10.22.0.0/25` |
| Spoke 3 `za-east-spoke-3-vnet` | `10.23.0.0/24` | `Subnet-1` `10.23.0.0/25` |
| On-premises | Discovered from live VPN gateway BGP/learned routes | Routed through hub `GatewaySubnet` |

**Named resources**

| Resource | Name |
|---|---|
| Azure Firewall | `AzFW-ZA-East-vDC` |
| Firewall Policy | `AzFW-ZA-East-vDC-Policy-1` |
| Firewall public IP | `AzFW-ZA-East-vDC-Pub-IP` |
| Policy rule collection group | `AzFW-ZA-East-vDC-Policy-1-Private-RCG` |
| Spoke route tables | `rt-za-east-spoke-1-via-azfw`, `rt-za-east-spoke-2-via-azfw`, `rt-za-east-spoke-3-via-azfw` |
| Hub workload route table | `rt-za-east-hub-workloads-via-azfw` |
| Gateway return route table | `rt-za-east-gateway-return-via-azfw` |

**Route design**

1. Each spoke receives its own route table with gateway route propagation disabled. Routes point the other two spoke VNet prefixes, hub workload prefixes, and every discovered on-premises prefix to the firewall private IP using next-hop type `VirtualAppliance`. Add `0.0.0.0/0 -> firewall private IP` only because the earlier scope selected firewall-controlled Internet egress.
2. The hub workload route table points all three spoke VNet prefixes and all discovered on-premises prefixes to the firewall private IP. It also includes `0.0.0.0/0 -> firewall private IP` for firewall-controlled Internet egress. Associate it only with live-confirmed VM workload subnets, including `ZA-East-Hub` and `Ping-test`.
3. The `GatewaySubnet` route table keeps gateway/BGP route propagation enabled. It contains explicit routes for `10.21.0.0/24`, `10.22.0.0/24`, `10.23.0.0/24`, and routed hub workload prefixes such as `10.20.1.0/24` and `10.20.8.0/24`, all pointing to the firewall private IP. It must not contain a `0.0.0.0/0` route.
4. Do not attach route tables to `AzureFirewallSubnet`, `AzureFirewallManagementSubnet`, `AzureBastionSubnet`, DNS Resolver subnets, `PEP`, or `AppGW-SubNet`. Do not route same-subnet traffic through the firewall; NSGs remain responsible for same-subnet segmentation.
5. `AzureFirewallSubnet` normally learns on-premises routes from BGP, so no UDR is required. If live inspection finds an on-premises-advertised `0.0.0.0/0`, add only `0.0.0.0/0 -> Internet` to preserve direct Internet connectivity for this non-forced-tunnel firewall.
6. Existing peerings already set `allowForwardedTraffic: true`; preserve it. Preserve hub `allowGatewayTransit` and spoke `useRemoteGateways` when a supported VPN gateway is deployed.

**Firewall Policy design**

- Create a Basic-SKU policy and attach it to the Basic firewall.
- Create one network rule collection group with an Allow collection for private inter-site traffic.
- Sources and destinations are the union of hub workload prefixes, `10.21.0.0/24`, `10.22.0.0/24`, `10.23.0.0/24`, and live-discovered on-premises prefixes.
- Allow protocol `Any` and destination ports `*` among these private prefixes, as explicitly selected for the lab. Keep Internet egress denied unless separate application/network allow rules are approved; a `0.0.0.0/0` UDR alone does not permit traffic through Azure Firewall.
- Do not add DNAT, TLS inspection, IDPS, or forced-tunneling rules.

**Steps**

### Phase 1: Read-only Azure discovery

1. Select the intended subscription/tenant and inventory resource group `za-east-southafricanorth`. Verify the actual VNet name, all VNet/subnet prefixes, NIC-to-subnet placement, peerings, VPN gateway SKU/state, current route-table associations, public IPs, existing firewall/policy names, locks, and Azure Policy assignments.
2. Query the VPN gateway learned routes/BGP peers and effective routes. Normalize the on-premises CIDRs, remove Azure hub/spoke prefixes and any unexpected/default routes, and present the resulting on-premises prefix list for approval before creating UDRs or policy rules.
3. Confirm every intended hub subnet actually hosts VMs. Include `ZA-East-Hub` and `Ping-test`; include `ZA-East-Subnet-1`, `ZA-East-Subnet-2`, `CloudShell`, or others only if live inventory confirms they are workload subnets and the service permits a route-table association. Exclude all infrastructure/delegated/private-endpoint subnets.
4. Verify the VPN gateway supports gateway transit. The repository notes Basic VPN Gateway does not support gateway transit; if the live gateway is Basic, upgrade/rework the gateway or remove `useRemoteGateways` from the design before rollout.

### Phase 2: Focused Bicep changes

5. Extend `ZA-East-Hub-resources.bicep` with parameters for firewall deployment, policy/rule deployment, approved on-premises prefixes, protected hub subnet names/prefixes, and optional Internet egress. Avoid hardcoding the firewall private IP because it is allocated at deployment.
6. Add a zone-compatible Standard Static public IP, Basic Firewall Policy `AzFW-ZA-East-vDC-Policy-1`, Azure Firewall Basic `AzFW-ZA-East-vDC`, and the private inter-site policy rule collection group. Attach the policy to the firewall.
7. Add route tables and routes using the deployed firewall private IP. Create one table per spoke, one shared table for compatible hub workload subnets, and one gateway return table. Set `disableBgpRoutePropagation: true` on spoke tables; retain propagation on `GatewaySubnet` and on the hub workload table unless live route analysis requires explicit suppression.
8. Associate each spoke table with its matching `Subnet-1`, the hub workload table with approved hub VM subnets, and the gateway return table with `GatewaySubnet`. Preserve all existing subnet properties and dependencies.
9. Add outputs for firewall name, policy name, firewall private/public IP, and route-table IDs. Update the subscription orchestrator outputs and the deployment script prompts/summary for approved on-premises prefixes and firewall deployment settings.
10. Add diagnostics to an approved Log Analytics workspace if one exists; otherwise parameterize diagnostics so deployment can proceed only after an explicit choice to create/use a workspace or skip logging for the lab.

### Phase 3: Validation and staged rollout

11. Compile/lint both Bicep files and run subscription deployment validation and `what-if`. Reject a plan that recreates the VNet, drops existing subnet properties, changes gateway settings unexpectedly, or associates routes with excluded infrastructure subnets.
12. Deploy the firewall, policy, and rules first without route-table associations. Capture and verify the firewall private IP and confirm the policy is attached and provisioned.
13. Deploy/associate the gateway return route table and one test spoke route table. Validate effective routes and use Network Watcher next-hop/connection troubleshoot for spoke-to-spoke and spoke-to-on-premises in both directions.
14. Associate the remaining spoke tables, then `ZA-East-Hub` and `Ping-test`, followed by any other approved hub workload subnets. Validate after each association and keep the prior route-table ID for rollback.
15. Test hub-to-spoke, spoke-to-spoke, hub-to-on-premises, spoke-to-on-premises, and return flows. Confirm firewall network-rule logs show the expected source, destination, and allow rule.
16. Document that deallocating/reallocating Azure Firewall can change its private IP and break all UDR next hops. Prefer keeping the firewall allocated; if stop/start remains an operational requirement, add a controlled start procedure that detects an IP change and redeploys/updates the route tables before restoring traffic.

**Relevant files**

- `/Users/vinceresente/my-code/Bicep/AIRS-Infra-as-Code/My-Labs/1-MngEnv461963.onmicrosoft.com/ZA-East/ZA-East-Hub-resources.bicep` — owning resource-group module; add firewall, policy, rules, route tables, routes, subnet associations, and outputs here.
- `/Users/vinceresente/my-code/Bicep/AIRS-Infra-as-Code/My-Labs/1-MngEnv461963.onmicrosoft.com/ZA-East/ZA-East-Hub-resources-rg.bicep` — pass firewall/on-premises parameters into the module and expose outputs.
- `/Users/vinceresente/my-code/Bicep/AIRS-Infra-as-Code/My-Labs/1-MngEnv461963.onmicrosoft.com/ZA-East/deploy-za-east-hub.sh` — gather approved on-premises CIDRs and firewall options, run validation/what-if, and summarize names/IPs.
- `/Users/vinceresente/my-code/PowerShell/@-AzFW/Az-FW-Stop-Start-vmr-AzFW-Premium-to-FT-using-PS.ps1` — do not use as the implementation owner; separately correct/update it only if the new firewall will be deallocated, because its current Premium and legacy-resource-group assumptions do not match this Basic deployment.

**Verification**

1. Live learned-route output supplies an approved, non-overlapping on-premises prefix list.
2. Bicep build/lint, subscription validation, and `what-if` pass with no unintended replacement or deletion.
3. Effective routes on all protected subnets show each remote private prefix with next hop `VirtualAppliance` and the deployed firewall private IP.
4. Effective routes on `GatewaySubnet` show hub/spoke Azure prefixes through the firewall while BGP propagation remains enabled and no default UDR exists.
5. Effective routes on `AzureFirewallSubnet` retain BGP on-premises routes and direct Internet access; no routing loop exists.
6. Positive tests for ICMP/TCP among hub, all spokes, and on-premises pass and appear in firewall logs; an unapproved public destination remains denied unless an explicit egress rule is added.
7. Rollback test or documented procedure can restore prior route-table associations without deleting the firewall.

**Decisions and boundaries**

- The target is a new Basic firewall in `za-east-southafricanorth`, not the existing Premium firewall in legacy resource group `ZA-East-vDC`.
- The firewall and policy names intentionally retain `ZA-East-vDC` per request.
- Private inter-site policy is intentionally broad (`Any` protocol/port among approved private prefixes) for this lab; Internet allow rules remain out of scope.
- On-premises prefixes will be discovered live and approved, not replaced by a broad `10.0.0.0/8` route.
- Inbound DNAT, forced tunneling, management NIC routing, and changes to on-premises FortiGate advertisements are excluded.
