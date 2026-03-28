locals {
  ssh_key_data = can(file(var.ssh_public_key)) ? trimspace(file(var.ssh_public_key)) : trimspace(var.ssh_public_key)
}

resource "azurerm_network_security_group" "web" {
  name                = "nsg-web-${var.prefix}"
  location            = var.location
  resource_group_name = var.resource_group
  tags                = var.tags

  security_rule {
    name                       = "allow-http-from-internet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-ssh-from-trusted-ip"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.allow_ssh_from_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-health-probe"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "web" {
  subnet_id                 = var.subnet_web_id
  network_security_group_id = azurerm_network_security_group.web.id
}

resource "azurerm_availability_set" "this" {
  name                         = "avail-${var.prefix}"
  location                     = var.location
  resource_group_name          = var.resource_group
  managed                      = true
  platform_fault_domain_count  = 2
  platform_update_domain_count = 2
  tags                         = var.tags
}

resource "azurerm_network_interface" "vm" {
  count               = var.vm_count
  name                = format("nic-%s-%02d", var.prefix, count.index + 1)
  location            = var.location
  resource_group_name = var.resource_group
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_web_id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface_backend_address_pool_association" "vm" {
  count                   = var.vm_count
  network_interface_id    = azurerm_network_interface.vm[count.index].id
  ip_configuration_name   = "internal"
  backend_address_pool_id = var.lb_backend_pool_id
}

resource "azurerm_linux_virtual_machine" "vm" {
  count               = var.vm_count
  name                = format("vm-%s-%02d", var.prefix, count.index + 1)
  location            = var.location
  resource_group_name = var.resource_group
  size                = var.vm_size
  admin_username      = var.admin_username
  network_interface_ids = [
    azurerm_network_interface.vm[count.index].id
  ]
  availability_set_id = azurerm_availability_set.this.id
  tags                = var.tags

  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = local.ssh_key_data
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  custom_data = base64encode(file(var.cloud_init_path))
}
