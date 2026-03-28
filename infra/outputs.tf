output "resource_group_name" {
  description = "Resource group name"
  value       = azurerm_resource_group.this.name
}

output "lb_public_ip" {
  description = "Public IP address of the load balancer"
  value       = module.lb.public_ip_address
}

output "vm_names" {
  description = "VM names"
  value       = module.compute.vm_names
}

output "vm_private_ips" {
  description = "VM private IPs"
  value       = module.compute.vm_private_ips
}
