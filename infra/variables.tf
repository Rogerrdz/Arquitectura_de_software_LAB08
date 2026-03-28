variable "prefix" {
  description = "Prefix used in naming convention"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "vm_count" {
  description = "Number of web VMs"
  type        = number
  default     = 2

  validation {
    condition     = var.vm_count >= 2
    error_message = "vm_count must be at least 2."
  }
}

variable "admin_username" {
  description = "Admin username for Linux VMs"
  type        = string
}

variable "ssh_public_key" {
  description = "Public key content or path to public key file"
  type        = string
}

variable "allow_ssh_from_cidr" {
  description = "IPv4 CIDR allowed to SSH (for example, 203.0.113.15/32)"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

variable "address_space" {
  description = "VNet address space"
  type        = list(string)
  default     = ["10.42.0.0/16"]
}

variable "subnet_web_cidr" {
  description = "CIDR for web subnet"
  type        = string
  default     = "10.42.1.0/24"
}

variable "subnet_mgmt_cidr" {
  description = "CIDR for management subnet"
  type        = string
  default     = "10.42.2.0/24"
}

variable "vm_size" {
  description = "VM SKU"
  type        = string
  default     = "Standard_B1s"
}
