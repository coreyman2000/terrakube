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

# --- 1. NEW VARIABLE FOR MULTIPLE VMS ---
variable "virtual_machines" {
  description = "Map of VMs to deploy"
  # This expects a format like:
  # {
  #   "vm-name-1" = { cores = 2, memory = 2048 }
  #   "vm-name-2" = { cores = 4, memory = 4096 }
  # }
  type = map(object({
    cores  = number
    memory = number
  }))
}

resource "proxmox_virtual_environment_vm" "ubuntu_vm" {
  # --- 2. THE LOOP ---
  for_each = var.virtual_machines

  # Use the key from the variable (e.g., "web-server") as the VM Name
  name      = each.key
  node_name = "proxmox2"
  stop_on_destroy = true
  
  agent {
    enabled = false
  }

  # --- 3. DYNAMIC SPECS ---
  memory {
    # Use the value from the variable (e.g., 2048)
    dedicated = each.value.memory
  }

  cpu {
    # Use the value from the variable (e.g., 2)
    cores = each.value.cores
  }

  initialization {
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    user_account {
      username = "user"
      password = "password"
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
