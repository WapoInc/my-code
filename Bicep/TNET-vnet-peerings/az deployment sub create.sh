az deployment sub create \
  --name tnet-vnet-peerings \
  --location southafricanorth \
  --subscription 29df7078-c53c-4638-81c1-e4bc8566d423 \
  --template-file TNET-SAP-vnet-peerings.bicep \
  --parameters TNET-SAP-vnet-peerings.bicepparam