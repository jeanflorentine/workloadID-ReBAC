# WSL Tooling Path

## Purpose

Keep a parallel Linux tooling path available while the preferred VM runtime decision is pending.

Implementation status:
1. Documented and ready.
2. Intentionally not implemented yet, per current decision to prioritize the VM runtime path first.

## Role of this path

1. Provide a Linux userland for OpenTofu or Terraform, kubectl, helm, ssh, and shell scripts.
2. Reduce friction on Windows when Linux-first tooling is easier to run in WSL.
3. Stay useful even if the final runtime is a real VM on the laptop or on Orange infrastructure.

## What WSL should be used for

1. Running the IaC toolchain.
2. Running kubectl and helm.
3. Running Linux-native shell checks and helper scripts.
4. Validating generated kubeconfig access.
5. Performing remote operations against Proxmox-hosted or Orange-hosted lab targets.

## What WSL should not be assumed to replace

1. The portable VM artefact.
2. A real laptop-hosted runtime if Hyper-V is available.
3. The eventual Orange Proxmox or OpenStack target.

## Current verified facts on this Windows 11 station

1. WSL 2 is active.
2. Debian is the default distribution.
3. `VirtualMachinePlatform` is enabled.
4. Full Hyper-V is disabled.

## Suggested workstation sequence inside WSL

1. Verify distribution status with `wsl --status` and `wsl -l -v` from Windows.
2. Open the default Debian distribution.
3. Install Linux-side tooling as needed: curl, git, openssh-client, unzip, kubectl, helm, and OpenTofu or Terraform.
4. Access the workspace through `/mnt/c/Projects/Orange-Lab1`.
5. Run the IaC workflow from WSL while keeping source files in the same repository.

## Command sequence (Windows + WSL)

1. Verify WSL status from Windows PowerShell:

```powershell
wsl --status
wsl -l -v
```

2. Open Debian in WSL:

```powershell
wsl -d Debian
```

3. Install base tooling in Debian:

```bash
sudo apt-get update
sudo apt-get install -y curl git openssh-client unzip ca-certificates gnupg lsb-release
```

4. Install kubectl (Debian upstream apt repository):

```bash
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubectl
```

5. Install helm:

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

6. Install one IaC CLI (choose one):

Option A: OpenTofu

```bash
curl --proto '=https' --tlsv1.2 -fsSL https://get.opentofu.org/install-opentofu.sh | sh
```

Option B: Terraform

```bash
sudo apt-get update
sudo apt-get install -y terraform
```

7. Move to the shared workspace from WSL and run the same workflow:

```bash
cd /mnt/c/Projects/Orange-Lab1/tofu/envs/lab1

if command -v tofu >/dev/null 2>&1; then
	tofu init
	tofu validate
	tofu plan
elif command -v terraform >/dev/null 2>&1; then
	terraform init
	terraform validate
	terraform plan
else
	echo "Neither tofu nor terraform is installed."
fi
```

## Current policy-aware position

1. Keep WSL as a ready tooling path now.
2. Keep VM runtime as the preferred final execution path if Orange policy allows it.
3. Use the same repository and variable model in both paths.
4. Activate this path only when needed, or once Orange confirms constraints requiring it.

## Practical value even if VM runtime wins

1. WSL can remain the operator environment.
2. The actual lab runtime can still live in a Proxmox VM, Hyper-V VM, or Orange-hosted VM.
3. This split is often the least disruptive option on managed Windows laptops.
