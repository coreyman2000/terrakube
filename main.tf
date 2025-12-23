terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
      version = "0.89.1"
    }
  }
}

provider "proxmox" {
  endpoint = var.pm_api_url
  api_token = "${var.pm_user}=${var.pm_password}"
  insecure = true
  tmp_dir  = "/tmp"
}

resource "proxmox_virtual_environment_vm" "ubuntu_vm" {
  name      = "test-ubuntu"
  node_name = "proxmox2"
  stop_on_destroy = true
  
  agent {
    enabled = true
  }

  # --- ADDED MEMORY BLOCK HERE ---
  memory {
    dedicated = 2048
  }

  # Optional: Define CPU cores if you want
  cpu {
    cores = 2
  }

  initialization {
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    user_account {
      username = "user"
      keys     = [var.ssh_public_key]
    }
  }

  disk {
    datastore_id = "local-lvm"
    import_from  = proxmox_virtual_environment_download_file.ubuntu_cloud_image.id
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
    size         = 20
    file_format  = "raw"
  }
  
  network_device {
    bridge = "vmbr0"
  }
  
  operating_system {
    type = "l26"
  }
}

resource "proxmox_virtual_environment_download_file" "ubuntu_cloud_image" {
  content_type = "import"
  datastore_id = "local"
  node_name    = "proxmox2"
  url          = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
  file_name    = "jammy-server-cloudimg-amd64.qcow2"
}

variable "pm_api_url" { type = string }
variable "pm_user" { type = string }
variable "pm_password" { type = string }
variable "ssh_public_key" { type = string }
