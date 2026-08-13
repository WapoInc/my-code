#!/usr/bin/env bash

set -euo pipefail

subscription_id='0cfd0d2a-2b38-4c93-ba14-cf79185bc683'
deployment_name='deploy-global-vwan'
location='southafricanorth'
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
template_file="${script_dir}/Global-vWAN-rg.bicep"
deployment_action="${1:-what-if}"

if [[ "$deployment_action" != 'what-if' && "$deployment_action" != 'deploy' ]]; then
  echo "Usage: $0 [what-if|deploy]" >&2
  exit 2
fi

if ! command -v az >/dev/null 2>&1; then
  echo 'Azure CLI (az) is not installed or is not on PATH.' >&2
  exit 1
fi

read -r -s -p 'VM administrator password: ' vm_password
echo
read -r -s -p 'Confirm VM administrator password: ' vm_password_confirmation
echo

cleanup() {
  unset vm_password vm_password_confirmation
}
trap cleanup EXIT

if [[ "$vm_password" != "$vm_password_confirmation" ]]; then
  echo 'Passwords do not match.' >&2
  exit 1
fi

if (( ${#vm_password} < 6 || ${#vm_password} > 72 )); then
  echo 'Password must be between 6 and 72 characters.' >&2
  exit 1
fi

if [[ "$vm_password" =~ [[:cntrl:]] ]]; then
  echo 'Password must not contain control characters.' >&2
  exit 1
fi

complexity_classes=0
[[ "$vm_password" =~ [[:upper:]] ]] && ((complexity_classes += 1))
[[ "$vm_password" =~ [[:lower:]] ]] && ((complexity_classes += 1))
[[ "$vm_password" =~ [[:digit:]] ]] && ((complexity_classes += 1))
[[ "$vm_password" =~ [^[:alnum:]] ]] && ((complexity_classes += 1))

if (( complexity_classes < 3 )); then
  echo 'Password must contain at least three of: uppercase, lowercase, number, special character.' >&2
  exit 1
fi

az_action='what-if'
if [[ "$deployment_action" == 'deploy' ]]; then
  az_action='create'
fi

az deployment sub "$az_action" \
  --subscription "$subscription_id" \
  --name "$deployment_name" \
  --location "$location" \
  --template-file "$template_file" \
  --parameters spokeVmAdminPassword="$vm_password"