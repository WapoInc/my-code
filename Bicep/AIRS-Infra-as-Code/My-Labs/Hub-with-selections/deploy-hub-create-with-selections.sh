#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="$SCRIPT_DIR/.deploy-hub-state"

LAST_RESOURCE_GROUP_NAME=""
if [[ -f "$STATE_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$STATE_FILE"
fi

# --- Selectable deployment regions ---
region_options=(
  "southafricanorth"
  "southafricawest"
  "westeurope"
  "northeurope"
  "uksouth"
  "ukwest"
)

# --- Selectable subscriptions (label | subscription id | tenant id) ---
subscription_labels=(
  "MngEnv461963 (5cba78fe tenant)"
  "MngEnvMCAP056429 (b91a5236 tenant)"
  "MngEnvMCAP158201 (2b8e427b tenant)"
)
subscription_ids=(
  "0cfd0d2a-2b38-4c93-ba14-cf79185bc683"
  "29df7078-c53c-4638-81c1-e4bc8566d423"
  "2ac21ef0-69db-49ec-a554-2cac36ec75f4"
)
subscription_tenants=(
  "5cba78fe-cc40-479a-9ee1-255423641bc9"
  "b91a5236-cd06-4bc7-889b-db71c19230ae"
  "2b8e427b-9e78-4589-9338-f870c84292ca"
)

# --- Selectable VM operating systems (label | bicep value) ---
os_labels=(
  "Ubuntu 22.04 LTS"
  "Windows Server 2022 Datacenter"
)
os_values=(
  "Ubuntu2204"
  "WindowsServer2022"
)

if ! command -v az >/dev/null 2>&1; then
  echo "Azure CLI is not installed or is not in PATH." >&2
  exit 1
fi

ensure_signed_in() {
  if ! az account show --subscription "$selected_subscription_id" >/dev/null 2>&1; then
    echo "Signing in to tenant $selected_tenant_id..."
    az login --tenant "$selected_tenant_id" >/dev/null
  fi
  az account set --subscription "$selected_subscription_id"
}

# ------------------------------------------------------------
# 1. Subscription
# ------------------------------------------------------------
echo
echo "Select the Azure subscription for this deployment:"
PS3="Enter selection (1-$((${#subscription_ids[@]} + 1))): "

selected_index=""
select selected_label in "${subscription_labels[@]}" "Cancel"; do
  if [[ "$selected_label" == "Cancel" ]]; then
    echo "Deployment cancelled."
    exit 0
  fi
  if [[ -n "$selected_label" && "$REPLY" =~ ^[0-9]+$ ]] && (( REPLY <= ${#subscription_ids[@]} )); then
    selected_index=$((REPLY - 1))
    break
  fi
  echo "Invalid selection. Choose a number from 1 to $((${#subscription_ids[@]} + 1))."
done

selected_subscription_id="${subscription_ids[$selected_index]}"
selected_tenant_id="${subscription_tenants[$selected_index]}"

# ------------------------------------------------------------
# 2. Deployment mode
# ------------------------------------------------------------
echo
echo "What do you want to do?"
PS3="Enter selection (1-3): "

DEPLOY_MODE=""
select mode_choice in "Create a new hub (VNet + subnets + VM)" "Add a VM to an existing hub (skip VNet/subnet setup)" "Cancel"; do
  case "$mode_choice" in
    "Create a new hub (VNet + subnets + VM)")
      DEPLOY_MODE="new"
      break
      ;;
    "Add a VM to an existing hub (skip VNet/subnet setup)")
      DEPLOY_MODE="add"
      break
      ;;
    "Cancel")
      echo "Deployment cancelled."
      exit 0
      ;;
    *)
      echo "Invalid selection. Choose a number from 1 to 3."
      ;;
  esac
done

LOCATION=""
RESOURCE_GROUP_NAME=""
VNET_CIDR=""
subnet_names=()
subnet_cidrs=()
SUBNET_COUNT=""
SUBNET_NAMES=""
SUBNET_CIDRS=""
VNET_NAME=""
SUBNET_NAME=""

if [[ "$DEPLOY_MODE" == "new" ]]; then
  TEMPLATE_FILE="$SCRIPT_DIR/hub-create-with-selections-rg.bicep"

  # ------------------------------------------------------------
  # 3. Region
  # ------------------------------------------------------------
  echo
  echo "Select the deployment region:"
  PS3="Enter selection (1-$((${#region_options[@]} + 1))): "

  select selected_region in "${region_options[@]}" "Cancel"; do
    if [[ "$selected_region" == "Cancel" ]]; then
      echo "Deployment cancelled."
      exit 0
    fi
    if [[ -n "$selected_region" && "$REPLY" =~ ^[0-9]+$ ]] && (( REPLY <= ${#region_options[@]} )); then
      LOCATION="$selected_region"
      break
    fi
    echo "Invalid selection. Choose a number from 1 to $((${#region_options[@]} + 1))."
  done

  # ------------------------------------------------------------
  # 4. Resource group name
  # ------------------------------------------------------------
  echo
  rg_default="${LAST_RESOURCE_GROUP_NAME:-${LOCATION}-lab-rg}"
  read -r -p "Resource group name [${rg_default}]: " RESOURCE_GROUP_NAME
  RESOURCE_GROUP_NAME="${RESOURCE_GROUP_NAME:-$rg_default}"

  # ------------------------------------------------------------
  # 5. VNet CIDR
  # ------------------------------------------------------------
  while true; do
    read -r -p "VNet CIDR [10.10.0.0/16]: " VNET_CIDR
    VNET_CIDR="${VNET_CIDR:-10.10.0.0/16}"
    if [[ "$VNET_CIDR" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]|[12][0-9]|3[0-2])$ ]]; then
      break
    fi
    echo "Not a valid CIDR (expected something like 10.10.0.0/16). Try again."
  done

  VNET_MASK="${VNET_CIDR##*/}"

  # ------------------------------------------------------------
  # 6. Subnets - count, then each one's own name + CIDR size
  # ------------------------------------------------------------
  # Every subnet is sized independently (no equal split): for each
  # one you give a name and a mask, and it's packed into the next
  # free, correctly-aligned space inside the VNet CIDR.
  while true; do
    read -r -p "How many subnets to define in ${VNET_CIDR}? [2]: " SUBNET_COUNT
    SUBNET_COUNT="${SUBNET_COUNT:-2}"
    if [[ "$SUBNET_COUNT" =~ ^[0-9]+$ ]] && (( SUBNET_COUNT >= 1 )); then
      break
    fi
    echo "Enter a whole number of 1 or more."
  done

  ip_to_int() {
    local IFS=.
    local -a o=($1)
    echo $(( (o[0] << 24) + (o[1] << 16) + (o[2] << 8) + o[3] ))
  }

  int_to_ip() {
    local ip=$1
    echo "$(( (ip >> 24) & 255 )).$(( (ip >> 16) & 255 )).$(( (ip >> 8) & 255 )).$(( ip & 255 ))"
  }

  vnet_base=$(ip_to_int "${VNET_CIDR%/*}")
  vnet_size=$(( 1 << (32 - VNET_MASK) ))
  vnet_end=$(( vnet_base + vnet_size ))
  cursor=$vnet_base

  name_regex='^[A-Za-z0-9][A-Za-z0-9._-]*[A-Za-z0-9_]$'

  for (( idx=1; idx<=SUBNET_COUNT; idx++ )); do
    echo
    echo "Subnet ${idx} of ${SUBNET_COUNT}:"

    while true; do
      read -r -p "  Name: " sn
      if ! [[ "$sn" =~ $name_regex ]]; then
        echo "  '$sn' is not a valid subnet name (word chars, '.', '-', '_' only; must start/end with a word char)."
        continue
      fi
      is_dup=0
      for existing in "${subnet_names[@]+"${subnet_names[@]}"}"; do
        [[ "$existing" == "$sn" ]] && is_dup=1 && break
      done
      if (( is_dup )); then
        echo "  '$sn' was already used for another subnet. Choose a unique name."
        continue
      fi
      break
    done

    while true; do
      read -r -p "  Subnet size (CIDR mask, e.g. 24): " mask
      mask="${mask#/}"

      if ! [[ "$mask" =~ ^[0-9]+$ ]]; then
        echo "  Enter the subnet mask as a number, e.g. 24."
        continue
      fi
      if (( mask <= VNET_MASK )); then
        echo "  Subnet mask /${mask} must be more specific than the VNet mask /${VNET_MASK}."
        continue
      fi
      if (( mask > 29 )); then
        echo "  Azure subnets can be at most /29."
        continue
      fi

      block_size=$(( 1 << (32 - mask) ))
      aligned_base=$(( ((cursor + block_size - 1) / block_size) * block_size ))
      block_end=$(( aligned_base + block_size ))

      if (( block_end > vnet_end )); then
        free=$(( vnet_end - cursor ))
        echo "  A /${mask} block (${block_size} addresses) doesn't fit; only ${free} address(es) left in ${VNET_CIDR}. Choose a smaller subnet (larger mask number)."
        continue
      fi

      subnet_cidr="$(int_to_ip "$aligned_base")/${mask}"
      cursor=$block_end
      break
    done

    subnet_names+=("$sn")
    subnet_cidrs+=("$subnet_cidr")
    echo "  -> ${sn}: ${subnet_cidr}"
  done

  SUBNET_NAMES="$(IFS=,; echo "${subnet_names[*]}")"
  SUBNET_CIDRS="$(IFS=,; echo "${subnet_cidrs[*]}")"
else
  TEMPLATE_FILE="$SCRIPT_DIR/hub-add-vm.bicep"

  # ------------------------------------------------------------
  # 3. Existing hub to attach to
  # ------------------------------------------------------------
  echo
  rg_default="$LAST_RESOURCE_GROUP_NAME"
  ensure_signed_in
  while true; do
    if [[ -n "$rg_default" ]]; then
      read -r -p "Existing resource group name [${rg_default}]: " RESOURCE_GROUP_NAME
      RESOURCE_GROUP_NAME="${RESOURCE_GROUP_NAME:-$rg_default}"
    else
      read -r -p "Existing resource group name: " RESOURCE_GROUP_NAME
    fi
    if az group show --name "$RESOURCE_GROUP_NAME" --subscription "$selected_subscription_id" >/dev/null 2>&1; then
      break
    fi
    echo "Resource group '$RESOURCE_GROUP_NAME' was not found in this subscription. Try again."
  done

  # ------------------------------------------------------------
  # Region
  # ------------------------------------------------------------
  echo
  echo "Select the deployment region for the new VM:"
  PS3="Enter selection (1-$((${#region_options[@]} + 1))): "

  select selected_region in "${region_options[@]}" "Cancel"; do
    if [[ "$selected_region" == "Cancel" ]]; then
      echo "Deployment cancelled."
      exit 0
    fi
    if [[ -n "$selected_region" && "$REPLY" =~ ^[0-9]+$ ]] && (( REPLY <= ${#region_options[@]} )); then
      LOCATION="$selected_region"
      break
    fi
    echo "Invalid selection. Choose a number from 1 to $((${#region_options[@]} + 1))."
  done

  # Look up VNets in the resource group and offer them as a menu instead of
  # free-text entry, so the VNet and subnet names can't get mixed up.
  vnet_list_raw="$(az network vnet list --resource-group "$RESOURCE_GROUP_NAME" --subscription "$selected_subscription_id" --query "[].name" -o tsv 2>/dev/null || true)"

  if [[ -n "$vnet_list_raw" ]]; then
    vnet_choices=()
    while IFS= read -r line; do
      [[ -n "$line" ]] && vnet_choices+=("$line")
    done <<< "$vnet_list_raw"
    echo
    echo "Select the VNet to attach the VM to:"
    PS3="Enter selection (1-$((${#vnet_choices[@]} + 1))): "
    select vc in "${vnet_choices[@]}" "Cancel"; do
      if [[ "$vc" == "Cancel" ]]; then
        echo "Deployment cancelled."
        exit 0
      fi
      if [[ -n "$vc" ]]; then
        VNET_NAME="$vc"
        break
      fi
      echo "Invalid selection. Choose a number from 1 to $((${#vnet_choices[@]} + 1))."
    done
  else
    echo "Could not list VNets in resource group '$RESOURCE_GROUP_NAME' (check the resource group name)."
    while true; do
      read -r -p "Existing VNet name: " VNET_NAME
      if az network vnet show --resource-group "$RESOURCE_GROUP_NAME" --name "$VNET_NAME" --subscription "$selected_subscription_id" >/dev/null 2>&1; then
        break
      fi
      echo "VNet '$VNET_NAME' was not found in resource group '$RESOURCE_GROUP_NAME'. Try again."
    done
  fi

  # Look up the chosen VNet's actual subnets and offer them as a menu too.
  subnet_list_raw="$(az network vnet subnet list --resource-group "$RESOURCE_GROUP_NAME" --vnet-name "$VNET_NAME" --subscription "$selected_subscription_id" --query "[].name" -o tsv 2>/dev/null || true)"

  if [[ -n "$subnet_list_raw" ]]; then
    subnet_choices=()
    while IFS= read -r line; do
      [[ -n "$line" ]] && subnet_choices+=("$line")
    done <<< "$subnet_list_raw"
    echo
    echo "Select the subnet to place the VM NIC in:"
    PS3="Enter selection (1-$((${#subnet_choices[@]} + 1))): "
    select sc in "${subnet_choices[@]}" "Cancel"; do
      if [[ "$sc" == "Cancel" ]]; then
        echo "Deployment cancelled."
        exit 0
      fi
      if [[ -n "$sc" ]]; then
        SUBNET_NAME="$sc"
        break
      fi
      echo "Invalid selection. Choose a number from 1 to $((${#subnet_choices[@]} + 1))."
    done
  else
    echo "Could not list subnets for VNet '$VNET_NAME' in resource group '$RESOURCE_GROUP_NAME'."
    while true; do
      read -r -p "Existing subnet name: " SUBNET_NAME
      if az network vnet subnet show --resource-group "$RESOURCE_GROUP_NAME" --vnet-name "$VNET_NAME" --name "$SUBNET_NAME" --subscription "$selected_subscription_id" >/dev/null 2>&1; then
        break
      fi
      echo "Subnet '$SUBNET_NAME' was not found in VNet '$VNET_NAME'. Try again."
    done
  fi
fi

# ------------------------------------------------------------
# 7. VM operating system
# ------------------------------------------------------------
echo
echo "Select the VM operating system:"
PS3="Enter selection (1-$((${#os_values[@]} + 1))): "

VM_OS=""
select selected_os in "${os_labels[@]}" "Cancel"; do
  if [[ "$selected_os" == "Cancel" ]]; then
    echo "Deployment cancelled."
    exit 0
  fi
  if [[ -n "$selected_os" && "$REPLY" =~ ^[0-9]+$ ]] && (( REPLY <= ${#os_values[@]} )); then
    VM_OS="${os_values[$((REPLY - 1))]}"
    break
  fi
  echo "Invalid selection. Choose a number from 1 to $((${#os_values[@]} + 1))."
done

# ------------------------------------------------------------
# 8. VM name
# ------------------------------------------------------------
if [[ "$DEPLOY_MODE" == "new" ]]; then
  vm_name_default="${LOCATION}-lab-vm"
else
  vm_name_default="${RESOURCE_GROUP_NAME}-vm2"
fi
read -r -p "VM name [${vm_name_default}]: " VM_NAME
VM_NAME="${VM_NAME:-$vm_name_default}"

# ------------------------------------------------------------
# 9. VM admin username
# ------------------------------------------------------------
ADMIN_USERNAME=""
while true; do
  read -r -p "VM admin username [labadmin]: " ADMIN_USERNAME
  ADMIN_USERNAME="${ADMIN_USERNAME:-labadmin}"
  # Block usernames Azure reserves.
  admin_username_lower="$(printf '%s' "$ADMIN_USERNAME" | tr '[:upper:]' '[:lower:]')"
  case "$admin_username_lower" in
    admin|administrator|root|user|guest|test|1|123)
      echo "'$ADMIN_USERNAME' is a reserved/disallowed username. Choose another."
      ;;
    *)
      break
      ;;
  esac
done

# ------------------------------------------------------------
# 10. VM admin password (hidden input, entered twice)
# ------------------------------------------------------------
ADMIN_PASSWORD=""
while true; do
  read -r -s -p "VM admin password: " ADMIN_PASSWORD
  echo
  read -r -s -p "Confirm password: " ADMIN_PASSWORD_CONFIRM
  echo
  if [[ "$ADMIN_PASSWORD" != "$ADMIN_PASSWORD_CONFIRM" ]]; then
    echo "Passwords do not match. Try again."
    continue
  fi
  # Azure requires 12-123 chars and 3 of 4 categories; do a light length check here.
  if (( ${#ADMIN_PASSWORD} < 12 )); then
    echo "Password must be at least 12 characters. Try again."
    continue
  fi
  break
done

# ------------------------------------------------------------
# 11. Public IP toggle
# ------------------------------------------------------------
read -r -p "Assign a public IP to the VM? (true/false) [false]: " ASSIGN_PUBLIC_IP
ASSIGN_PUBLIC_IP="${ASSIGN_PUBLIC_IP:-false}"

# ------------------------------------------------------------
# Summary + confirm
# ------------------------------------------------------------
echo
echo "Deployment target:"
echo "  Subscription:   ${subscription_labels[$selected_index]}"
echo "  ID:             $selected_subscription_id"
echo "  Tenant:         $selected_tenant_id"
if [[ "$DEPLOY_MODE" == "new" ]]; then
  echo "  Mode:           Create new hub"
  echo "  Location:       $LOCATION"
  echo "  Resource grp:   $RESOURCE_GROUP_NAME"
  echo "  VNet CIDR:      $VNET_CIDR"
  echo "  Subnets:"
  for i in "${!subnet_names[@]}"; do
    echo "                    ${subnet_names[$i]} -> ${subnet_cidrs[$i]}"
  done
else
  echo "  Mode:           Add VM to existing hub"
  echo "  Location:       $LOCATION"
  echo "  Resource grp:   $RESOURCE_GROUP_NAME (existing)"
  echo "  VNet:           $VNET_NAME (existing)"
  echo "  Subnet:         $SUBNET_NAME (existing)"
fi
echo "  VM OS:          $VM_OS"
echo "  VM name:        $VM_NAME"
echo "  VM username:    $ADMIN_USERNAME"
echo "  Public IP:      $ASSIGN_PUBLIC_IP"
echo "  Template:       $TEMPLATE_FILE"
echo

read -r -p "Continue with this deployment? [y/N] " confirmation
if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
  echo "Deployment cancelled."
  exit 0
fi

ensure_signed_in

if [[ "$DEPLOY_MODE" == "new" ]]; then
  az deployment sub create \
    --name "lab-vm-$(date -u +%Y%m%d-%H%M%S)" \
    --location "$LOCATION" \
    --template-file "$TEMPLATE_FILE" \
    --parameters \
      resourceGroupName="$RESOURCE_GROUP_NAME" \
      location="$LOCATION" \
      vnetCidr="$VNET_CIDR" \
      subnetCount="$SUBNET_COUNT" \
      subnetNames="$SUBNET_NAMES" \
      subnetCidrs="$SUBNET_CIDRS" \
      vmOs="$VM_OS" \
      vmName="$VM_NAME" \
      adminUsername="$ADMIN_USERNAME" \
      adminPassword="$ADMIN_PASSWORD" \
      assignPublicIp="$ASSIGN_PUBLIC_IP" \
    --subscription "$selected_subscription_id"
else
  az deployment group create \
    --name "lab-vm-$(date -u +%Y%m%d-%H%M%S)" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --template-file "$TEMPLATE_FILE" \
    --parameters \
      location="$LOCATION" \
      vnetName="$VNET_NAME" \
      subnetName="$SUBNET_NAME" \
      vmOs="$VM_OS" \
      vmName="$VM_NAME" \
      adminUsername="$ADMIN_USERNAME" \
      adminPassword="$ADMIN_PASSWORD" \
      assignPublicIp="$ASSIGN_PUBLIC_IP" \
    --subscription "$selected_subscription_id"
fi

# Remember the resource group for next time (only reached if the deployment above succeeded).
echo "LAST_RESOURCE_GROUP_NAME='$RESOURCE_GROUP_NAME'" > "$STATE_FILE"
