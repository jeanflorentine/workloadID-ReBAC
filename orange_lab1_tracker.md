# Orange Lab 1 Tracker

Single source of truth for planning, deployment strategy, and execution tracking for the Orange integration lab.

- Project: Orange integration lab, from PKI to ReBAC
- Priority: High, ahead of the previous Keycloak book lab
- Workspace: C:\Projects\Orange-Lab1
- Related reference: C:\Projects\KeyCloack-Lab\KeyCloack_Lab_Book_tracker.md
- Last updated: 2026-09-01

---

## 1. Context and constraints

1. The Orange laptop is not available yet and will be received on Thursday afternoon.
2. A working Proxmox infrastructure is already available and was used successfully in the previous lab.
3. The new Orange lab explicitly targets internal, sovereign, open-source deployment (no cloud account required).
4. The lab stack is long-lived across 10 weeks, so early choices must optimize continuity and reproducibility.
5. Once the Orange laptop is received, the lab must be runnable without any dependency on home infrastructure.
6. The lab should remain deployable in three contexts: temporary home Proxmox bootstrap, autonomous execution on the Orange laptop, and later hosting on Orange Proxmox or OpenStack if available.
7. Home Proxmox remains usable right now as a bootstrap platform, and the Proxmox admin GUI is reachable at `https://192.168.1.44:8006`.
8. Orange laptop policy regarding local VM runtime versus WSL 2 is still pending confirmation from Orange.

---

## 2. Assessment summary and comparison with previous lab

### 2.1 What the Orange lab asks for

1. Build one reusable internal lab stack across all phases.
2. Start with IaC (OpenTofu or Terraform), then workload identity, then ReBAC.
3. Run everything on internal means: workstation or internal VM, with Proxmox or OpenStack as valid hosting options.

### 2.2 What already worked in the previous Keycloak lab

1. Remote-first runtime on homelab infrastructure was successful.
2. Local machine acted as control node for authoring and operations.
3. Reproducible, version-pinned, incremental steps gave stable progress.
4. Persistent infrastructure avoided rework when changing workstation context.

### 2.3 Gap analysis

1. The Orange lab has broader scope than the previous Keycloak-first runtime.
2. The previous remote-first pattern is useful only as a bootstrap aid, not as the long-term operating model for this lab.
3. The key upgrade is to make IaC and image portability the primary source of continuity from day one.
4. The deployment unit must be movable across hypervisors and usable from disconnected or restricted-network situations.

---

## 3. Recommended deployment architecture (response output)

Revised recommendation: start today on home Proxmox only as a temporary bootstrap host, but design the lab as a portable single-node platform that can be copied onto the Orange laptop and later redeployed on Orange Proxmox or OpenStack. This is the best fit for the timing constraint and for mobility after Friday.

### 3.1 Best-fit architecture

1. Runtime model: one portable single-node lab VM image as the reference runtime.
2. Initial host: home Proxmox this week, only to begin work before the Orange laptop arrives.
3. Primary target after Friday: the Orange laptop must be able to run the lab autonomously, even with no connectivity to home.
4. Secondary target after Friday: the same artefacts should deploy on Orange Proxmox or OpenStack if internal infrastructure becomes available.
5. Orchestration baseline: OpenTofu or Terraform as source of truth from day one, with host-specific variables isolated from workload definitions.
6. Kubernetes choice: single-node k3s inside the portable VM, because it is lighter and easier to move than a multi-node cluster while still matching the lab requirements.
7. Services on cluster: Keycloak, SPIRE, OpenBao or Vault, MinIO, OpenFGA (Helm or Kubernetes manifests managed by IaC).
8. Portability strategy: separate the lab into two layers: image or VM provisioning layer and in-cluster service layer.
9. State strategy: keep workload definitions in git, keep secrets external, and avoid any dependency on a state backend reachable only from home.

### 3.2 Why this is better than alternatives

1. Better than pure remote-first on home Proxmox: it removes the risk of being blocked in Orange offices or customer sites with no route back home.
2. Better than local-only install on the personal laptop: it still allows immediate progress today while avoiding a throwaway setup.
3. Better than waiting until Thursday: allows immediate start on Phase 1 foundations.
4. Better than kind-on-laptop as the main platform: a portable VM with k3s behaves more like a stable internal lab and migrates more cleanly between laptop and enterprise virtualization.

