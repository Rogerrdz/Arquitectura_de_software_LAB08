output "vnet_id" {
  value = azurerm_virtual_network.this.id
}

output "subnet_web_id" {
  value = azurerm_subnet.web.id
}

output "subnet_mgmt_id" {
  value = azurerm_subnet.mgmt.id
}
