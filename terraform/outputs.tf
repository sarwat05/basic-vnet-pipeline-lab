output "resource_group" {
  value = azurerm_resource_group.lab.name
}

output "vnet_name" {
  value = azurerm_virtual_network.lab.name
}

output "vnet_address_space" {
  value = azurerm_virtual_network.lab.address_space
}

output "subnet_id" {
  value = azurerm_subnet.default.id
}
