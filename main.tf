# test 
terraform {
  required_providers {
    proxmox = {
      source = "Telmate/proxmox"
      version = "2.9.14"
    }
  }
}

provider "proxmox" {
  # These will be pulled from Terrakube variables
  pm_api_url      = var.pm_api_url
  pm_user         = var.pm_user
  pm_password     = var.pm_password
  pm_tls_insecure = true
}

resource "proxmox_vm_qemu" "test_server" {
  name        = "terrakube-test-vm"
  target_node = "pve" # CHANGE THIS to your Proxmox node name
  iso         = "local:iso/ubuntu-20.04.iso" # Ensure this ISO exists on your Proxmox storage

  cores       = 2
  memory      = 2048
  agent       = 1
  
  network {
    model  = "virtio"
    bridge = "vmbr0"
  }

  disk {
    type    = "scsi"
    storage = "local-lvm" # CHANGE THIS to your storage ID
    size    = "10G"
  }
}

variable "pm_api_url" { type = string }
variable "pm_user" { type = string }
variable "pm_password" { type = string }
