# Runbooks

## Phase-specific references

1. Phase 1 scope and completion status: `docs/phase1_completion_status.md`
2. Phase 2 workload identity validation plan: `docs/phase2_workload_identity_validation.md`
3. Phase 2 current completion status and execution evidence: `docs/phase2_completion_status.md`

## Phase 1 bootstrap evidence to capture

1. Target selected: home Proxmox, Orange laptop, or Orange enterprise virtualization.
2. Tool versions used.
3. Guest OS image used for the reference VM.
4. k3s installation result.
5. kubeconfig validation result.
6. Health status for Keycloak, SPIRE, OpenBao, MinIO, and OpenFGA.
7. Redeploy or rebuild result with no manual drift correction.

## Execution evidence (2026-09-02)

1. `tofu apply -auto-approve -lock=false -input=false -no-color` deployed OpenBao, OpenFGA, MinIO, `spire-crds`, and SPIRE.
2. SPIRE required a separate `spire-crds` release before the main `spire` chart, and the module was updated accordingly.
3. MinIO required disabling the optional console subcomponent because the default Bitnami `minio-object-browser` image tag was not pullable.
4. Final `tofu plan -lock=false -input=false -no-color` returned no drift.
5. Final `tofu state list` includes Helm releases for Keycloak, SPIRE, OpenBao, MinIO, and OpenFGA.
6. Final `kubectl get pods -A -o wide` shows the Phase 1 platform pods in `Running` state.
7. The widened `scripts/phase1-week1.ps1` now validates Keycloak, SPIRE, OpenBao, MinIO, and OpenFGA readiness plus service endpoints.
8. `scripts/phase2-week4.ps1` successfully verified cluster OIDC discovery, JWKS reachability, projected ServiceAccount token claims, and Keycloak admin automation.
9. `scripts/tofu-remote.ps1 -Action plan -ProxmoxUsername root@pam` returned `No changes` using forwarded local PowerShell credentials.
10. `scripts/tofu-remote.ps1 -Action apply -ProxmoxUsername root@pam` returned `Apply complete! Resources: 0 added, 0 changed, 0 destroyed.`
11. `scripts/tofu-remote.ps1 -Action apply -ProxmoxUsername root@pam -AutoApprove` returned the same no-drift result.
12. Verified outputs from the remote helper path include:
	- `k3s_bootstrap_status = "bootstrap-defined"`
	- `proxmox_import_source_id = "local:import/debian-12-genericcloud-amd64.qcow2"`
	- `reference_vm_ipv4 = "192.168.1.210"`
	- `reference_vm_name = "orange-lab1"`
	- `selected_target_platform = "proxmox"`
13. `scripts/phase2-week5.ps1` passed with explicit markers showing the authorized SPIFFE identity entry is present and the denied identity entry is absent.
14. `scripts/phase2-week6.ps1` passed with OpenBao dynamic-secret positive and negative checks, plus MinIO short-lived credential positive and negative checks.
15. `scripts/phase2-end2end-zero-secret.ps1` passed the full chain: SPIRE identity check, static-credential absence check, OpenBao secret retrieval, MinIO temporary credential use, and revocation-failure gate.

## Week 6 transposition note to hyperscaler names

1. OpenBao or Vault dynamic secret with Kubernetes auth maps to:
	- AWS IAM role plus Secrets Manager
	- Azure Managed Identity plus Key Vault
	- Google Workload Identity plus Secret Manager
2. MinIO temporary credentials map to cloud-native short-lived object-storage credentials:
	- AWS STS for S3
	- Azure user delegation SAS for Blob
	- Google short-lived access tokens for Cloud Storage

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
11. Lab SSH keypair generated at `C:/Users/jflorentin/.ssh/orange_lab1_bootstrap_ed25519` and injected into local `terraform.tfvars`.
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
	- SSH to `debian@192.168.1.210` works with `orange_lab1_bootstrap_ed25519`.
	- k3s service is active.

## Static configuration retrieval map

Use these files as the stable lookup points for the lab's static or slow-changing operator configuration:

1. `tofu/envs/lab1/terraform.tfvars`: target host IP, SSH user, SSH key path, guest sizing, and core environment values.
2. `tofu/modules/proxmox_vm/main.tf`: Proxmox VM creation, cloud-init networking, and SSH key injection.
3. `tofu/modules/k3s_bootstrap/main.tf`: bootstrap commands, remote SSH connection settings, and verified `sudo` usage.
4. `tofu/modules/k3s_bootstrap/outputs.tf`: helper command to fetch kubeconfig from the VM.
5. `docs/phase1_completion_status.md`: current validated VM facts and access model.
6. `docs/phase2_completion_status.md`: current validated Keycloak and workload-identity behavior.
8. Fetch kubeconfig using output helper command and check node readiness.

## Smart App Control-safe IaC workflow (Windows host blocked)

Use this path when Windows blocks local `tofu` execution.

1. Keep Smart App Control enabled on the workstation.
2. Run OpenTofu from the Debian lab VM over SSH.
3. Keep local Windows usage limited to editing and copying files.

### One-time VM bootstrap for OpenTofu

Run from Windows PowerShell:

```powershell
ssh -i C:/Users/jflorentin/.ssh/orange_lab1_bootstrap_ed25519 debian@192.168.1.210 "sudo apt-get update && sudo apt-get install -y git gpg lsb-release ca-certificates"
ssh -i C:/Users/jflorentin/.ssh/orange_lab1_bootstrap_ed25519 debian@192.168.1.210 "sudo install -m 0755 -d /etc/apt/keyrings && curl -fsSL https://packages.opentofu.org/opentofu/tofu/gpgkey | sudo gpg --dearmor -o /etc/apt/keyrings/opentofu.gpg && sudo chmod a+r /etc/apt/keyrings/opentofu.gpg && echo 'deb [signed-by=/etc/apt/keyrings/opentofu.gpg] https://packages.opentofu.org/opentofu/tofu/any/ any main' | sudo tee /etc/apt/sources.list.d/opentofu.list >/dev/null && sudo apt-get update && sudo apt-get install -y tofu && tofu version"
```

