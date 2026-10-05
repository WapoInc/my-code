$ErrorActionPreference = "Stop"

$defaultResourceGroup = "MEA-Instructor"
$resourceGroup = Read-Host "Resource group name [$defaultResourceGroup]"
if ([string]::IsNullOrWhiteSpace($resourceGroup)) {
  $resourceGroup = $defaultResourceGroup
}

$env:TF_VAR_resource_group_name = $resourceGroup

function Invoke-Terraform {
  param(
    [Parameter(Mandatory)]
    [string[]] $Arguments
  )

  & terraform "-chdir=$PSScriptRoot" @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "terraform $($Arguments -join ' ') failed with exit code $LASTEXITCODE."
  }
}

if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
  throw "Terraform is not installed or is not available on PATH."
}

Invoke-Terraform -Arguments @("init")
Invoke-Terraform -Arguments @("validate")
Invoke-Terraform -Arguments @("plan", "-out=tfplan")
Invoke-Terraform -Arguments @("apply", "tfplan")
