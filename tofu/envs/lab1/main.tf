locals {
  use_local_hypervisor = var.target_platform == "local-hypervisor"
  use_openstack        = var.target_platform == "openstack"
  use_proxmox          = var.target_platform == "proxmox"
}

module "proxmox_vm" {
  source = "../../modules/proxmox_vm"
  count  = local.use_proxmox ? 1 : 0

  proxmox_node_name    = var.proxmox_node_name
  proxmox_vm_id        = var.proxmox_vm_id
  image_datastore_id   = var.image_datastore_id
  vm_datastore_id      = var.vm_datastore_id
  cloud_image_url      = var.cloud_image_url
  cloud_image_source_path = var.cloud_image_source_path
  cloud_image_file_name = var.cloud_image_file_name
  cloud_image_file_id  = var.cloud_image_file_id
  vm_name              = var.vm_name
  vm_description       = var.vm_description
  vm_tags              = var.vm_tags
  cpu_cores            = var.cpu_cores
  cpu_type             = var.cpu_type
  memory_mb            = var.memory_mb
  enable_ballooning    = var.enable_ballooning
  disk_size_gb         = var.disk_size_gb
  network_bridge       = var.network_bridge
  network_vlan_id      = var.network_vlan_id
  vm_username          = var.vm_username
  vm_ssh_public_key    = var.vm_ssh_public_key
  vm_ipv4_cidr         = var.vm_ipv4_cidr
  vm_ipv4_gateway      = var.vm_ipv4_gateway
  vm_ipv4_address      = var.vm_ipv4_address
  dns_servers          = var.dns_servers
  dns_search_domain    = var.dns_search_domain
  vm_started           = var.vm_started
}

module "local_hypervisor_vm" {
  source = "../../modules/local_hypervisor_vm"
  count  = local.use_local_hypervisor ? 1 : 0

  vm_name = var.vm_name
}

module "openstack_vm" {
  source = "../../modules/openstack_vm"
  count  = local.use_openstack ? 1 : 0

  vm_name = var.vm_name
}

module "k3s_bootstrap" {
  source = "../../modules/k3s_bootstrap"

  depends_on = [
    module.proxmox_vm,
    module.local_hypervisor_vm,
    module.openstack_vm,
  ]

  vm_name                  = var.vm_name
  target_platform          = var.target_platform
  target_host              = var.vm_ipv4_address
  ssh_username             = var.vm_username
  ssh_private_key_path     = var.ssh_private_key_path
  ssh_port                 = var.ssh_port
  k3s_channel              = var.k3s_channel
  install_qemu_guest_agent = var.install_qemu_guest_agent
}

module "kube_namespaces" {
  source = "../../modules/kube_namespaces"

  namespace_names = var.namespace_names
}

module "helm_keycloak" {
  source = "../../modules/helm_keycloak"
  count  = var.enable_keycloak ? 1 : 0

  depends_on = [module.kube_namespaces]

  namespace       = var.keycloak_namespace
  release_name    = var.keycloak_release_name
  chart_version   = var.keycloak_chart_version
  admin_username  = var.keycloak_admin_username
  admin_password  = var.keycloak_admin_password
  timeout_seconds = var.keycloak_timeout_seconds
}
