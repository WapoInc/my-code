

Parameters:

{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "connections_bup_to_er_connection_zan_via_zaw_name": {
            "defaultValue": "bup-to-er-connection-zan-via-zaw",
            "type": "String"
        },
        "virtualNetworkGateways_ER_GateWay_SA_North_Standard_externalid": {
            "defaultValue": "/subscriptions/0cfd0d2a-2b38-4c93-ba14-cf79185bc683/resourceGroups/er-ltsa-rg/providers/Microsoft.Network/virtualNetworkGateways/ER-GateWay-SA-North-Standard",
            "type": "String"
        },
        "expressRouteCircuits_ER_LTSA_SA_West_externalid": {
            "defaultValue": "/subscriptions/0cfd0d2a-2b38-4c93-ba14-cf79185bc683/resourceGroups/ER-LTSA-rg/providers/Microsoft.Network/expressRouteCircuits/ER-LTSA-SA-West",
            "type": "String"
        }
    },
    "variables": {},
    "resources": [
        {
            "type": "Microsoft.Network/connections",
            "apiVersion": "2024-07-01",
            "name": "[parameters('connections_bup_to_er_connection_zan_via_zaw_name')]",
            "location": "southafricanorth",
            "properties": {
                "virtualNetworkGateway1": {
                    "id": "[parameters('virtualNetworkGateways_ER_GateWay_SA_North_Standard_externalid')]",
                    "properties": {}
                },
                "connectionType": "ExpressRoute",
                "routingWeight": 10,
                "enableBgp": false,
                "useLocalAzureIpAddress": false,
                "usePolicyBasedTrafficSelectors": false,
                "ipsecPolicies": [],
                "trafficSelectorPolicies": [],
                "tunnelProperties": [],
                "peer": {
                    "id": "[parameters('expressRouteCircuits_ER_LTSA_SA_West_externalid')]"
                },
                "expressRouteGatewayBypass": false,
                "enablePrivateLinkFastPath": false,
                "dpdTimeoutSeconds": 0,
                "connectionMode": "Default",
                "gatewayCustomBgpIpAddresses": []
            }
        }
    ]
}



Variables:[
    {
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "connections_bup_to_er_connection_zan_via_zaw_name": {
            "defaultValue": "bup-to-er-connection-zan-via-zaw",
            "type": "String"
        },
        "virtualNetworkGateways_ER_GateWay_SA_North_Standard_externalid": {
            "defaultValue": "/subscriptions/0cfd0d2a-2b38-4c93-ba14-cf79185bc683/resourceGroups/er-ltsa-rg/providers/Microsoft.Network/virtualNetworkGateways/ER-GateWay-SA-North-Standard",
            "type": "String"
        },
        "expressRouteCircuits_ER_LTSA_SA_West_externalid": {
            "defaultValue": "/subscriptions/0cfd0d2a-2b38-4c93-ba14-cf79185bc683/resourceGroups/ER-LTSA-rg/providers/Microsoft.Network/expressRouteCircuits/ER-LTSA-SA-West",
            "type": "String"
        }
    },
    "variables": {},
    "resources": [
        {
            "type": "Microsoft.Network/connections",
            "apiVersion": "2024-07-01",
            "name": "[parameters('connections_bup_to_er_connection_zan_via_zaw_name')]",
            "location": "southafricanorth",
            "properties": {
                "virtualNetworkGateway1": {
                    "id": "[parameters('virtualNetworkGateways_ER_GateWay_SA_North_Standard_externalid')]",
                    "properties": {}
                },
                "connectionType": "ExpressRoute",
                "routingWeight": 10,
                "enableBgp": false,
                "useLocalAzureIpAddress": false,
                "usePolicyBasedTrafficSelectors": false,
                "ipsecPolicies": [],
                "trafficSelectorPolicies": [],
                "tunnelProperties": [],
                "peer": {
                    "id": "[parameters('expressRouteCircuits_ER_LTSA_SA_West_externalid')]"
                },
                "expressRouteGatewayBypass": false,
                "enablePrivateLinkFastPath": false,
                "dpdTimeoutSeconds": 0,
                "connectionMode": "Default",
                "gatewayCustomBgpIpAddresses": []
            }
        }
    ]
}


Resources:

{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "connections_bup_to_er_connection_zan_via_zaw_name": {
            "defaultValue": "bup-to-er-connection-zan-via-zaw",
            "type": "String"
        },
        "virtualNetworkGateways_ER_GateWay_SA_North_Standard_externalid": {
            "defaultValue": "/subscriptions/0cfd0d2a-2b38-4c93-ba14-cf79185bc683/resourceGroups/er-ltsa-rg/providers/Microsoft.Network/virtualNetworkGateways/ER-GateWay-SA-North-Standard",
            "type": "String"
        },
        "expressRouteCircuits_ER_LTSA_SA_West_externalid": {
            "defaultValue": "/subscriptions/0cfd0d2a-2b38-4c93-ba14-cf79185bc683/resourceGroups/ER-LTSA-rg/providers/Microsoft.Network/expressRouteCircuits/ER-LTSA-SA-West",
            "type": "String"
        }
    },
    "variables": {},
    "resources": [
        {
            "type": "Microsoft.Network/connections",
            "apiVersion": "2024-07-01",
            "name": "[parameters('connections_bup_to_er_connection_zan_via_zaw_name')]",
            "location": "southafricanorth",
            "properties": {
                "virtualNetworkGateway1": {
                    "id": "[parameters('virtualNetworkGateways_ER_GateWay_SA_North_Standard_externalid')]",
                    "properties": {}
                },
                "connectionType": "ExpressRoute",
                "routingWeight": 10,
                "enableBgp": false,
                "useLocalAzureIpAddress": false,
                "usePolicyBasedTrafficSelectors": false,
                "ipsecPolicies": [],
                "trafficSelectorPolicies": [],
                "tunnelProperties": [],
                "peer": {
                    "id": "[parameters('expressRouteCircuits_ER_LTSA_SA_West_externalid')]"
                },
                "expressRouteGatewayBypass": false,
                "enablePrivateLinkFastPath": false,
                "dpdTimeoutSeconds": 0,
                "connectionMode": "Default",
                "gatewayCustomBgpIpAddresses": []
            }
        }
    ]
}