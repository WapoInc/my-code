#!/usr/bin/env bash
set -euo pipefail

# Override these defaults before running, for example:
# RG="My-RG" ER_Circuit_Name="My-Circuit" ./@-Show\ ExpressRoute\ Metro\ MSEE\ POPs.azcli.sh
RG="${RG:-ER-LTSA-RG}"
ER_Circuit_Name="${ER_Circuit_Name:-ER-Metro}"

METRO_LOCATION="Johannesburg Metro"
POP_1_NAME="Johannesburg"
POP_1_FACILITY="Teraco JT1"
POP_2_NAME="Johannesburg2"
POP_2_FACILITY="Africa Data Centres JHB1 ADC"

command -v az >/dev/null 2>&1 || {
  echo "Error: Azure CLI (az) is not installed or is not in PATH." >&2
  exit 1
}

az account show --output none 2>/dev/null || {
  echo "Error: Sign in first with 'az login'." >&2
  exit 1
}

IFS='|' read -r CIRCUIT_NAME PEERING_LOCATION PROVIDER PROVISIONING_STATE PROVIDER_STATE < <(
  az network express-route show \
    --resource-group "$RG" \
    --name "$ER_Circuit_Name" \
    --query "join('|',[name,serviceProviderProperties.peeringLocation,serviceProviderProperties.serviceProviderName,provisioningState,serviceProviderProvisioningState])" \
    --output tsv
)

if [[ "$PEERING_LOCATION" != "$METRO_LOCATION" ]]; then
  echo "Error: Circuit '$CIRCUIT_NAME' uses '$PEERING_LOCATION', not '$METRO_LOCATION'." >&2
  echo "The POP mapping in this script applies only to Johannesburg Metro." >&2
  exit 1
fi

IFS='|' read -r PEERING_STATE PRIMARY_PREFIX SECONDARY_PREFIX < <(
  az network express-route peering show \
    --resource-group "$RG" \
    --circuit-name "$ER_Circuit_Name" \
    --name AzurePrivatePeering \
    --query "join('|',[state,primaryPeerAddressPrefix,secondaryPeerAddressPrefix])" \
    --output tsv
)

printf '\nExpressRoute Metro circuit\n'
printf '%-22s %s\n' "Circuit:" "$CIRCUIT_NAME"
printf '%-22s %s\n' "Resource group:" "$RG"
printf '%-22s %s\n' "Metro location:" "$PEERING_LOCATION"
printf '%-22s %s\n' "Provider:" "$PROVIDER"
printf '%-22s %s\n' "Circuit state:" "$PROVISIONING_STATE"
printf '%-22s %s\n' "Provider state:" "$PROVIDER_STATE"

printf '\nMicrosoft MSEE meet-me POPs\n'
printf '%-5s %-18s %s\n' "POP" "Peering location" "Facility"
printf '%-5s %-18s %s\n' "1" "$POP_1_NAME" "$POP_1_FACILITY"
printf '%-5s %-18s %s\n' "2" "$POP_2_NAME" "$POP_2_FACILITY"

printf '\nAzure private peering\n'
printf '%-22s %s\n' "State:" "$PEERING_STATE"
printf '%-22s %s\n' "Primary BGP prefix:" "$PRIMARY_PREFIX"
printf '%-22s %s\n' "Secondary BGP prefix:" "$SECONDARY_PREFIX"

printf '\nNote: Azure CLI does not map the primary/secondary path labels to a named facility.\n'