### 3.3 Immediate execution plan

1. Today: bootstrap IaC layout, create the reference VM definition, install k3s, and keep all host-specific parameters externalized.
2. Tomorrow: add Kubernetes and Helm managed components, validate redeployability inside the VM, and document the copy path.
3. Thursday and Friday: copy the VM artefact or rebuild it from the same code on the Orange laptop, then continue autonomously.
4. Later: reuse the same workload layer on Orange Proxmox or OpenStack with a thin target-specific infrastructure wrapper.

### 3.4 Consequence for the design

1. Home Proxmox is a bootstrap accelerator, not a required dependency.
2. The real product is not only the cluster state; it is the reproducible portable lab package plus its IaC source.
3. Every decision from now on should be checked against one criterion: can this still work when you are away from home and operating only from the Orange laptop?
4. Until Orange confirms the laptop policy, keep two tracks active in parallel: preferred VM runtime path and secondary WSL tooling path.

---

## 4. Starter blueprint (concrete implementation)

## 4.1 Architecture principles

1. Make the lab portable first, then optimize where it runs.
2. Treat home Proxmox as a temporary build or test host, not as the permanent runtime anchor.
3. Keep all topology and config in code.
4. Isolate target-specific infrastructure code from target-agnostic Kubernetes service definitions.
5. Keep secrets out of git and rotate bootstrap secrets early.
6. Validate each layer independently before stacking the next one.

## 4.2 Target topology

1. One reference single-node lab VM running k3s.
2. That VM must be exportable or reproducible for three targets: home Proxmox, Orange laptop hypervisor, Orange Proxmox or OpenStack.
3. One private network segment for lab services inside the VM runtime.
4. One ingress endpoint for Keycloak and API entry points.
5. Optional second VM later only if a phase explicitly needs node separation, trust-domain federation, or failure drills.
6. While Orange policy is pending, the architecture remains intentionally dual-track: VM runtime preferred, WSL tooling supported.

## 4.3 Repository layout blueprint

Use this structure inside C:\Projects\Orange-Lab1.

```text
Orange-Lab1/
  orange_lab1_tracker.md
  README.md
  .gitignore
  docs/
    architecture.md
    runbooks.md
    migration_to_orange_laptop.md
    portability_strategy.md
  tofu/
    envs/
      lab1/
        backend.hcl.example
        terraform.tfvars.example
        versions.tf
        providers.tf
        main.tf
        outputs.tf
    modules/
      proxmox_vm/
      openstack_vm/
      local_hypervisor_vm/
      k3s_bootstrap/
      kube_namespaces/
      helm_keycloak/
      helm_spire/
      helm_openbao/
      helm_minio/
      helm_openfga/
  kubernetes/
    base/
    overlays/
      lab1/
  scripts/
    check-prereqs.ps1
    bootstrap-workstation.ps1
    smoke-test.ps1
```

## 4.4 Version and pinning policy

1. Pin OpenTofu or Terraform major and minor version.
2. Pin all providers (proxmox, openstack if used, kubernetes, helm, keycloak if used).
3. Pin Helm chart versions for all platform services.
4. Pin container image tags, never use latest.
5. Record all pinned versions in docs/runbooks.md.
6. Pin the guest OS image source used to build the reference VM.

## 4.5 Minimal provider and module sequence

1. Module A: proxmox_vm
Purpose: create or reuse VM with fixed CPU, RAM, disk, network, SSH access.

2. Module B: local_hypervisor_vm
Purpose: define the same reference VM for Orange laptop local execution if a local hypervisor is available.

3. Module C: openstack_vm
Purpose: provide a thin alternative wrapper if Orange offers OpenStack later.

4. Module D: k3s_bootstrap
Purpose: install and configure single-node k3s, export kubeconfig.

5. Module E: kube_namespaces
Purpose: create dedicated namespaces and baseline policies.

6. Module F to J: helm_keycloak, helm_spire, helm_openbao, helm_minio, helm_openfga
Purpose: install core services with pinned chart versions.

7. Optional module K: keycloak_seed
Purpose: bootstrap realm, clients, roles once Keycloak is reachable.

The critical split is this:

1. Infrastructure wrapper modules are target-specific.
2. k3s and all in-cluster services are target-agnostic and must remain reusable without modification.

## 4.6 Environment model

