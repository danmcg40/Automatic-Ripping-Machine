terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.2-rc07"
    }
  }
}

provider "proxmox" {
  pm_api_url          = var.pm_api_url
  pm_api_token_id     = var.pm_api_token_id
  pm_api_token_secret = var.pm_api_token_secret
  pm_tls_insecure     = true
}

locals {
  ripper_mac = "BC:24:11:00:10:10"
}

resource "proxmox_vm_qemu" "ripper" {
  name         = var.vm_name
  target_node  = var.target_node
  clone        = var.template_name
  full_clone   = true
  onboot       = true
  agent        = 1
  vm_state     = "running"
  force_create = false

  memory = var.memory_mb

  scsihw = "virtio-scsi-pci"

  serial {
    id   = 0
    type = "socket"
  }

  vga {
    type = "serial0"
  }

  cpu {
    cores   = var.cpu_cores
    sockets = 1
  }

  network {
    id      = 0
    model   = "virtio"
    bridge  = var.network_bridge
    macaddr = local.ripper_mac
  }

  disks {
  ide {
    ide2 {
      cloudinit {
        storage = var.disk_storage
      }
    }
  }
  
    scsi {
      scsi0 {
        disk {
          size    = var.disk_size
          storage = var.disk_storage
        }
      }
    }
  }

  ciuser     = var.ssh_user
  sshkeys    = trimspace(var.ssh_public_key)
  ipconfig0  = "ip=dhcp"
  nameserver = var.nameserver
  searchdomain = var.searchdomain
}

output "ripper_vm" {
  value = {
    name = proxmox_vm_qemu.ripper.name
    vmid = proxmox_vm_qemu.ripper.vmid
    mac  = local.ripper_mac
    ip   = try(proxmox_vm_qemu.ripper.default_ipv4_address, "")
  }
}