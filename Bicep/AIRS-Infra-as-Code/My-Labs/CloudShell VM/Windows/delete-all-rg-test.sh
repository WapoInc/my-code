#!/usr/bin/env bash
set -euo pipefail

# Deletes every resource group whose name starts with a given prefix.
# Usage: ./delete-prefix-rgs.sh [prefix]   (prefix defaults to "Test")

PREFIX="${1:-Test}"

mapfile -t RESOURCE_GROUPS < <(
  az group list --query "[?starts_with(name, '$PREFIX')].name" --output tsv | sort
)

if (( ${#RESOURCE_GROUPS[@]} == 0 )); then
  echo "No resource groups found with prefix '$PREFIX'."
  exit 0
fi

echo "Resource groups with prefix '$PREFIX':"
printf '  %s\n' "${RESOURCE_GROUPS[@]}"
echo

read -r -p "Delete these ${#RESOURCE_GROUPS[@]} resource group(s)? [y/N]: " CONFIRMATION
if [[ ! "$CONFIRMATION" =~ ^[Yy]([Ee][Ss])?$ ]]; then
  echo 'Cancelled.'
  exit 0
fi

for RG in "${RESOURCE_GROUPS[@]}"; do
  echo "Deleting '$RG'..."
  az group delete --name "$RG" --yes --no-wait
done

echo
echo 'Deletion started for all matching resource groups. Current state:'
az group list \
  --query "[?starts_with(name, '$PREFIX')].{Name:name, State:properties.provisioningState}" \
  --output table
