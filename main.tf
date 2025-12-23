terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.89.1"
    }
  }
}

provider "proxmox" {
  endpoint  = var.pm_api_url
  api_token = "${var.pm_user}=${var.pm_password}"
  insecure  = true

  ssh {
    agent    = false
    username = "root"
    password = var.proxmox_ssh_password
  }
}

# --- 1. DEFINE AVAILABLE IMAGES ---
variable "cloud_images" {
  description = "Map of cloud images to download"
  type = map(object({
    url       = string
    file_name = string
  }))
  default = {
    "ubuntu-jammy" = {
      url       = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
      file_name = "jammy-server-cloudimg-amd64.qcow2"
    }
    "debian-12" = {
      url       = "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
      file_name = "debian-12-generic-amd64.qcow2"
    }
  }
}

# --- 2. DEFINE VMS ---
variable "virtual_machines" {
  description = "Map of VMs to deploy"
  type = map(object({
    cores    = number
    memory   = number
    image    = string
    username = string
  }))
}

# --- 3. CLOUD-INIT SNIPPETS (Dynamic per VM) ---
resource "proxmox_virtual_environment_file" "cloud_config" {
  for_each     = var.virtual_machines
  content_type = "snippets"
  datastore_id = "local"
  node_name    = "proxmox2"

  source_raw {
    file_name = "cloud-config-${each.key}.yaml"
    
    data = <<EOF
#cloud-config
package_update: true
packages:
  - qemu-guest-agent

user: ${each.value.username}
password: password
chpasswd: { expire: False }
ssh_authorized_keys:
  - ${trimspace(var.ssh_public_key)}

runcmd:
  - systemctl enable qemu-guest-agent
  - systemctl start qemu-guest-agent
EOF
  }
}

# --- 4. DOWNLOAD IMAGES ---
resource "proxmox_virtual_environment_download_file" "images" {
  for_each = var.cloud_images

  content_type        = "import"
  datastore_id        = "local"
  node_name           = "proxmox2"
  url                 = each.value.url
  file_name           = each.value.file_name
  overwrite_unmanaged = true
}

# --- 5. CREATE VMS ---
resource "proxmox_virtual_environment_vm" "vm_loop" {
  for_each = var.virtual_machines

  name            = each.key
  node_name       = "proxmox2"
  stop_on_destroy = true
  
  agent { enabled = true }

  memory { dedicated = each.value.memory }
  cpu { 
    cores = each.value.cores 
    type  = "host" 
  }

  initialization {
    # Reference the specific snippet for THIS VM
    user_data_file_id = proxmox_virtual_environment_file.cloud_config[each.key].id

    ip_config {
      ipv4 { address = "dhcp" }
    }

    user_account {
      username = each.value.username 
      password = "password"
      keys     = [var.ssh_public_key]
    }
  }

  disk {
    datastore_id = "local-lvm"
    import_from  = proxmox_virtual_environment_download_file.images[each.value.image].id
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
    size         = 20
    file_format  = "raw"
  }
  
  network_device { bridge = "vmbr0" }
  operating_system { type = "l26" }
}

# --- VARIABLES ---
variable "pm_api_url" { type = string }
variable "pm_user" { type = string }
variable "pm_password" { type = string }
variable "ssh_public_key" { type = string }
variable "proxmox_ssh_password" {
  type      = string
  sensitive = true
}
