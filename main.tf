terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
      version = "0.69.1"
    }
  }
}

provider "proxmox" {
  endpoint = var.pm_api_url
  
  # Connect using your existing variables
  # Format combines them: user@realm!token=secret
  api_token = "${var.pm_user}=${var.pm_password}"
  
  insecure = true
  
  # This provider needs a tmp folder
  tmp_dir  = "/tmp"
}

resource "proxmox_virtual_environment_vm" "test_server" {
  name      = "terrakube-vm"
  node_name = "proxmox2" # CHANGE THIS if your node is not named 'pve'

  cpu {
    cores = 2
  }

  memory {
    dedicated = 2048
  }

  agent {
    enabled = true
  }

  network_device {
    bridge = "vmbr0"
  }

  disk {
    datastore_id = "local-lvm" # CHANGE THIS if your storage is local-zfs
    interface    = "scsi0"
    size         = 10
    file_format  = "raw"
  }

  cdrom {
    file_id = "local:iso/ubuntu-20.04.iso" # Ensure this path is 100% correct in Proxmox
  }
  
  operating_system {
    type = "l26" # Linux 2.6+
  }
}

variable "pm_api_url" { type = string }
variable "pm_user" { type = string }
variable "pm_password" { type = string }
