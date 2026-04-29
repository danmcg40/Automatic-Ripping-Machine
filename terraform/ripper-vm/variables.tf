variable "pm_api_url" {
  type = string
}

variable "pm_api_token_id" {
  type = string
}

variable "pm_api_token_secret" {
  type      = string
  sensitive = true
}

variable "target_node" {
  type    = string
  default = "pve"
}

variable "template_name" {
  type    = string
  default = "ubuntu-template-work"
}

variable "vm_name" {
  type    = string
  default = "automatic-ripping-machine"
}

variable "cpu_cores" {
  type    = number
  default = 2
}

variable "memory_mb" {
  type    = number
  default = 4096
}

variable "disk_size" {
  type    = string
  default = "60G"
}

variable "disk_storage" {
  type    = string
  default = "local-lvm"
}

variable "network_bridge" {
  type    = string
  default = "vmbr0"
}

variable "ssh_user" {
  type    = string
  default = "ubuntu"
}

variable "ssh_public_key" {
  type = string
}

variable "nameserver" {
  type    = string
  default = "192.168.0.1"
}

variable "searchdomain" {
  type    = string
  default = "local"
}