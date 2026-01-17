
output "public_ip_address" {
  value = azurerm_public_ip.vnet_public_ip.ip_address
}

# output "registry_pass" {
#   value = azurerm_container_registry.app_registry.admin_password
# }

# output "registry_user" {
#   value = azurerm_container_registry.app_registry.admin_username
# }

# output "registry_url" {
#   value = azurerm_container_registry.app_registry.login_server
# }

output "logAnalyticsWorkspace" {
  value = azapi_resource.logAnalyticsWorkspace.id
}

# output "AppInsightsWorkspace" {
#   value = azapi_resource.AppInsights.i
# }

output "rg_vnet" {
  value = azurerm_virtual_network.rg_vnet.id
}

output "rg_vnet_nic" {
  value = azurerm_network_interface.rg_nic.id
}

output "rg_vnet_nsg" {
  value = azurerm_network_security_group.rg_nsg.id
}




