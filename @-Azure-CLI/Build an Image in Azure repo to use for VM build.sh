

# Build a Image to use when building a VM

az image create --name MK-CHR-2 --resource-group My-HD-Stash --location southafricanorth --os-type linux --hyper-v-generation V1 --source https://myhdstash.blob.core.windows.net/mikrotik/chr-6.48.6.vhd