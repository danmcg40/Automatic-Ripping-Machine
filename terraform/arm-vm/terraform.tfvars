pm_api_url          = "https://YOUR-PROXMOX:8006/api2/json"
pm_api_token_id     = "terraform@pve!token"
pm_api_token_secret = "YOUR_SECRET"

template_name  = "ubuntu-template"
vm_name        = "automatic-ripping-machine"
target_node    = "pve"
cpu_cores      = 2
memory_mb      = 4096
disk_size      = "60G"
disk_storage   = "local-lvm"
network_bridge = "vmbr0"

ssh_user       = "ubuntu"
ssh_public_key = "ssh-ed25519 AAAA..."
nameserver     = "192.168.0.1"
searchdomain   = "local"