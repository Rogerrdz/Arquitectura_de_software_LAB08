resource "azurerm_virtual_network" "this" {
  name                = "vnet-${var.prefix}"
  location            = var.location
  resource_group_name = var.resource_group
  address_space       = var.address_space
  tags                = var.tags
}

resource "azurerm_subnet" "web" {
  name                 = "subnet-web"
  resource_group_name  = var.resource_group
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.subnet_web_cidr]
}

resource "azurerm_subnet" "mgmt" {
  name                 = "subnet-mgmt"
  resource_group_name  = var.resource_group
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.subnet_mgmt_cidr]
}
