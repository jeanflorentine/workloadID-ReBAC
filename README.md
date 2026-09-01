# Orange Lab 1

Portable-first integration lab for Terraform or OpenTofu, workload identity, and ReBAC.

## Objective

Build one reproducible lab stack that can:

1. Start immediately on home Proxmox.
2. Run autonomously on the Orange laptop after delivery.
3. Be redeployed later on Orange Proxmox or OpenStack.

## Operating model

1. The durable asset is the code and the portable runtime definition.
2. Home Proxmox is a bootstrap accelerator only.
3. The Orange laptop is the primary autonomous execution target.
4. Orange-hosted virtualization is the secondary enterprise target.

## Repository layout

- `docs/`: operational and architecture documentation
- `tofu/`: infrastructure and service IaC scaffold
- `kubernetes/`: target-agnostic manifests and overlays
- `scripts/`: workstation bootstrap and smoke checks

## Immediate path

1. Review the target split in `docs/portability_strategy.md`.
2. Review local hypervisor decision criteria in `docs/local_hypervisor_decision.md`.
3. Populate environment values under `tofu/envs/lab1/`.
4. Implement and test the first VM wrapper and `k3s_bootstrap` path.
