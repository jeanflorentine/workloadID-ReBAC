locals {
  guest_agent_commands = var.install_qemu_guest_agent ? [
    "sudo apt-get update",
    "sudo apt-get install -y qemu-guest-agent",
    "sudo systemctl enable --now qemu-guest-agent || sudo systemctl start qemu-guest-agent || true",
  ] : []

  bootstrap_commands = concat(
    [
      "set -eux",
      "curl -fsSL https://get.k3s.io -o /tmp/get-k3s.sh",
      "sudo INSTALL_K3S_CHANNEL='${var.k3s_channel}' sh /tmp/get-k3s.sh server --write-kubeconfig-mode 644 --node-name ${var.vm_name}",
      "for i in $(seq 1 24); do if [ -f /etc/systemd/system/k3s.service ]; then break; fi; sleep 5; done",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable --now k3s",
      "for i in $(seq 1 24); do sudo systemctl is-active --quiet k3s && break; sleep 5; done",
      "sudo kubectl get nodes -o wide",
    ],
    local.guest_agent_commands,
  )
}

resource "terraform_data" "bootstrap" {
  input = {
    vm_name             = var.vm_name
    target_platform     = var.target_platform
    target_host         = var.target_host
    ssh_username        = var.ssh_username
    ssh_port            = var.ssh_port
    k3s_channel         = var.k3s_channel
    install_guest_agent = var.install_qemu_guest_agent
  }

  provisioner "remote-exec" {
    inline = local.bootstrap_commands
  }

  connection {
    type        = "ssh"
    host        = var.target_host
    user        = var.ssh_username
    port        = var.ssh_port
    private_key = file(var.ssh_private_key_path)
    timeout     = "10m"
  }
}
