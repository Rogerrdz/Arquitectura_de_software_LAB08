output "vm_names" {
  value = [for vm in azurerm_linux_virtual_machine.vm : vm.name]
}

output "vm_private_ips" {
  value = [for nic in azurerm_network_interface.vm : nic.private_ip_address]
}
