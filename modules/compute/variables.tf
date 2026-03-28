variable "prefix" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group" {
  type = string
}

variable "vm_count" {
  type = number
}

variable "vm_size" {
  type = string
}

variable "subnet_web_id" {
  type = string
}

variable "lb_backend_pool_id" {
  type = string
}

variable "admin_username" {
  type = string
}

variable "ssh_public_key" {
  type = string
}

variable "allow_ssh_from_cidr" {
  type = string
}

variable "cloud_init_path" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
