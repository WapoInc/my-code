#!/usr/bin/env bash
set -Eeuo pipefail

SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-0cfd0d2a-2b38-4c93-ba14-cf79185bc683}"
RESOURCE_GROUP="${RESOURCE_GROUP:-VNET-Peerings}"
LOCATION="${LOCATION:-southafricanorth}"
TEMPLATE_FILE="${TEMPLATE_FILE:-$(cd "$(dirname "$0")" && pwd)/main.bicep}"
DEPLOYMENT_NAME="${DEPLOYMENT_NAME:-vnet-peering-spoke-5-6-$(date +%Y%m%d%H%M%S)}"
KEY_VAULT_NAME="${KEY_VAULT_NAME:-vnet-peer-kv-0cfd0d2a}"
VPN_PSK_SECRET_NAME="${VPN_PSK_SECRET_NAME:-vpn-shared-key}"
VM_PASSWORD_SECRET_NAME="${VM_PASSWORD_SECRET_NAME:-vm-admin-password}"

fail() {
	printf 'ERROR: %s\n' "$*" >&2
	exit 1
}

IFS= read -r -p "Resource group [$RESOURCE_GROUP]: " RESOURCE_GROUP_INPUT \
	|| fail "Unable to read resource group."
RESOURCE_GROUP="${RESOURCE_GROUP_INPUT:-$RESOURCE_GROUP}"
unset RESOURCE_GROUP_INPUT
KEY_VAULT_RESOURCE_GROUP="${KEY_VAULT_RESOURCE_GROUP:-$RESOURCE_GROUP}"

command -v az >/dev/null 2>&1 || fail "Azure CLI is not installed."
command -v python3 >/dev/null 2>&1 || fail "Python 3 is required to generate the FortiGate CLI file."
[[ -f "$TEMPLATE_FILE" ]] || fail "Template '$TEMPLATE_FILE' not found."

ARM_TEMPLATE_FILE="$(mktemp -t vnet-peerings-template)"
trap 'rm -f -- "$ARM_TEMPLATE_FILE"' EXIT

# Compile once before changing Azure resources or prompting for credentials.
printf 'Compiling Bicep template...\n'
az bicep build \
	--file "$TEMPLATE_FILE" \
	--outfile "$ARM_TEMPLATE_FILE" \
	--no-restore \
	|| fail "Bicep compilation failed. Run 'az bicep upgrade' and retry."

az account show --subscription "$SUBSCRIPTION_ID" --output none 2>/dev/null \
	|| fail "Sign in with 'az login' and ensure access to subscription '$SUBSCRIPTION_ID'."
az group create \
	--subscription "$SUBSCRIPTION_ID" \
	--name "$RESOURCE_GROUP" \
	--location "$LOCATION" \
	--output none

if [[ "$KEY_VAULT_RESOURCE_GROUP" != "$RESOURCE_GROUP" ]]; then
	az group create \
		--subscription "$SUBSCRIPTION_ID" \
		--name "$KEY_VAULT_RESOURCE_GROUP" \
		--location "$LOCATION" \
		--output none
fi

VAULT_EXISTS="$(az keyvault list \
	--subscription "$SUBSCRIPTION_ID" \
	--resource-group "$KEY_VAULT_RESOURCE_GROUP" \
	--query "length([?name=='$KEY_VAULT_NAME'])" --output tsv)"
if [[ "$VAULT_EXISTS" == "0" ]]; then
	az keyvault create \
		--subscription "$SUBSCRIPTION_ID" \
		--resource-group "$KEY_VAULT_RESOURCE_GROUP" \
		--name "$KEY_VAULT_NAME" \
		--location "$LOCATION" \
		--sku standard \
		--enable-rbac-authorization true \
		--enabled-for-template-deployment true \
		--output none
else
	az keyvault update \
		--subscription "$SUBSCRIPTION_ID" \
		--resource-group "$KEY_VAULT_RESOURCE_GROUP" \
		--name "$KEY_VAULT_NAME" \
		--enabled-for-template-deployment true \
		--output none
fi

KEY_VAULT_ID="$(az keyvault show \
	--subscription "$SUBSCRIPTION_ID" \
	--resource-group "$KEY_VAULT_RESOURCE_GROUP" \
	--name "$KEY_VAULT_NAME" \
	--query id --output tsv)" \
	|| fail "Unable to resolve Key Vault '$KEY_VAULT_NAME' in '$KEY_VAULT_RESOURCE_GROUP'."

OPERATOR_ID="$(az ad signed-in-user show --query id --output tsv)" \
	|| fail "This interactive deployment requires an Azure user login with permission to assign Key Vault roles."
