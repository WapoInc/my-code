targetScope = 'resourceGroup'

param location string
param vnetName string
param subnetName string
param vmName string
param adminUsername string

@secure()
param adminPassword string

param vmSize string
param createPublicIp bool

var nicName = '${vmName}-nic'
var nsgName = '${vmName}-nsg'
var publicIpName = '${vmName}-pip'
var kernelVersion = '6.8.0-1042-azure'
var kernelSetupScript = '''
#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install --yes ca-certificates curl linux-base-sgx

kernel_dir=$(mktemp -d)
trap 'rm -rf "$kernel_dir"' EXIT

curl --fail --location --silent --show-error \
  --output "$kernel_dir/linux-modules.deb" \
  https://launchpadlibrarian.net/824739355/linux-modules-6.8.0-1042-azure_6.8.0-1042.48_amd64.deb
curl --fail --location --silent --show-error \
  --output "$kernel_dir/linux-image.deb" \
  https://launchpadlibrarian.net/824813614/linux-image-6.8.0-1042-azure_6.8.0-1042.48_amd64.deb

echo '3dd1cb1106dad829ee68e29a9678ca52dd16c4369da5641b434ff9888f09324c  '"$kernel_dir/linux-modules.deb" | sha256sum --check
echo '602d9d8ac84c7b90be115981330070dbca21a335177b0811a4134881a9232a2f  '"$kernel_dir/linux-image.deb" | sha256sum --check
apt-get install --yes "$kernel_dir/linux-modules.deb" "$kernel_dir/linux-image.deb"
test -f /boot/vmlinuz-6.8.0-1042-azure

cat > /etc/default/grub.d/99-kernel-1042.cfg <<'EOF'
GRUB_DEFAULT='Advanced options for Ubuntu>Ubuntu, with Linux 6.8.0-1042-azure'
EOF
update-grub
'''

// The VNet and subnet are provisioned once by the deploy script before the
// parallel VM deployments run, so they are referenced here as existing.
resource subnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = {
  name: '${vnetName}/${subnetName}'
}

resource publicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = if (createPublicIp) {
  name: publicIpName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-SSH-Any'
        properties: {
          priority: 1000
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: nicName
  location: location
  properties: {
    networkSecurityGroup: {
      id: nsg.id
    }
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: union({
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnet.id
          }
        }, createPublicIp ? {
          publicIPAddress: {
            id: resourceId('Microsoft.Network/publicIPAddresses', publicIpName)
          }
        } : {})
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2024-11-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'ubuntu-24_04-lts'
        sku: 'server'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
        provisionVMAgent: true
      }
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
          properties: {
            primary: true
          }
        }
      ]
    }
  }
}

resource kernelSetup 'Microsoft.Compute/virtualMachines/extensions@2024-11-01' = {
  parent: vm
  name: 'install-azure-kernel-1042'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    protectedSettings: {
      commandToExecute: 'echo ${base64(kernelSetupScript)} | base64 --decode > /tmp/install-azure-kernel-1042.sh && chmod 700 /tmp/install-azure-kernel-1042.sh && /tmp/install-azure-kernel-1042.sh'
    }
  }
}

output vmId string = vm.id
output vmName string = vm.name
output adminUsername string = adminUsername
output osVersion string = 'Ubuntu 24.04 LTS'
output kernelVersion string = kernelVersion
output privateIpAddress string = nic.properties.ipConfigurations[0].properties.privateIPAddress
output publicIpAddress string = publicIp.?properties.?ipAddress ?? ''
