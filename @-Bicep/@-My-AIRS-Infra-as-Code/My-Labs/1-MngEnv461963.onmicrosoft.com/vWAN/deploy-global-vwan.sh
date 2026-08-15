#!/usr/bin/env bash

set -euo pipefail

subscription_id='0cfd0d2a-2b38-4c93-ba14-cf79185bc683'
deployment_name='deploy-global-vwan'
location='southafricanorth'
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
template_file="${script_dir}/Global-vWAN-rg.bicep"

if (( $# == 0 )); then
  echo 'Choose an action:'
  echo '  1) Check which resources would be deployed (what-if)'
  echo '  2) Deploy the resources'
  read -r -p 'Selection [1/2]: ' deployment_choice

  case "$deployment_choice" in
    1)
      deployment_action='what-if'
      ;;
    2)
      deployment_action='deploy'
      ;;
    *)
      echo 'Invalid selection. Enter 1 or 2.' >&2
      exit 2
      ;;
  esac
else
  deployment_action="$1"
fi

if [[ "$deployment_action" != 'validate' && "$deployment_action" != 'what-if' && "$deployment_action" != 'deploy' && "$deployment_action" != 'full' ]]; then
  echo "Usage: $0 [validate|what-if|deploy|full]" >&2
  exit 2
fi

if ! command -v az >/dev/null 2>&1; then
  echo 'Azure CLI (az) is not installed or is not on PATH.' >&2
  exit 1
fi

vm_password='P@ssw0rd123!'
vpn_shared_key='S2SPSK123!'

cleanup() {
  unset vm_password vpn_shared_key
}
trap cleanup EXIT

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

run_deployment() {
  local action="$1"

  az deployment sub "$action" \
    --subscription "$subscription_id" \
    --name "$deployment_name" \
    --location "$location" \
    --template-file "$template_file" \
    --parameters \
      spokeVmAdminPassword="$vm_password" \
      fortiGateVpnSharedKey="$vpn_shared_key"
}

case "$deployment_action" in
  validate)
    run_deployment validate
    ;;
  what-if)
    run_deployment what-if
    ;;
  deploy)
    run_deployment create
    ;;
  full)
    echo 'Validating the complete Global vWAN deployment...'
    run_deployment validate

    echo 'Previewing the complete Global vWAN deployment...'
    run_deployment what-if

    read -r -p 'Deploy these changes? [y/N]: ' deploy_confirmation
    if [[ ! "$deploy_confirmation" =~ ^[Yy]$ ]]; then
      echo 'Deployment cancelled.'
      exit 0
    fi

    echo 'Deploying the Global vWAN, VPN gateway, VPN site, site link, and hub connection...'
    run_deployment create
    ;;
esac