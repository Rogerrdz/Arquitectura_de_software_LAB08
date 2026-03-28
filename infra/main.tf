locals {
  rg_name = "rg-${var.prefix}-${var.location}"

  common_tags = merge(
    {
      course = "ARSW/BluePrints"
      env    = "dev"
    },
    var.tags
  )
}

resource "azurerm_resource_group" "this" {
  name     = local.rg_name
  location = var.location
  tags     = local.common_tags
}

module "vnet" {
  source = "../modules/vnet"

  prefix           = var.prefix
  location         = var.location
  resource_group   = azurerm_resource_group.this.name
  address_space    = var.address_space
  subnet_web_cidr  = var.subnet_web_cidr
  subnet_mgmt_cidr = var.subnet_mgmt_cidr
  tags             = local.common_tags
}

module "lb" {
  source = "../modules/lb"

  prefix         = var.prefix
  location       = var.location
  resource_group = azurerm_resource_group.this.name
  tags           = local.common_tags
}

module "compute" {
  source = "../modules/compute"

  prefix              = var.prefix
  location            = var.location
  resource_group      = azurerm_resource_group.this.name
  vm_count            = var.vm_count
  vm_size             = var.vm_size
  subnet_web_id       = module.vnet.subnet_web_id
  lb_backend_pool_id  = module.lb.backend_pool_id
  admin_username      = var.admin_username
  ssh_public_key      = var.ssh_public_key
  allow_ssh_from_cidr = var.allow_ssh_from_cidr
  cloud_init_path     = "${path.module}/cloud-init.yaml"
  tags                = local.common_tags
}
