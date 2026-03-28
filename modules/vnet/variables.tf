variable "prefix" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group" {
  type = string
}

variable "address_space" {
  type = list(string)
}

variable "subnet_web_cidr" {
  type = string
}

variable "subnet_mgmt_cidr" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
