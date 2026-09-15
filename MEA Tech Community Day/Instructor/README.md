# MEA Networking Lab1

## To Fix in Student Lab

- Change the PSK on both VPN Connections to a new known PSK.
- Fix the on-premises CIDRs in both Local Network Gateways (LNGs) and change them to `/22`.
- Update Azure Firewall rules to use the correct on-premises `/22` CIDRs.
- Check all UDR CIDRs and update them to `/22` where required.

## Azure Firewall Commands

### View Azure Firewall Network Rule Hits

```kusto
AzureDiagnostics
| where TimeGenerated between (datetime(2026-09-13T07:40:40Z) .. datetime(2026-09-14T07:40:40Z))
| where Category == "AZFWNetworkRule"
| where SourceIP == "192.168.1.4"
| summarize
    events = count(),
    firstSeen = min(TimeGenerated),
    lastSeen = max(TimeGenerated),
    sourcePorts = dcount(SourcePort_d)
    by
        Protocol = Protocol_s,
        Action = Action_s,
        DestinationIp = DestinationIp_s,
        DestinationPort = DestinationPort_d,
        Rule = Rule_s,
        RuleCollectionGroup = RuleCollectionGroup_s,
        RuleCollection = RuleCollection_s,
        Policy = Policy_s
| order by events desc, DestinationIp asc
| take 20
```
