prefix              = "lab8"
location            = "eastus2"
vm_count            = 2
vm_size             = "Standard_B1s"
admin_username      = "student"
ssh_public_key      = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdyTHOSKOThb/QwxXkb3pGMF0oELxDAEBaoLHZjTF2ivY5qlkcjl7ACoYB8RjIfIHMR3IExZnmsHdFPFH3uBCG4HiwdlVQcHoluEVBBLRg5aMVi5SSTU+StGuhj9OktcpSJfBXbwz4N3BCLXIzLBnQQuceh5IXNwqEQXZUBtMXmguo5kI1zdvEERUiPhf1DKArYYPBYkDGpYQNMkYF2Bfy0b4BshKDxUvMxqg6O4LT9TxWBNvIQzhR366SYMqnHU37KkbpzmA9m1F38pzXnDqt5BsaLCpMowijfWOKAlkJb0Bs9rxsWApXEfrDSHbE8vnkCSC4uWNMllWOK7aelTAy3Gfmx/BCt6zP7CIbc5AfBCXHJ3RRDkmb9enQR+I6N/hoLtZoiQ5hEvFTUab/X5ttDnw8XOL0hHN5dvlAjWvL93xQHtUbo49ujKcUfO5xlbHudhzsWqN6fBVmpJCtPY9F6Ww1Prrq7gMUrjp2SEuU7S+bDzgnsbWjSr35UMT32n0/JLKw5rbQSMbsuLxk+GA/IG2CBeLSD4lPBciXf6490G/1I046skgjXPUZFx8+krqdhHAQcNL49H7xk81WyL0MtJ8/bSoXWpYVgaq0D46ozHQtH/a9AxLbq8JJjzcMX/0SIkKwX2xk2+5bJsdIjgATgyChmWIFA/3iafxmEtRooQ== admin@DESKTOP-HM0SH9F"
allow_ssh_from_cidr = "179.51.125.11/32"

tags = {
  owner   = "roger"
  course  = "ARSW/BluePrints"
  env     = "dev"
  expires = "2026-12-31"
}
