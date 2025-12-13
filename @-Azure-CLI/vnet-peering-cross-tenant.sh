
# Tenant / subscription / resource group / VNet names
# --- Tenant A (e.g., Contoso)
TENANT_A_ID="5cba78fe-cc40-479a-9ee1-255423641bc9"
SUB_A_ID="0cfd0d2a-2b38-4c93-ba14-cf79185bc683"
RG_A="AVS-ZA-North"
VNET_A="JumpBox-vnet"
PEER_TO_B_NAME="peer-to-new-AIRS"

# --- Tenant B (e.g., Fabrikam)
TENANT_B_ID="b91a5236-cd06-4bc7-889b-db71c19230ae"
SUB_B_ID="29df7078-c53c-4638-81c1-e4bc8566d423"
RG_B="DC-PoC"
VNET_B="DC-VM1-vnet"
PEER_TO_A_NAME="peer-to-old-AIRS"

# Optional flags (set to true/false as needed)
ALLOW_VNET_ACCESS=true
ALLOW_FORWARDED_TRAFFIC=true
ALLOW_GATEWAY_TRANSIT=false  # set true only if using GW transit
USE_REMOTE_GATEWAY=false     # set true on the *other* side when consuming transit
