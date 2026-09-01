# Runbooks

## Phase 1 bootstrap evidence to capture

1. Target selected: home Proxmox, Orange laptop, or Orange enterprise virtualization.
2. Tool versions used.
3. Guest OS image used for the reference VM.
4. k3s installation result.
5. kubeconfig validation result.
6. Health status for Keycloak and the first supporting component.
7. Redeploy or rebuild result with no manual drift correction.

## Rebuild rule

For every step, record:

1. Objective.
2. Command or action.
3. Expected outcome.
4. Verification method.
5. Reset or rollback method.

## Current verified fact

1. Home Proxmox admin GUI reachable at `https://192.168.1.44:8006` on 2026-09-01.
2. First pinned guest image choice for the portable VM: Debian 12 Bookworm generic cloud image (`debian-12-genericcloud-amd64.qcow2`) for the initial Proxmox bootstrap path.

## Execution evidence (2026-09-01)

1. Terraform installed successfully on Windows via winget.
2. Terraform init succeeded in `tofu/envs/lab1`.
3. Terraform validate succeeded.
4. Terraform plan with Proxmox credentials and `-refresh=false -var-file=terraform.tfvars.example` succeeded.
5. Planned actions: 3 resources to create.
6. Planned resources:
	- `module.proxmox_vm[0].proxmox_virtual_environment_download_file.reference_image`
	- `module.proxmox_vm[0].proxmox_virtual_environment_vm.reference_vm`
	- `module.k3s_bootstrap.terraform_data.bootstrap`
7. Plan output confirms selected target platform `proxmox`, reference VM `orange-lab1`, and expected IPv4 `192.168.1.210`.
8. Important pre-apply gate: `vm_ssh_public_key` is still set to the placeholder value `REPLACE_WITH_YOUR_PUBLIC_KEY` in the example var-file and must be replaced in local `terraform.tfvars` before apply.
9. Non-blocking warning: the resource `proxmox_virtual_environment_download_file` is deprecated in provider `bpg/proxmox` and should be migrated to `proxmox_download_file` in a cleanup pass.
10. OpenTofu installed successfully via winget (`OpenTofu.Tofu`), and the same environment was executed with `tofu`.
11. Lab SSH keypair generated at `C:/Users/jflorentin/.ssh/orange_lab1_ed25519` and injected into local `terraform.tfvars`.
12. OpenTofu plan with local `terraform.tfvars` succeeded (`3 to add, 0 to change, 0 to destroy`).
13. First `tofu apply tfplan` attempt failed during image download from Proxmox with HTTP 401 when fetching the cloud image URL.
14. Fallback implemented in code: support pre-existing Proxmox import image via `cloud_image_file_id` and local upload via `cloud_image_source_path` to avoid node-side external download.

## Next unblock actions

1. Create local `tofu/envs/lab1/terraform.tfvars` from the example and replace placeholder SSH key material.
2. Keep one Proxmox auth method available in shell environment variables for apply.
3. Run `terraform plan -out=tfplan -var-file=terraform.tfvars` to freeze an exact reviewed plan.
4. Apply only after verifying guest network values and SSH reachability assumptions.
5. After first apply, capture:
	- VM creation success in Proxmox
	- SSH access to `debian@192.168.1.210`
	- k3s node readiness
6. Choose one image source mode before reattempting apply:
	- Local upload mode: set `cloud_image_source_path` to the Debian Bookworm QCOW2 on this workstation and keep `cloud_image_file_name` aligned.
	- Existing file mode: set `cloud_image_file_id` (example `local:import/debian-12-genericcloud-amd64.qcow2`).

## Current image inventory and implication

1. Discovered on node `proxmox-1`: only Debian installer ISOs in `local:iso` (`debian-12.11.0-amd64-netinst.iso`, `debian-13.6.0-amd64-netinst.iso`).
2. Installer ISO is not the right source for the current cloud-init based VM creation path.
3. Needed source type for this module: cloud image in import storage (for example `local:import/debian-12-genericcloud-amd64.qcow2`).
4. Local upload is now supported directly from `C:/Projects/Orange-Lab1/artifacts/debian-12-genericcloud-amd64.qcow2`.

## Roadmap to successful tofu apply

1. Keep OpenTofu as active CLI.
2. Keep Proxmox API credentials in current shell session.
3. Ensure local `terraform.tfvars` has `vm_username = "debian"`.
4. Keep the Bookworm image source local unless you explicitly choose a Proxmox import file ID.
5. If using existing-file mode, set `cloud_image_file_id` to the real value (example `local:import/debian-12-genericcloud-amd64.qcow2`).
6. Run:
	- `tofu validate`
	- `tofu plan -refresh=false -var-file=terraform.tfvars -out=tfplan`
	- `tofu apply tfplan`
7. After apply succeeds, verify:
	- VM exists and is running.
	- SSH to `debian@192.168.1.210` works with `orange_lab1_ed25519`.
	- k3s service is active.
8. Fetch kubeconfig using output helper command and check node readiness.
