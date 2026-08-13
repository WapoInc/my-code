#!/usr/bin/env bash

set -euo pipefail

if (( $# < 1 || $# > 4 )); then
    echo "Usage: $0 <azure-vpn-gateway-public-ip> [fortigate-ssh-target] [wan-interface] [lan-interface]" >&2
    echo "Example: $0 203.0.113.10 admin@156.155.28.158 wan1 lan" >&2
  exit 2
fi

azure_gateway_ip="$1"
fortigate_ssh_target="${2:-admin@156.155.28.158}"
wan_interface="${3:-wan1}"
lan_interface="${4:-lan}"
tunnel_name='MiaCasa-Fort-1'

read -r -s -p 'FortiGate VPN pre-shared key: ' vpn_shared_key
echo
read -r -s -p 'Confirm FortiGate VPN pre-shared key: ' vpn_shared_key_confirmation
echo

cleanup() {
  unset vpn_shared_key vpn_shared_key_confirmation
}
trap cleanup EXIT

if [[ -z "$vpn_shared_key" || "$vpn_shared_key" != "$vpn_shared_key_confirmation" ]]; then
  echo 'VPN pre-shared keys are empty or do not match.' >&2
  exit 1
fi

ssh "$fortigate_ssh_target" <<EOF
config vpn ipsec phase1-interface
    edit "${tunnel_name}"
        set interface "${wan_interface}"
        set ike-version 2
        set peertype any
        set net-device disable
        set proposal aes256-sha256
        set dhgrp 14
        set keylife 28800
        set remote-gw ${azure_gateway_ip}
        set psksecret "${vpn_shared_key}"
        set dpd on-idle
        set dpd-retryinterval 20
        set dpd-retrycount 3
    next
end

config vpn ipsec phase2-interface
    edit "${tunnel_name}"
        set phase1name "${tunnel_name}"
        set proposal aes256-sha256
        set pfs disable
        set keylifeseconds 27000
        set src-subnet 0.0.0.0 0.0.0.0
        set dst-subnet 0.0.0.0 0.0.0.0
    next
end

config router static
    edit 0
        set dst 10.200.5.0 255.255.255.0
        set device "${tunnel_name}"
    next
    edit 0
        set dst 10.200.6.0 255.255.255.0
        set device "${tunnel_name}"
    next
end

config firewall address
    edit "MiaCasa-LAN"
        set subnet 192.168.2.0 255.255.255.0
    next
    edit "Azure-Spoke-1"
        set subnet 10.200.5.0 255.255.255.0
    next
    edit "Azure-Spoke-2"
        set subnet 10.200.6.0 255.255.255.0
    next
end

config firewall addrgrp
    edit "Azure-Spokes"
        set member "Azure-Spoke-1" "Azure-Spoke-2"
    next
end

config firewall policy
    edit 0
        set name "MiaCasa-to-Azure"
        set srcintf "${lan_interface}"
        set dstintf "${tunnel_name}"
        set action accept
        set srcaddr "MiaCasa-LAN"
        set dstaddr "Azure-Spokes"
        set schedule "always"
        set service "ALL"
        set nat disable
    next
    edit 0
        set name "Azure-to-MiaCasa"
        set srcintf "${tunnel_name}"
        set dstintf "${lan_interface}"
        set action accept
        set srcaddr "Azure-Spokes"
        set dstaddr "MiaCasa-LAN"
        set schedule "always"
        set service "ALL"
        set nat disable
    next
end
EOF