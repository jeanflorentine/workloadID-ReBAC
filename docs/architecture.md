# Architecture

## Goal

Provide one lab architecture that survives a host change without redesign.

## Reference model

1. Infrastructure wrapper layer
Purpose: create or prepare the target runtime container for the lab.
Targets: home Proxmox, Orange laptop hypervisor, Orange Proxmox, Orange OpenStack.

2. Portable runtime layer
Purpose: a single-node VM running k3s as the stable execution base.

3. In-cluster services layer
Purpose: run Keycloak, SPIRE, OpenBao or Vault, MinIO, and OpenFGA through reusable IaC.

## Design rule

Only the infrastructure wrapper changes per target. The VM contents and the in-cluster service layer should remain as stable as possible.

## First shape

1. One single-node k3s VM.
2. Lightweight ingress exposure for lab endpoints.
3. Pinned service versions.
4. Externalized secrets and per-target variables.