Current verified result on 2026-09-02:

1. Debian VM has OpenTofu installed (`OpenTofu v1.12.6`).
2. SSH key-based access and non-interactive `sudo` are working.

### Copy IaC folder to the VM

```powershell
scp -r -i C:/Users/jflorentin/.ssh/orange_lab1_bootstrap_ed25519 C:/Projects/Orange-Lab1/tofu debian@192.168.1.210:~/Orange-Lab1
```

Note: this command copies local providers and state artifacts as-is. For clean validation on Linux, remove `.terraform` in the remote env before running `tofu init`.

### Remote validate (proven)

```powershell
ssh -i C:/Users/jflorentin/.ssh/orange_lab1_bootstrap_ed25519 debian@192.168.1.210 "cd ~/Orange-Lab1/envs/lab1 && rm -rf .terraform && tofu init -backend=false -input=false -no-color && tofu validate -no-color"
```

Current verified result on 2026-09-02:

1. `tofu init -backend=false` succeeded.
2. `tofu validate -no-color` succeeded.
3. Existing warning remains: `proxmox_virtual_environment_download_file` is deprecated and should be migrated to `proxmox_download_file` in a cleanup pass.

### Remote plan with Linux-safe kubeconfig override

The current `terraform.tfvars` uses a Windows kubeconfig path. Override it at runtime when planning from Linux:

```powershell
ssh -i C:/Users/jflorentin/.ssh/orange_lab1_bootstrap_ed25519 debian@192.168.1.210 "cd ~/Orange-Lab1/envs/lab1 && tofu plan -refresh=false -input=false -no-color -var-file=terraform.tfvars -var 'kubeconfig_path=/home/debian/Orange-Lab1/envs/lab1/orange-lab1.yaml'"
```

If Proxmox credentials are not already configured in the remote shell, set them before running plan (username/password or API token, depending on your provider auth mode).

Credential examples on the Debian VM:

```bash
export PROXMOX_VE_USERNAME='root@pam'
export PROXMOX_VE_PASSWORD='REPLACE_WITH_PASSWORD'
```

or

```bash
export PROXMOX_VE_API_TOKEN='REPLACE_WITH_TOKEN'
```

How to create and capture `PROXMOX_VE_API_TOKEN` in Proxmox:

1. Open Proxmox Web UI as an administrator.
2. Navigate to Datacenter -> Permissions -> API Tokens.
3. Click Add and set:
	- User: `root@pam`
	- Token ID: for example `orange-lab1`
	- Privilege Separation: Off (inherits user privileges) unless you intentionally manage token-specific ACLs.
4. Confirm creation and copy the token secret immediately (it is shown only once).
5. Build the environment value using the canonical format:
	- `root@pam!orange-lab1=<token-secret>`
6. In the same local PowerShell session used for `scripts/tofu-remote.ps1`, set:
	- `$env:PROXMOX_VE_API_TOKEN = 'root@pam!orange-lab1=<token-secret>'`

If the secret is lost, create a new token because Proxmox does not reveal the previous secret again.

Then rerun `tofu plan`.

Default lab assumption: if Proxmox has only the root account configured, use `root@pam` as `PROXMOX_VE_USERNAME`.

Credential safety note:

1. Keep `PROXMOX_VE_USERNAME` non-secret (`root@pam`) and pass it at runtime.
2. Set `PROXMOX_VE_PASSWORD` or `PROXMOX_VE_API_TOKEN` in the same local PowerShell session where you run `scripts/tofu-remote.ps1`; the helper forwards them on each SSH invocation.
3. Remote exports in a separate interactive Debian shell are isolated and are not inherited by later non-interactive helper calls.
4. Do not commit secrets into `terraform.tfvars`, scripts, or repo files.

### Helper script on Windows

Use `scripts/tofu-remote.ps1` to run the same flow without rewriting commands.

```powershell
Set-Location -LiteralPath C:/Projects/Orange-Lab1
./scripts/tofu-remote.ps1 -Action bootstrap
./scripts/tofu-remote.ps1 -Action sync
./scripts/tofu-remote.ps1 -Action validate
./scripts/tofu-remote.ps1 -Action plan
./scripts/tofu-remote.ps1 -Action apply
./scripts/tofu-remote.ps1 -Action apply -AutoApprove
```

Optional explicit username:

```powershell
./scripts/tofu-remote.ps1 -Action plan -ProxmoxUsername root@pam
./scripts/tofu-remote.ps1 -Action apply -ProxmoxUsername root@pam
```

Current verified behavior on 2026-09-02:

1. `-Action validate` succeeds from Windows by executing OpenTofu on Debian over SSH.
2. `-Action plan` now fails only when Proxmox credentials are missing from the remote shell.

### Optional local fallback (only if allowed by policy)

If Smart App Control allows Terraform on Windows, you can use Terraform locally for `validate` and `plan` only, while keeping actual `apply` on the Debian VM.

Observed on this host (2026-09-02):

1. `terraform.exe` is executable from `C:/Users/jflorentin/AppData/Local/Microsoft/WinGet/Packages/Hashicorp.Terraform_Microsoft.Winget.Source_8wekyb3d8bbwe/terraform.exe`.
2. A local `terraform plan` still failed because Application Control blocked at least one provider executable under `.terraform/providers/...`.
3. Practical conclusion: keep VM-based OpenTofu as the primary path until local provider binaries are allowed by policy.
