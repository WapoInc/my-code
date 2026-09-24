#Build a AKS cluster with Ingress Controller and connect to App Gateway

# Connect to your Azure Subscription.
Connect-AzAccount

#----------------------------------------------------------------------------------------
# If you have more than one subscription, get a list of your Azure subscriptions.
Get-AzSubscription

#----------------------------------------------------------------------------------------
# Specify the subscription that you want to use.
Select-AzSubscription -SubscriptionName "@viresent - AIRS"



az aks create -n myCluster -g AFD-CDN-PoC --network-plugin azure --enable-managed-identity -a ingress-appgw --appgw-name myApplicationGateway --appgw-subnet-cidr "10.2.0.0/16" --generate-ssh-keys 
