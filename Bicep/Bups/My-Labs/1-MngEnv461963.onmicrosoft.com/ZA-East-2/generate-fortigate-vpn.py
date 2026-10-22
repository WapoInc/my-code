import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


def azure(*args):
    result = subprocess.run(
        ["az", *args, "--subscription", sys.argv[1], "--output", "json"],
        check=True, capture_output=True, text=True,
    )
    return json.loads(result.stdout)


def main():
    subscription, resource_group, gateway_name = sys.argv[1:]
    gateway = azure(
        "network", "vnet-gateway", "show",
        "--resource-group", resource_group, "--name", gateway_name,
    )
    connections = azure("network", "vpn-connection", "list", "-g", resource_group)
    matches = [
        connection for connection in connections
        if connection.get("connectionType") == "IPsec"
        and connection["virtualNetworkGateway1"]["id"].lower() == gateway["id"].lower()
    ]
    if len(matches) != 1:
        raise ValueError("Expected exactly one IPsec connection for the VPN gateway.")
    connection = matches[0]
    if not gateway.get("enableBgp") or not connection.get("enableBgp"):
        raise ValueError("The FortiGate template requires BGP on the gateway and connection.")
    if connection.get("connectionProtocol") != "IKEv2" or connection.get("ipsecPolicies"):
        raise ValueError("The FortiGate template requires IKEv2 with default IPsec policies.")
    local_gateway = azure(
        "network", "local-gateway", "show",
        "--ids", connection["localNetworkGateway2"]["id"],
    )
    public_ip = azure(
        "network", "public-ip", "show",
        "--ids", gateway["ipConfigurations"][0]["publicIPAddress"]["id"],
    )
    key = azure(
        "network", "vpn-connection", "shared-key", "show",
        "-g", resource_group, "--connection-name", connection["name"],
    )["value"]
    if not isinstance(key, str) or not key or any(ord(char) < 32 for char in key):
        raise ValueError("The connection PSK is empty or contains unsupported control characters.")
    values = {
        "PSK": key.replace("\\", "\\\\").replace('"', '\\"'),
        "AZURE_PUBLIC_IP": public_ip["ipAddress"],
        "AZURE_BGP_IP": gateway["bgpSettings"]["bgpPeeringAddress"],
        "AZURE_ASN": gateway["bgpSettings"]["asn"],
        "FORTIGATE_BGP_IP": local_gateway["bgpSettings"]["bgpPeeringAddress"],
        "FORTIGATE_ASN": local_gateway["bgpSettings"]["asn"],
    }
    directory = Path(__file__).resolve().parent
    text = (directory / "fortigate-vpn.template").read_text(encoding="ascii")
    for name, value in values.items():
        text = text.replace("{{" + name + "}}", str(value))
    if "{{" in text:
        raise ValueError("Unresolved FortiGate template placeholder.")
    output = directory / "fortigate-run-to-conf-vpn-on-fortigate"
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w", encoding="ascii", dir=directory, delete=False,
        ) as stream:
            temporary = Path(stream.name)
            stream.write(text)
        os.replace(temporary, output)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
    print(f"FortiGate VPN configuration generated (mode 600): {output}")


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as error:
        print(f"Azure CLI failed: {error.stderr}", file=sys.stderr)
        sys.exit(error.returncode)
