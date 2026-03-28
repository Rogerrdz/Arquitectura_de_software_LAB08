output "backend_pool_id" {
  value = azurerm_lb_backend_address_pool.this.id
}

output "public_ip_address" {
  value = azurerm_public_ip.this.ip_address
}
