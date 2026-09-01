variable "vm_name" {
  description = "Reference VM name used for labeling and documentation."
  type        = string
}

variable "target_platform" {
  description = "Current infrastructure target."
  type        = string
}

variable "target_host" {
  description = "IPv4 or hostname used to reach the guest over SSH."
  type        = string
}

variable "ssh_username" {
  description = "SSH user used to bootstrap k3s."
  type        = string
}

variable "ssh_private_key_path" {
  description = "Private key path used by remote-exec."
  type        = string
}

variable "ssh_port" {
  description = "SSH port used to bootstrap k3s."
  type        = number
  default     = 22
}

variable "k3s_channel" {
  description = "Installation channel for k3s."
  type        = string
}

variable "install_qemu_guest_agent" {
  description = "Whether to install qemu-guest-agent during bootstrap."
  type        = bool
}
