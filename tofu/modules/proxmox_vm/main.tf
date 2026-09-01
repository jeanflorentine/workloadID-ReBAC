terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

locals {
  module_tags               = sort(distinct(concat(var.vm_tags, ["orange-lab1", "portable", "k3s"])))

  use_local_image_source    = var.cloud_image_source_path != ""
  use_existing_image_file_id = var.cloud_image_file_id != ""
  resolved_import_source_id  = local.use_existing_image_file_id ? var.cloud_image_file_id : local.use_local_image_source ? proxmox_virtual_environment_file.reference_image[0].id : proxmox_virtual_environment_download_file.reference_image[0].id
}

resource "proxmox_virtual_environment_file" "reference_image" {
  count = local.use_local_image_source ? 1 : 0

  content_type = "import"
  datastore_id = var.image_datastore_id
  node_name    = var.proxmox_node_name

  source_file {
    file_name = var.cloud_image_file_name != "" ? var.cloud_image_file_name : basename(var.cloud_image_source_path)
    path      = var.cloud_image_source_path
  }
}

resource "proxmox_virtual_environment_download_file" "reference_image" {
  count = local.use_existing_image_file_id || local.use_local_image_source ? 0 : 1

  content_type = "import"
  datastore_id = var.image_datastore_id
  node_name    = var.proxmox_node_name
  url          = var.cloud_image_url
  file_name    = var.cloud_image_file_name
}

resource "proxmox_virtual_environment_vm" "reference_vm" {
  name        = var.vm_name
  description = var.vm_description
  tags        = local.module_tags

  node_name = var.proxmox_node_name
  vm_id     = var.proxmox_vm_id

  agent {
    enabled = false
  }

  stop_on_destroy   = true
  on_boot           = true
  started           = var.vm_started
  scsi_hardware     = "virtio-scsi-single"
  reboot_after_update = true

  cpu {
    cores = var.cpu_cores
    type  = var.cpu_type
  }

  memory {
    dedicated = var.memory_mb
    floating  = var.enable_ballooning ? var.memory_mb : 0
  }

  disk {
    datastore_id = var.vm_datastore_id
    import_from  = local.resolved_import_source_id
    interface    = "scsi0"
    size         = var.disk_size_gb
  }

  initialization {
    datastore_id = var.vm_datastore_id

    dns {
      servers = var.dns_servers
      domain  = var.dns_search_domain != "" ? var.dns_search_domain : null
    }

    ip_config {
      ipv4 {
        address = var.vm_ipv4_cidr
        gateway = var.vm_ipv4_gateway != "" ? var.vm_ipv4_gateway : null
      }
    }

    user_account {
      username = var.vm_username
      keys     = [trimspace(var.vm_ssh_public_key)]
    }
  }

  network_device {
    bridge  = var.network_bridge
    firewall = false
    model   = "virtio"
    vlan_id = var.network_vlan_id > 0 ? var.network_vlan_id : null
  }

  operating_system {
    type = "l26"
  }

  serial_device {}
}
