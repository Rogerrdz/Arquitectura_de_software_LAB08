prefix              = "lab8-prod"
location            = "eastus"
vm_count            = 2
vm_size             = "Standard_B1ms"
admin_username      = "student"
ssh_public_key      = "C:/Users/Admin/.ssh/id_ed25519.pub"
allow_ssh_from_cidr = "179.51.125.11/32"

tags = {
  owner   = "admin"
  course  = "ARSW/BluePrints"
  env     = "prod"
  expires = "2026-12-31"
}
