# MEA Networking Lab1

## To Fix in Student Lab

- Change the PSK on both VPN Connections to a new known PSK.
- Fix the on-premises CIDRs in both Local Network Gateways (LNGs) and change them to `/22`.
- Update Azure Firewall rules to use the correct on-premises `/22` CIDRs.
- Check all UDR CIDRs and update them to `/22` where required.

## Azure Firewall Commands

### View Azure Firewall Network Rule Hits

AZFWNetworkRule
| where SourceIp == "192.168.1.4"
| take 100
