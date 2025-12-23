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
  
  # Connect using your existing variables
  # Format combines them: user@realm!token=secret
  api_token = "${var.pm_user}=${var.pm_password}"
  
  insecure = true
  
  # This provider needs a tmp folder
  tmp_dir  = "/tmp"
}

resource "proxmox_virtual_environment_vm" "ubuntu_vm" {
  name      = "test-ubuntu"
  node_name = "proxmox2"

  # should be true if qemu agent is not installed / enabled on the VM
  stop_on_destroy = true

  initialization {
    user_account {
      # do not use this in production, configure your own ssh key instead!
      username = "user"
      password = "password"
    }
  }

  disk {
    datastore_id = "local-lvm"
    import_from  = proxmox_virtual_environment_download_file.ubuntu_cloud_image.id
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
    size         = 20
  }
}

resource "proxmox_virtual_environment_download_file" "ubuntu_cloud_image" {
  content_type = "import"
  datastore_id = "local"
  node_name    = "pve"
  url          = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
  # need to rename the file to *.qcow2 to indicate the actual file format for import
  file_name = "jammy-server-cloudimg-amd64.qcow2"
}
variable "pm_api_url" { type = string }
variable "pm_user" { type = string }
variable "pm_password" { type = string }
