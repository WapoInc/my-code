# MEA Networking Lab1

To fix in Student lab ::
PSK of both Connections - change to a new 'known" PSK
Fix the on-prem cidr's in both LNG's - change to /22
fix AzFW rules to show correct onprem cidrs - change to /22
chck udr's cidr's - change to /22


AzFW commands:

AzureDiagnostics
| where TimeGenerated between (datetime(2026-09-13T07:40:40Z) .. datetime(2026-09-14T07:40:40Z))
| where Category == "AZFWNetworkRule"
| where SourceIP == "192.168.1.4"
| summarize events = count(), firstSeen = min(TimeGenerated), lastSeen = max(TimeGenerated), sourcePorts = dcount(SourcePort_d)
    by Protocol = Protocol_s, Action = Action_s, DestinationIp = DestinationIp_s, DestinationPort = DestinationPort_d,
       Rule = Rule_s, RuleCollectionGroup = RuleCollectionGroup_s, RuleCollection = RuleCollection_s, Policy = Policy_s
| order by events desc, DestinationIp asc
| take 20