az role assignment create \
	--subscription "$SUBSCRIPTION_ID" \
	--assignee-object-id "$OPERATOR_ID" \
	--assignee-principal-type User \
	--role 'Key Vault Secrets Officer' \
	--scope "$KEY_VAULT_ID" \
	--output none

# New RBAC assignments can take time to reach the Key Vault data plane.
for ((attempt = 1; attempt <= 18; attempt++)); do
	if SECRET_NAMES="$(az keyvault secret list \
		--subscription "$SUBSCRIPTION_ID" \
		--vault-name "$KEY_VAULT_NAME" \
		--query '[].name' --output tsv 2>&1)"; then
		break
	else
		rc=$?
		if [[ "$attempt" -eq 18 || "$SECRET_NAMES" != *ForbiddenByRbac* ]]; then
			printf '%s\n' "$SECRET_NAMES" >&2
			exit "$rc"
		fi
		printf 'Waiting for Key Vault RBAC permissions (%d/18)...\n' "$attempt" >&2
		sleep 10
	fi
done

set +x
if ! grep -Fxq "$VPN_PSK_SECRET_NAME" <<<"$SECRET_NAMES"; then
	IFS= read -r -s -p 'FortiGate VPN pre-shared key (must match the FortiGate): ' VPN_SHARED_KEY \
		|| fail "Unable to read VPN pre-shared key."
	printf '\n'
	[[ -n "$VPN_SHARED_KEY" ]] || fail "VPN pre-shared key must not be empty."
	printf '%s' "$VPN_SHARED_KEY" | az keyvault secret set \
		--subscription "$SUBSCRIPTION_ID" \
		--vault-name "$KEY_VAULT_NAME" \
		--name "$VPN_PSK_SECRET_NAME" \
		--file /dev/stdin \
		--encoding utf-8 \
		--output none
	unset VPN_SHARED_KEY
fi

IFS= read -r -s -p 'VM administrator password: ' VM_ADMIN_PASSWORD \
	|| fail "Unable to read VM administrator password."
printf '\n'
IFS= read -r -s -p 'Confirm VM administrator password: ' VM_ADMIN_PASSWORD_CONFIRM \
	|| fail "Unable to read password confirmation."
