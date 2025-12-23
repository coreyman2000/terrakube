terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
      version = "0.89.1"
    }
  }
}

provider "proxmox" {
  endpoint  = var.pm_api_url
  api_token = "${var.pm_user}=${var.pm_password}"
  insecure  = true

  ssh {
    username = "root"
    password = var.proxmox_ssh_password # Reference the new variable here
  }
}

# --- 1. DEFINE AVAILABLE IMAGES ---
variable "cloud_images" {
  description = "Map of cloud images to download (Name -> URL)"
  type = map(object({
    url       = string
    file_name = string
  }))
  # We set defaults here so you don't HAVE to put this in Terrakube variables, 
  # but you can override it if you want.
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

# --- 2. DEFINE VMS (Now with 'image' selection) ---
variable "virtual_machines" {
  description = "Map of VMs to deploy"
  type = map(object({
    cores    = number
    memory   = number
    image    = string # Must match a key in 'cloud_images' (e.g. "ubuntu-jammy")
    username = string # Cloud-init user varies by OS (ubuntu vs debian)
  }))
}

resource "proxmox_virtual_environment_file" "cloud_config" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = "proxmox2"

  source_raw {
    file_name = "vm-init-config.yaml"
    data = <<EOF
#cloud-config
# 1. Update and install Guest Agent
package_update: true
packages:
  - qemu-guest-agent
  - [python-unversioned-command, false]

# 2. Configure the User (Moves it from the VM block to the snippet)
user: ${var.vm_username}
password: ${var.vm_password}
chpasswd: { expire: False }
ssh_authorized_keys:
  - ${var.ssh_public_key}

# 3. Start the Agent
runcmd:
  - apt-get purge -y python-unversioned-command || true
  - ln -sf /usr/bin/python3 /usr/bin/python
  - systemctl enable qemu-guest-agent
  - systemctl start qemu-guest-agent
  - dnf update -y
EOF
  }
}

# --- 3. DOWNLOAD ALL IMAGES ---
resource "proxmox_virtual_environment_download_file" "images" {
  for_each = var.cloud_images

  content_type        = "import"
  datastore_id        = "local"
  node_name           = "proxmox2"
  url                 = each.value.url
  file_name           = each.value.file_name
  overwrite_unmanaged = true
}

# --- 4. CREATE VMS ---
resource "proxmox_virtual_environment_vm" "vm_loop" {
  for_each = var.virtual_machines

  name            = each.key
  node_name       = "proxmox2"
  stop_on_destroy = true
  
  agent { enabled = true }
  serial_device {
    device = "socket"
  }

  memory { dedicated = each.value.memory }
  cpu { 
    cores = each.value.cores 
    type  = "host"   # This replaces the default 'qemu64'
  }

  initialization {
    # This links the uploaded snippet to the VM
    user_data_file_id = proxmox_virtual_environment_file.cloud_config.id
    ip_config {
      ipv4 { address = "dhcp" }
    }

    user_account {
      # Use the specific username for this VM (e.g. ubuntu or debian)
      username = each.value.username 
      password = "password"
      keys     = [var.ssh_public_key]
    }
  }

  disk {
    datastore_id = "local-lvm"
    
    # MAGIC HAPPENS HERE:
    # Look up the correct image ID based on the 'image' name provided in the variable
    import_from  = proxmox_virtual_environment_download_file.images[each.value.image].id
    
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
    size         = 25
    file_format  = "raw"
  }
  
  network_device { bridge = "vmbr0" }
  operating_system { type = "l26" }
}

variable "pm_api_url" { type = string }
variable "pm_user" { type = string }
variable "pm_password" { type = string }
variable "ssh_public_key" { type = string }

variable "vm_password" { type = string }
variable "vm_username" { type = string }

variable "proxmox_ssh_password" {
  description = "The root password for the Proxmox host OS"
  type        = string
  sensitive   = true
}
