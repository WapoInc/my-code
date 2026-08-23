# Deployment Plan: ZA-East Azure Firewall and UDRs

Status: Approved for Implementation

## Scope

Implement the approved `ZA-East Firewall Policy and UDRs` design in the existing ZA-East Bicep deployment.

## Target

- Resource group: `za-east-southafricanorth`
- Location: `southafricanorth`
- Azure Firewall: `AzFW-ZA-East-vDC`, Basic SKU
- Firewall Policy: `AzFW-ZA-East-vDC-Policy-1`, Basic SKU
- Hub VNet: `za-east-southafricanorth-vnet`
- Spokes: `10.21.0.0/24`, `10.22.0.0/24`, `10.23.0.0/24`
- On-premises prefixes: supplied explicitly after live BGP route discovery and approval

## Implementation

1. Extend the ZA-East resource-group module with the firewall public IP, Basic policy, firewall, private network rule collection group, UDRs, and subnet associations.
2. Extend the subscription orchestrator to pass firewall, routing, diagnostics, and approved on-premises parameters and expose deployment outputs.
3. Extend the shell deployment workflow to collect the approved prefixes and options, compile the templates, run validation and what-if, and require confirmation before deployment.
4. Keep BGP propagation enabled on `GatewaySubnet`, disable it on spoke route tables, omit a default route from `GatewaySubnet`, and leave infrastructure subnets unassociated.
5. Deploy firewall resources before route associations by exposing an association toggle for staged rollout.

## Validation

- Run Bicep formatting/build and inspect diagnostics.
- Run `bash -n` and ShellCheck when available.
- Do not execute an Azure deployment without a separate explicit deployment request.

## Boundaries

- No forced tunneling, DNAT, TLS inspection, IDPS, or automatic changes to on-premises FortiGate advertisements.
- Internet traffic is routed to the firewall only when selected, and remains denied without explicit firewall allow rules.
- The deployment script must not contain credentials or hardcoded secrets.