printf '\n'
[[ "$VM_ADMIN_PASSWORD" == "$VM_ADMIN_PASSWORD_CONFIRM" ]] || fail "Passwords do not match."
[[ ${#VM_ADMIN_PASSWORD} -ge 12 && ${#VM_ADMIN_PASSWORD} -le 72 ]] \
	|| fail "VM password must contain 12 to 72 characters."

printf '%s' "$VM_ADMIN_PASSWORD" | az keyvault secret set \
	--subscription "$SUBSCRIPTION_ID" \
	--vault-name "$KEY_VAULT_NAME" \
	--name "$VM_PASSWORD_SECRET_NAME" \
	--file /dev/stdin \
	--encoding utf-8 \
	--output none
unset VM_ADMIN_PASSWORD VM_ADMIN_PASSWORD_CONFIRM

VPN_PARAMETERS="$(printf '{"vpnSharedKey":{"reference":{"keyVault":{"id":"%s"},"secretName":"%s"}},"vmAdminPassword":{"reference":{"keyVault":{"id":"%s"},"secretName":"%s"}}}' \
	"$KEY_VAULT_ID" "$VPN_PSK_SECRET_NAME" "$KEY_VAULT_ID" "$VM_PASSWORD_SECRET_NAME")"

printf 'Using Key Vault secret %s/%s for vpnSharedKey.\n' "$KEY_VAULT_NAME" "$VPN_PSK_SECRET_NAME"
printf 'Using Key Vault secret %s/%s for vmAdminPassword.\n' "$KEY_VAULT_NAME" "$VM_PASSWORD_SECRET_NAME"

az deployment group what-if \
	--subscription "$SUBSCRIPTION_ID" \
	--resource-group "$RESOURCE_GROUP" \
	--name "$DEPLOYMENT_NAME" \
	--template-file "$ARM_TEMPLATE_FILE" \
	--parameters "$VPN_PARAMETERS" location="$LOCATION"

az deployment group create \
	--subscription "$SUBSCRIPTION_ID" \
	--resource-group "$RESOURCE_GROUP" \
	--name "$DEPLOYMENT_NAME" \
	--template-file "$ARM_TEMPLATE_FILE" \
	--parameters "$VPN_PARAMETERS" location="$LOCATION" \
	--output table

FORTIGATE_CONFIGURATION="$(az deployment group show \
	--subscription "$SUBSCRIPTION_ID" \
	--resource-group "$RESOURCE_GROUP" \
	--name "$DEPLOYMENT_NAME" \
	--query properties.outputs.fortigateConfiguration.value \
	--output json)"
FORTIGATE_FILE="$(dirname "$TEMPLATE_FILE")/fortigate-script-paste-into-cli"
python3 - "$FORTIGATE_FILE" "$FORTIGATE_CONFIGURATION" <<'PY'
import ipaddress
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
config = json.loads(sys.argv[2])
gateway = str(ipaddress.IPv4Address(config["gatewayPublicIp"]))
networks = {
    "AZH-OnPrem": ipaddress.IPv4Network(config["onPremPrefix"]),
    "AZH-Hub": ipaddress.IPv4Network(config["hubPrefix"]),
    "AZH-Spoke5": ipaddress.IPv4Network(config["spoke5Prefix"]),
    "AZH-Spoke6": ipaddress.IPv4Network(config["spoke6Prefix"]),
}
lines = [
    "# Replace ENTER_CURRENT_VPN_PSK with the deployed VPN PSK before pasting.",
    "# Apply in the VDOM containing wan1 and b.",
    "# This updates Azure-Hub. Route/policy edit 0 creates NEW entries.",
    "# Skip existing equivalent routes/policies to avoid duplicates.",
    "# Place allow policies above matching deny policies.",
    "config vpn ipsec phase1-interface",
    '    edit "Azure-Hub"',
    '        set interface "wan1"',
    "        set type static",
    "        set ike-version 2",
    "        set peertype any",
    "        set authmethod psk",
    f"        set remote-gw {gateway}",
    "        set proposal aes256-sha256",
    "        set dhgrp 14",
    "        set keylife 28800",
    "        set nattraversal enable",
    "        set dpd on-idle",
    "        set dpd-retryinterval 10",
    "        set add-route disable",
    '        set psksecret "ENTER_CURRENT_VPN_PSK"',
    "    next",
    "end",
    "",
    "config vpn ipsec phase2-interface",
    '    edit "Azure-Hub-P2"',
    '        set phase1name "Azure-Hub"',
    "        set proposal aes256-sha256",
    "        set pfs disable",
    "        set keylife-type seconds",
    "        set keylifeseconds 27000",
    "        set src-subnet 0.0.0.0 0.0.0.0",
    "        set dst-subnet 0.0.0.0 0.0.0.0",
    "        set auto-negotiate enable",
    "    next",
    "end",
    "",
    "config firewall address",
]
for name, network in networks.items():
    lines += [
        f'    edit "{name}"',
        f"        set subnet {network.network_address} {network.netmask}",
        "    next",
    ]
lines += [
    "end",
    "",
    "config firewall addrgrp",
    '    edit "AZH-Networks"',
    '        set member "AZH-Hub" "AZH-Spoke5" "AZH-Spoke6"',
    "    next",
    "end",
    "",
    "config router static",
]
for name in ("AZH-Hub", "AZH-Spoke5", "AZH-Spoke6"):
    network = networks[name]
    lines += [
        "    edit 0",
        f"        set dst {network.network_address} {network.netmask}",
        '        set device "Azure-Hub"',
        "        set distance 10",
        f'        set comment "{name} via IPsec"',
        "    next",
    ]
lines += ["end", "", "config firewall policy"]
for name, source_interface, destination_interface, source, destination in (
    ("OnPrem-to-AzureHub", "b", "Azure-Hub", "AZH-OnPrem", "AZH-Networks"),
    ("AzureHub-to-OnPrem", "Azure-Hub", "b", "AZH-Networks", "AZH-OnPrem"),
):
    lines += [
        "    edit 0",
        f'        set name "{name}"',
        f'        set srcintf "{source_interface}"',
        f'        set dstintf "{destination_interface}"',
        f'        set srcaddr "{source}"',
        f'        set dstaddr "{destination}"',
        "        set action accept",
        '        set schedule "always"',
        '        set service "ALL"',
        "        set nat disable",
        "        set logtraffic all",
        "        set tcp-mss-sender 1350",
        "        set tcp-mss-receiver 1350",
        "    next",
    ]
lines += ["end", ""]
path.write_text("\n".join(lines), encoding="ascii")
PY
printf 'FortiGate CLI file generated: %s\n' "$FORTIGATE_FILE"
printf 'Replace ENTER_CURRENT_VPN_PSK before pasting; skip duplicate routes and policies.\n'

printf '\nDeployment %s complete.\n' "$DEPLOYMENT_NAME"
printf 'The hub VPN gateway and FortiGate site-to-site VPN connection are provisioned.\n'
printf 'Ubuntu VMs are provisioned in the hub and both spokes; see deployment output vmConnectionDetails for addresses.\n'
printf 'Verify the tunnel is connected and the FortiGate has return routes for the hub and spoke CIDRs.\n'
printf 'For a fresh environment, update the FortiGate remote gateway to deployment output hubVpnGatewayPublicIpAddress.\n'
