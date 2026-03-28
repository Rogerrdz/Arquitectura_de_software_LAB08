resource "azurerm_public_ip" "this" {
  name                = "pip-lb-${var.prefix}"
  location            = var.location
  resource_group_name = var.resource_group
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_lb" "this" {
  name                = "lb-${var.prefix}"
  location            = var.location
  resource_group_name = var.resource_group
  sku                 = "Standard"
  tags                = var.tags

  frontend_ip_configuration {
    name                 = "public-frontend"
    public_ip_address_id = azurerm_public_ip.this.id
  }
}

resource "azurerm_lb_backend_address_pool" "this" {
  name            = "web-backend-pool"
  loadbalancer_id = azurerm_lb.this.id
}

resource "azurerm_lb_probe" "this" {
  name            = "http-80-probe"
  loadbalancer_id = azurerm_lb.this.id
  port            = 80
  protocol        = "Tcp"
}

resource "azurerm_lb_rule" "http" {
  name                           = "http-80-rule"
  loadbalancer_id                = azurerm_lb.this.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "public-frontend"
  probe_id                       = azurerm_lb_probe.this.id
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.this.id]
}
