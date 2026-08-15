#!/usr/bin/env bash

set -euo pipefail

if (( $# != 1 )); then
  echo "Usage: $0 <subscription-id-or-name>" >&2
  exit 2
fi

subscription="$1"
resource_groups=(
  "DefaultResourceGroup-CIN"
  "DefaultResourceGroup-CPT"
  "DefaultResourceGroup-CUS"
  "DefaultResourceGroup-EUS"
  "DefaultResourceGroup-JNB"
  "DefaultResourceGroup-SEC"
  "DefaultResourceGroup-SUK"
  "DefaultResourceGroup-WEU"
  "DefaultResourceGroup-WUS"
)

if ! command -v az >/dev/null 2>&1; then
  echo "Azure CLI is not installed or is not in PATH." >&2
  exit 1
fi

if ! az account show --subscription "$subscription" >/dev/null 2>&1; then
  echo "Subscription '$subscription' is unavailable. Run 'az login' and try again." >&2
  exit 1
fi

az account set --subscription "$subscription"
subscription_name="$(az account show --query name --output tsv)"
subscription_id="$(az account show --query id --output tsv)"

existing_groups=()
for resource_group in "${resource_groups[@]}"; do
  if [[ "$(az group exists --name "$resource_group" --output tsv)" == "true" ]]; then
    existing_groups+=("$resource_group")
  fi
done

if (( ${#existing_groups[@]} == 0 )); then
  echo "None of the specified resource groups exist in '$subscription_name' ($subscription_id)."
  exit 0
fi

echo "The following resource groups will be permanently deleted from:"
echo "  Subscription: $subscription_name"
echo "  ID:           $subscription_id"
printf '  - %s\n' "${existing_groups[@]}"
echo
read -r -p "Type DELETE to continue: " confirmation

if [[ "$confirmation" != "DELETE" ]]; then
  echo "Deletion cancelled."
  exit 0
fi

delete_data_collection_rules() {
  local resource_group="$1"
  local rule_id

  while IFS= read -r rule_id; do
    [[ -z "$rule_id" ]] && continue
    echo "Removing data collection rule and its associations: $rule_id"
    az monitor data-collection rule delete \
      --ids "$rule_id" \
      --delete-associations true \
      --yes
  done < <(az monitor data-collection rule list \
    --resource-group "$resource_group" \
    --subscription "$subscription_id" \
    --query '[].id' \
    --output tsv)
}

for resource_group in "${existing_groups[@]}"; do
  delete_data_collection_rules "$resource_group"
  echo "Deleting $resource_group..."
  az group delete \
    --name "$resource_group" \
    --subscription "$subscription_id" \
    --yes
done

echo "All requested resource group deletions completed."