# Migration To Orange Laptop

## Objective

Switch from bootstrap-on-home to autonomous-on-Orange with minimal rework.

## Expected inputs

1. Repository clone access.
2. Approved local hypervisor if available.
3. Git, SSH, OpenTofu or Terraform, kubectl, and helm installed.
4. External secret files transferred through an approved method.

## Migration sequence

1. Clone the repository.
2. Verify tool versions.
3. Prepare the target-specific variable files.
4. Launch the local VM runtime or rebuild it from code.
5. Validate kubeconfig access.
6. Run smoke tests.
7. Continue normal work from the Orange laptop only.

## Acceptance criteria

1. No required dependency on home Proxmox.
2. Lab services reachable locally.
3. IaC plan is readable and controlled.
4. The same repository remains usable later for Orange Proxmox or OpenStack.
