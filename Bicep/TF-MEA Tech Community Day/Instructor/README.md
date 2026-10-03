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
export TF_VAR_admin_password='replace-with-a-complex-password'
export TF_VAR_vpn_shared_key='replace-with-a-shared-key'
cp terraform.tfvars.example terraform.tfvars
```

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

Destroy the lab when it is no longer needed:

```bash
terraform destroy
```

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
