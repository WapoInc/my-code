# Deployment Plan: MetroBus Gateway Transit Peering

Status: Validated

## Scope

Deploy the validated MetroBus Bicep template update to add bidirectional peering between `azure-vnet` and `avs-vnet`, allowing `avs-vnet` to use the VPN gateway in `azure-vnet` and learn on-premises routes.

## Target

- Subscription: `2ac21ef0-69db-49ec-a554-2cac36ec75f4`
- Resource group: `metro-bus-rg`
- Location: `southafricanorth`
- Template: `Bicep/MetroBus/main.bicep`
- Recipe type: Azure CLI with Bicep

## Changes

1. Create `azure-vnet/azure-to-avs` with virtual network access, forwarded traffic, and gateway transit enabled.
2. Create `avs-vnet/avs-to-azure` with virtual network access, forwarded traffic, and remote gateway use enabled.
3. Preserve the existing Azure VPN gateway, Route Server, firewall, VMs, and connections.
4. Verify both peerings are connected and inspect `avs-vm-nic` effective routes for on-premises prefixes using `VirtualNetworkGateway`.
5. Add `172.16.1.0/24` to `azure-local-gateway` so the simulated on-premises VPN has a return route to the AVS spoke.

## Validation

- [x] All validation checks pass
	- [x] Core validation: Azure CLI, authentication, Bicep build, ARM validation, and what-if
	- [x] Bicep lint and editor diagnostics
	- [x] Azure Policy assignments reviewed
	- [x] `deploy-MetroBus.sh` Bash syntax

## Boundaries

- Do not delete or replace existing resources.
- Do not create a VPN gateway in `avs-vnet`.
- Do not change VNet address spaces or subnet prefixes.
- Deploy only after explicit user approval.

## Validation Proof

Validated at `2026-09-16T07:42:38Z`.

- Shared Azure CLI validator: CLI and authentication passed; Bicep build passed; ARM resource-group validation passed.
- `az deployment group what-if`: 2 creates (`azure-to-avs`, `avs-to-azure`), 46 idempotent deploys, 14 ignored unmanaged resources, 0 deletes, and 0 replacements.
- `az bicep lint --file Bicep/MetroBus/main.bicep`: passed with no diagnostics.
- `bash -n Bicep/MetroBus/deploy-MetroBus.sh`: passed.
- `az policy assignment list`: no applicable assignments returned for the target scope.
- Static RBAC review: no role assignments are declared or required by this peering change.
