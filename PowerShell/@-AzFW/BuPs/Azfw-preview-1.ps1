


Connect-AzAccount 
Select-AzSubscription -Subscription "@viresent - New AIRS-ME-MngEnv461963" 
Register-AzProviderFeature -FeatureName AFWEnableNetworkRuleNameLogging -ProviderNamespace Microsoft.Network
Register-AzResourceProvider -ProviderNamespace Microsoft.Network





Connect-AzAccount 
Select-AzSubscription -Subscription "@viresent - New AIRS-ME-MngEnv461963" 
Register-AzProviderFeature -FeatureName AFWEnableStructuredLogs -ProviderNamespace Microsoft.Network
Register-AzResourceProvider -ProviderNamespace Microsoft.Network