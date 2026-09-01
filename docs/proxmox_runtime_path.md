# Proxmox Runtime Path

## Purpose

Proceed immediately with the preferred runtime model while the Orange laptop policy decision is still pending.

## Role of this path

1. Start work now on the reference VM and k3s runtime.
2. Keep the runtime model aligned with the preferred end state: a real VM-based lab.
3. Avoid design choices that would block later migration to the Orange laptop or Orange-hosted virtualization.

## Current assumptions

1. Home Proxmox admin GUI is reachable at `https://192.168.1.44:8006`.
2. The first target is a single-node Debian 12 Bookworm cloud image VM.
3. k3s is the first cluster runtime.

## SSH bootstrap clarification

1. The SSH key used by `k3s_bootstrap` is for the guest VM login user (`vm_username`, currently `debian`).
2. You do not need to create an SSH key on Proxmox for host user `root` to bootstrap k3s in the guest.
3. Proxmox API credentials are used by the provider to create the VM.
4. Guest SSH credentials are used by `remote-exec` to install k3s inside the new VM.

## Immediate execution sequence

1. Copy `tofu/envs/lab1/terraform.tfvars.example` to a local `terraform.tfvars`.
2. Replace the placeholder SSH public key value.
3. Verify the exact Proxmox node name and datastore names.
4. Provide Proxmox credentials through environment variables, not in git.
5. Run init, validate, and plan in `tofu/envs/lab1` once OpenTofu or Terraform is installed.
6. Apply only after the VM definition and network values are reviewed.
7. Confirm SSH reachability to the VM.
8. Run the k3s bootstrap path.
9. Fetch kubeconfig and validate node readiness.

## Command sequence (PowerShell)

Use one terminal session from the workspace root.

1. Export Proxmox provider environment variables (session scope only):

```powershell
$env:PROXMOX_VE_ENDPOINT = "https://192.168.1.44:8006/"
$env:PROXMOX_VE_INSECURE = "true"

# Choose one auth method.
# Option A: API token
# $env:PROXMOX_VE_API_TOKEN = "user@realm!tokenid=secret"

# Option B: username/password
# $env:PROXMOX_VE_USERNAME = "root@pam"
# $env:PROXMOX_VE_PASSWORD = "REPLACE_ME"
```

2. Create local runtime variable file from the example:

```powershell
Copy-Item -LiteralPath "tofu/envs/lab1/terraform.tfvars.example" -Destination "tofu/envs/lab1/terraform.tfvars"
```

3. Edit `tofu/envs/lab1/terraform.tfvars` and set real values for:

1. `vm_ssh_public_key`
2. `proxmox_node_name`
3. `image_datastore_id`
4. `vm_datastore_id`
5. `vm_ipv4_address`, `vm_ipv4_cidr`, `vm_ipv4_gateway`
6. `dns_servers`
7. `ssh_private_key_path`

4. Initialize and validate (OpenTofu if installed, Terraform otherwise):

```powershell
Set-Location -LiteralPath "tofu/envs/lab1"

if (Get-Command tofu -ErrorAction SilentlyContinue) {
	tofu init
	tofu validate
	tofu plan -out=tfplan
} elseif (Get-Command terraform -ErrorAction SilentlyContinue) {
	terraform init
	terraform validate
	terraform plan -out=tfplan
} else {
	Write-Error "Neither tofu nor terraform is installed in this shell."
}
```

5. Apply after plan review:

```powershell
if (Get-Command tofu -ErrorAction SilentlyContinue) {
	tofu apply tfplan
} elseif (Get-Command terraform -ErrorAction SilentlyContinue) {
	terraform apply tfplan
}
```

6. Pull kubeconfig from the new VM after bootstrap:

```powershell
# Example using the values from terraform.tfvars
ssh -i C:/Users/jflorentin/.ssh/id_ed25519 debian@192.168.1.210 sudo cat /etc/rancher/k3s/k3s.yaml > k3s.yaml
```

## Current blocker on this station

1. `kubectl`, `helm`, `tofu`, and `terraform` were not found in the latest prerequisite check.
2. Install at least one IaC CLI (`tofu` or `terraform`) before running init and plan.

## Required variables to confirm

1. `proxmox_node_name`
2. `image_datastore_id`
3. `vm_datastore_id`
4. `vm_ipv4_address`
5. `vm_ipv4_gateway`
6. `dns_servers`
7. `vm_ssh_public_key`
8. `ssh_private_key_path`

## Guardrails

1. Do not hard-code credentials in files.
2. Do not rely on home-only state or secrets.
3. Keep the VM definition generic enough to be re-expressed later for Hyper-V or OpenStack.
4. Treat this as the preferred runtime track until Orange policy says otherwise.
