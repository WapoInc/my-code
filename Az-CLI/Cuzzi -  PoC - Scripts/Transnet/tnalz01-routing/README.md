# TNALZ01 route table remediation (Bicep)

```
networks.json                          shared network definitions (prod subscription IDs)
main.bicep                             remediation (replaces the PowerShell script)
modules/route-table-association*.bicep
test/test-environment.bicep            pre-remediation test environment, one subscription
test/modules/                          hub, spoke, peering
```

## Test in your own subscription

```bash
SUB=$(az account show --query id -o tsv)

# 1. Build the "before" environment (add deployFirewall=true for a real Azure Firewall)
az deployment sub create -n tnalz01-test-env -l southafricanorth \
  -f test/test-environment.bicep

# 2. Preview the remediation
az deployment sub what-if -n tnalz01-remediation -l southafricanorth \
  -f main.bicep -p testSubscriptionId=$SUB

# 3. Apply it
az deployment sub create -n tnalz01-remediation -l southafricanorth \
  -f main.bicep -p testSubscriptionId=$SUB

# 4. Clean up
for rg in $(az group list --tag purpose=tnalz01-route-remediation-test --query [].name -o tsv); do
  az group delete -n $rg --yes --no-wait
done
```

## Production

```bash
az deployment sub what-if -n tnalz01-remediation -l southafricanorth -f main.bicep
```
