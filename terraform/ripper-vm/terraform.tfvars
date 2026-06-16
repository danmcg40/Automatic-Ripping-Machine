pm_api_url          = var.pm_api_url

template_name  = "ubuntu-template-work"
vm_name        = "automatic-ripping-machine"
target_node    = "pve"
cpu_cores      = 2
memory_mb      = 4096
disk_size      = "60G"
disk_storage   = "local-lvm"
network_bridge = "vmbr0"

ssh_user       = "ubuntu"
nameserver     = "192.168.0.1"
searchdomain   = "local"