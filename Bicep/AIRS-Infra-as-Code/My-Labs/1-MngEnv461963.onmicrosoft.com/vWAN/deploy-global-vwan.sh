#!/usr/bin/env bash

set -euo pipefail

subscription_id='0cfd0d2a-2b38-4c93-ba14-cf79185bc683'
deployment_name="deploy-global-vwan-$(date -u +%Y%m%d-%H%M%S)-$$"
location='southafricanorth'
default_resource_group_name='Global-vWAN'
default_resource_group_name='Global-vWAN-PoC'
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
template_file="${script_dir}/Global-vWAN-rg.bicep"
fortigate_script_file="${script_dir}/update-fortigate-vpn-tunnels.sh"

read -r -p "Resource group name [${default_resource_group_name}]: " resource_group_name
resource_group_name="${resource_group_name:-$default_resource_group_name}"

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

echo
echo "Resource group:  $resource_group_name"
echo "Deployment name: $deployment_name"
echo

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
      deploymentName="$deployment_name" \
      resourceGroupName="$resource_group_name" \
      spokeVmAdminPassword="$vm_password" \
      fortiGateVpnSharedKey="$vpn_shared_key"
}

check_resource_group_state() {
  local provisioning_state

  provisioning_state="$(az group show \
    --subscription "$subscription_id" \
    --name "$resource_group_name" \
    --query properties.provisioningState \
    --output tsv 2>/dev/null || true)"

  if [[ "$provisioning_state" == 'Deleting' ]]; then
    echo "Resource group '$resource_group_name' is still being deleted by Azure." >&2
    echo 'Wait for deletion to finish, then run this script again.' >&2
    exit 1
  fi
}

generate_fortigate_script() {
  local public_ip_1 public_ip_2 extra_value public_ip_output

  public_ip_output="$(az deployment sub show \
    --subscription "$subscription_id" \
    --name "$deployment_name" \
    --query "join(' ', [properties.outputs.vpnGatewayPublicIpAddresses.value.Interface0, properties.outputs.vpnGatewayPublicIpAddresses.value.Interface1])" \
    --output tsv)"
  read -r public_ip_1 public_ip_2 extra_value <<< "$public_ip_output"

  if [[ -z "$public_ip_1" || -z "$public_ip_2" || -n "$extra_value" ]]; then
    echo 'Expected exactly two VPN gateway public IP addresses in the deployment output.' >&2
    exit 1
  fi

  cat > "$fortigate_script_file" <<FORTIGATE_SCRIPT
config vpn ipsec phase1-interface
    edit "MiaCasa-Fort-1"
        set remote-gw ${public_ip_1}
    next
    edit "MiaCasa-Fort-2"
        set remote-gw ${public_ip_2}
    next
end
FORTIGATE_SCRIPT

  echo "FortiGate VPN tunnel update script created: $fortigate_script_file"
  echo "MiaCasa-Fort-1 remote gateway: $public_ip_1"
  echo "MiaCasa-Fort-2 remote gateway: $public_ip_2"
}

case "$deployment_action" in
  validate)
    run_deployment validate
    ;;
  what-if)
    check_resource_group_state
    run_deployment what-if
    ;;
  deploy)
    check_resource_group_state
    run_deployment create
    generate_fortigate_script
    ;;
  full)
    check_resource_group_state
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
    generate_fortigate_script
    ;;
esac
