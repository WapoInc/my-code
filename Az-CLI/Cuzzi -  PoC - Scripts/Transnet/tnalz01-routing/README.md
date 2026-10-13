# TNALZ01 route table remediation (Bicep)

```
networks.json                          shared network definitions
main.bicep                             remediation (replaces the PowerShell script)
deploy.sh                              preview, confirm, and deploy main.bicep
modules/route-table-association*.bicep
test/test-environment.bicep            pre-remediation test environment, one subscription
test/modules/                          hub, spoke, peering
```

## Test in your own subscription

```bash
# 1. Build the "before" environment with an Azure Firewall
az deployment sub create -n tnalz01-test-env -l southafricanorth \
  -f test/test-environment.bicep -p deployFirewall=true

# 2. Preview the remediation
az deployment sub what-if -n tnalz01-remediation -l southafricanorth \
  -f main.bicep

# 3. Apply it
az deployment sub create -n tnalz01-remediation -l southafricanorth \
  -f main.bicep

# 4. Clean up
for rg in $(az group list --tag purpose=tnalz01-route-remediation-test --query [].name -o tsv); do
  az group delete -n $rg --yes --no-wait
done
```

## Automated test flow

```bash
./deploy.sh
```

The script uses the active Azure CLI subscription for every network. It first
deploys the baseline test environment, then applies the remediation. Each stage
displays its what-if result and asks for confirmation. Override
`TEST_DEPLOYMENT_NAME`, `DEPLOYMENT_NAME`, or `LOCATION` with environment
variables. Additional Azure CLI arguments are forwarded to the remediation
deployment command. The script deploys an Azure Firewall by default; set
`DEPLOY_FIREWALL=false` to omit it.
