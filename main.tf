# test 
terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.2-rc07"  # Changed from 2.9.14 to fix Proxmox 9 support
    }
  }
}

provider "proxmox" {
  pm_api_url          = var.pm_api_url
  
  # CHANGE: Use token arguments instead of user/password
  pm_api_token_id     = var.pm_user      # Use the value "root@pam!terrakube"
  pm_api_token_secret = var.pm_password  # Use the UUID secret
  
  # IMPORTANT: Do NOT include pm_user or pm_password lines here
  
  pm_tls_insecure     = true
}

resource "proxmox_vm_qemu" "test_server" {
  name        = "terrakube-test-vm"
  target_node = "pve"
  
  # CHANGE: Try this as a simple string argument
  cdrom = "local:iso/ubuntu-20.04.iso"

  cores       = 2
  memory      = 2048
  agent       = 1
  
  network {
    id     = 0
    model  = "virtio"
    bridge = "vmbr0"
  }

  disk {
    slot    = "scsi0"
    type    = "scsi"
    storage = "local-lvm"
    size    = "10G"
  }
}

variable "pm_api_url" { type = string }
variable "pm_user" { type = string }
variable "pm_password" { type = string }
