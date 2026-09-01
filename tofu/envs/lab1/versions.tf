terraform {
  required_version = ">= 1.6.0"

  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.15"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.32"
    }

    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 3.0"
    }

    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.78"
    }
  }
}
