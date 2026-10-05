# MEA Networking Lab 1

## Deploy with Terraform

### Prerequisites

- Terraform 1.5 or later
- Azure CLI authenticated with `az login`
- An Azure subscription with permission to create the lab resources

### Configure

```bash
az account set --subscription "ME-MngEnvMCAP158201-viresent-1"
export ARM_SUBSCRIPTION_ID="$(az account show --query id --output tsv)"
export TF_VAR_admin_password="Aa1$(openssl rand -hex 16)"
cp terraform.tfvars.example terraform.tfvars
```

On PowerShell, run `./deploy.ps1` to enter a resource group name or press
Enter to use `MEA-Instructor`. The lab IPsec PSK is set to `S2SPSK123!` and
is not prompted for.

The VM administrator password must be at least 12 characters and contain at
least three of these character classes: lowercase, uppercase, digits, and
special characters other than underscore.

Do not commit `terraform.tfvars` if it contains secrets. Sensitive Terraform
variables are redacted from CLI output, but their values remain in Terraform
state. Store production state in a secured remote backend.

### Validate and deploy

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

VPN gateways can take 30 minutes or longer to provision. Inspect deployment
values after the apply completes:

```bash
terraform output
```

The VMs use Azure-managed boot diagnostics storage. This is compatible with
subscriptions that prohibit storage-account shared-key authentication.

If an earlier deployment failed while creating the old custom boot diagnostics
storage account, remove that resource from Terraform state and delete the
orphaned account before running `terraform plan` again:

```bash
terraform state rm azurerm_storage_account.boot_diagnostics
az storage account delete \
  --name "<boot-diagnostics-storage-account>" \
  --resource-group "<resource-group-name>" \
  --yes
```

Destroy the lab when it is no longer needed:

```bash
terraform destroy
```

## Monitoring Deployment Progress

Terraform doesn't create entries in the resource group's **Deployments** blade. [deployments.tf](deployments.tf) adds empty ARM deployments (`tf-01-foundation` ... `tf-06-vpn-connections`) that are created as each stage finishes, so you can follow progress under Resource group > Settings > Deployments. For per-resource detail, use the resource group's **Activity log**.

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