1. Single initial environment: lab1.
2. Keep one variables file per environment.
3. Keep one backend config per environment.
4. Keep secrets in external files excluded from git.

## 4.7 State and secrets strategy

1. Do not place critical state in a location reachable only from home.
2. Keep infrastructure-wrapper state separated per target.
3. If starting with local backend, place state in a controlled location that can be copied to the Orange laptop or migrated cleanly.
4. Never commit secret values.
5. Use example files for non-secret defaults and naming conventions.
6. Prefer regeneration of target-specific infrastructure over fragile state transplant when moving between hypervisors.

## 4.8 Day-by-day startup plan

### Day 0 (today)

1. Create repository structure and baseline documentation.
2. Define pinned versions and provider list.
3. Implement the reference VM definition and the proxmox_vm wrapper.
4. Implement k3s_bootstrap so it is not tied to Proxmox assumptions.
5. Run first apply to get a reachable k3s node.
6. Run smoke checks: VM reachability, kubectl connectivity, node ready.

### Day 1 (tomorrow)

1. Add kube_namespaces and first Helm modules.
2. Deploy Keycloak and one supporting service first, then SPIRE, OpenBao, MinIO, OpenFGA.
3. Validate each deployment with explicit health checks.
4. Validate that the VM definition and workload layer can be rebuilt without manual edits.
5. Run one full plan then one no-op plan to confirm idempotency.

### Day 2 (Thursday before laptop handover)

1. Freeze and document exact state and outputs.
2. Export either the reference VM artefact or the exact rebuild procedure.
3. Export runbook: clone, configure, launch, verify.
4. Confirm that all operations can be run from a clean workstation profile.

### Day 3 (Friday on Orange laptop)

1. Install minimal tooling only: git, ssh, OpenTofu or Terraform, kubectl, helm.
2. Install or use the locally approved hypervisor if available at Orange.
3. Clone repository and apply workstation bootstrap script.
4. Launch the local reference VM or rebuild it from the same code.
5. Run read-only checks first, then plan.
6. Continue normal implementation autonomously, with no dependency on home Proxmox.

## 4.9 Friday migration checklist

1. Repository cloned successfully.
2. Correct tool versions installed and verified.
3. Local execution path validated on the Orange laptop.
4. Kubernetes context points to the local or Orange-hosted k3s cluster.
5. Target-specific state is reachable or recreated cleanly.
6. Plan output matches expected drift status.
7. Smoke tests pass from Orange laptop without home-network dependency.

## 4.10 Target strategy matrix

1. Home Proxmox
Use: immediate bootstrap before Thursday.
Role: temporary host.
Expectation: helps start early, but must not be required later.

2. Orange laptop
Use: primary autonomous runtime when travelling, at the office, or at customer sites.
Role: main portable execution environment.
Expectation: must be able to run the full lab locally.

3. Orange Proxmox or OpenStack
Use: secondary enterprise-hosted runtime when internal infrastructure is available.
Role: larger or more durable target for demos and team sharing.
Expectation: reuse same workload layer with thin infrastructure adaptation.

4. WSL 2 tooling path
Use: parallel Linux tooling path while the Orange laptop runtime decision is pending.
Role: operator environment, not the preferred primary runtime.
Expectation: remains useful whether the final runtime is a laptop VM or Orange-hosted virtualization.

## 4.11 Risks and mitigations

1. Risk: hidden dependency on home network or home hypervisor.
Mitigation: enforce at least one full local-only execution path on the Orange laptop.

2. Risk: Orange laptop policy blocks the preferred local VM runtime.
Mitigation: keep the WSL tooling path ready in parallel and request policy clarification immediately.

3. Risk: state split between machines.
Mitigation: separate state by target and prefer reproducible rebuild over manual state moves.

4. Risk: secret leakage in repository.
Mitigation: gitignore hardening, example files only, early secret rotation.

5. Risk: chart or provider drift.
Mitigation: pin versions and enforce no floating tags.

6. Risk: laptop resource limits.
Mitigation: keep the first lab shape single-node, minimal, and modular; defer heavier HA or multi-node patterns until Orange-hosted infrastructure is available.

---

## 5. First deliverable definition

By end of initial setup window (before or on Friday), success means:

1. A portable single-node k3s lab runtime is operational.
2. IaC project structure is ready and runnable.
3. At least Keycloak and one additional core component are deployed via IaC.
4. Orange laptop can run the lab autonomously or rebuild it locally from the same code.
5. The same workload layer is reusable later on Orange Proxmox or OpenStack.

---

## 6. Next concrete actions

1. Populate the first real target values for home Proxmox in the lab1 environment.
2. Turn proxmox_vm from scaffold into the first working VM provisioning module.
3. Turn k3s_bootstrap from scaffold into the first working runtime bootstrap module.
4. Decide the first guest OS image and pin it in the runbook.
5. Execute the first VM plus k3s smoke path and capture evidence in docs/runbooks.md.
6. Send the runtime decision request to Orange using docs/orange_vm_runtime_request_email.md.
7. Keep Proxmox runtime path and WSL tooling path progressing in parallel until Orange answers.
8. As soon as the Orange laptop arrives, verify Hyper-V availability before choosing any alternative local hypervisor.

Execution status update:
1. Preference-order alignment is done across docs (WSL 2 second, VirtualBox third).
2. Parallel runbooks are now command-level and ready:
  - Proxmox runtime path in docs/proxmox_runtime_path.md.
  - WSL tooling path in docs/wsl_tooling_path.md.
3. VM path progress: Terraform installed, init and validate succeeded, plan reached the expected Proxmox credential gate.
4. WSL path progress: documented and generated, implementation intentionally deferred for now.
5. VM path gate passed: plan now succeeds with credentials (`3 to add, 0 to change, 0 to destroy`).
6. Remaining pre-apply gate: replace placeholder SSH public key in local var-file and save a plan with `-out`.
7. OpenTofu is now installed and validated as the active IaC CLI path for this lab.
8. Dedicated lab SSH keypair created and wired into local `terraform.tfvars`.
9. Apply attempt reached provisioning stage but failed on Proxmox-side external image fetch (HTTP 401), so image-source fallback support was added.
10. Current decision gate: choose between URL-based image fetch and pre-existing `cloud_image_file_id` mode.

Operational slice 3 clarification:
1. Slice 3 means comparing command outputs and behavior between PowerShell-native and WSL-based executions.
2. Because WSL implementation is deferred, slice 3 is also deferred.
3. When WSL is activated later, we will run the same `init/validate/plan` sequence in WSL and record the output comparison in docs/runbooks.md.

## 7. Decision support documents

1. Runtime decision request email: docs/orange_vm_runtime_request_email.md.
2. Preferred VM path: docs/proxmox_runtime_path.md.
3. Secondary WSL tooling path: docs/wsl_tooling_path.md.
4. Hypervisor and WSL decision note: docs/local_hypervisor_decision.md.

## 8. Scaffold status on 2026-09-01

Completed in this workspace:

1. README.md created with the portable-first operating model.
2. .gitignore created for IaC state, secrets, and local artifacts.
3. Operational documentation created: architecture, portability strategy, migration path, runbooks, and local hypervisor decision note.
4. Environment scaffold created under tofu/envs/lab1.
5. First module skeletons created for Proxmox, local hypervisor, OpenStack, k3s bootstrap, and Kubernetes namespaces.
6. Placeholder service module directories created for Keycloak, SPIRE, OpenBao, MinIO, and OpenFGA.
7. Workstation helper scripts created and the prerequisite check executed successfully.
8. Decision-request email, Proxmox runtime path, and WSL tooling path documents created.
9. Command-level sequences added to Proxmox runtime and WSL tooling paths.
10. Local hypervisor decision wording aligned with current order: Hyper-V, WSL 2, VirtualBox.

---

## Annexe: agent self-reference

- Purpose: deployment strategy and execution tracker for Orange Lab 1.
- Scope: architecture choice, implementation blueprint, migration readiness.
- Inputs considered: Orange lab specialization document and previous Keycloak lab tracker.
- Core decision: portable-first single-node lab, with home Proxmox only as temporary bootstrap host.
- Constraint handled: Orange laptop unavailable until Thursday afternoon.
- Constraint added: the lab must remain usable from Orange offices and customer sites without access to home infrastructure.
- Verified bootstrap fact: home Proxmox admin GUI reachable at `https://192.168.1.44:8006` on 2026-09-01.
- Output objective: start implementation immediately and keep the lab movable across laptop and Orange-hosted virtualization.
- Last updated: 2026-09-01.
