# Phase 1 Completion Status

## Interpretation used for this lab

Phase 1 is the IaC foundation phase.

Under this interpretation, Phase 1 is complete only when all platform components cited by the lab are declared and deployable through OpenTofu or Terraform, even if some of them are exercised mainly in later phases.

This interpretation is stricter than a minimal infrastructure-only reading. It treats Phase 1 as the point where the full platform substrate exists in code and can be applied reproducibly.

## Scope baseline

The platform components cited by the lab are:

1. k3s
2. Keycloak
3. SPIRE
4. OpenBao or Vault
5. MinIO
6. OpenFGA

## Current status on 2026-09-02

### Deployed and validated

1. Proxmox-backed reference VM
2. Single-node k3s cluster
3. Foundation namespaces
4. Keycloak deployed through Helm and validated with a smoke gate
5. SPIRE deployed through Helm, including the required `spire-crds` release
6. OpenBao deployed through Helm in development mode
7. MinIO deployed through Helm in standalone mode
8. OpenFGA deployed through Helm with the in-memory datastore profile

## Status verdict

Phase 1 is complete under the strict IaC interpretation.

What is complete:

1. Infrastructure wrapper layer
2. Portable runtime layer
3. Full in-cluster platform substrate: Keycloak, SPIRE, OpenBao, MinIO, and OpenFGA
4. Executable verification for convergence and runtime pod health

## Recorded evidence locations

1. Phase 1 completion rationale and verdict: `docs/phase1_completion_status.md`.
2. Consolidated execution evidence and operational logs: `docs/runbooks.md`.
3. Progress timeline and closeout narrative: `orange_lab1_tracker.md`.
4. Full-platform readiness and endpoint gate: `scripts/phase1-week1.ps1`.
5. Phase 2 Week 4 entrypoint script, used only after Phase 1 gate pass: `scripts/phase2-week4.ps1`.

## Reference VM facts and access model

The Phase 1 reference runtime is one dedicated Proxmox VM, not a reused shared host.

Operational facts confirmed in code and in live use:

1. The VM address `192.168.1.210` is the dedicated IPv4 address assigned to this reference VM in the `lab1` environment.
2. The guest login user is `debian`.
3. Automation and operator access use the SSH private key `C:/Users/jflorentin/.ssh/orange_lab1_bootstrap_ed25519`.
4. The repo provisions SSH key-based access through cloud-init. No VM login password is defined anywhere in the tracked OpenTofu configuration used for this lab.
5. The VM has working non-interactive `sudo` capability, as proven by the `k3s_bootstrap` module and by the validation scripts that execute privileged commands remotely.

Static source-of-truth locations:

1. VM identity inputs and network values: `tofu/envs/lab1/terraform.tfvars`.
2. Provisioned VM shape and cloud-init user/key injection: `tofu/modules/proxmox_vm/main.tf`.
3. Bootstrap SSH and `sudo` usage: `tofu/modules/k3s_bootstrap/main.tf`.
4. Kubeconfig fetch helper derived from the active SSH settings: `tofu/modules/k3s_bootstrap/outputs.tf`.
5. Phase 1 validation entrypoint: `scripts/phase1-week1.ps1`.
6. Phase 2 Week 4 validation entrypoint: `scripts/phase2-week4.ps1`.

Snapshot recommendation:

1. Yes, it is sensible to create a Proxmox snapshot now that Phase 1 is validated and Week 4 is passing.
2. Prefer a snapshot of the current VM state over a separate ad hoc manual image at this stage, because it preserves the exact in-place cluster and service state used by the validation scripts.
3. Do not treat the snapshot as the primary source of truth. The authoritative rebuild path remains the OpenTofu code plus the documented variable values and operator commands.

## Phase transition evidence

1. `scripts/phase1-week1.ps1` passed with platform-wide readiness for Keycloak, SPIRE, OpenBao, MinIO, and OpenFGA.
2. `scripts/phase2-week4.ps1` executed successfully after the PowerShell subject interpolation fix.
3. Week 4 startup checks now validate:
	- cluster OIDC discovery reachability,
	- JWKS reachability,
	- projected ServiceAccount token claim integrity,
	- Keycloak admin automation path through `kcadm.sh` with writable temporary config.

## Smoke gate demonstration command and raw output

Command used:

```powershell
Set-Location -LiteralPath 'C:\Projects\Orange-Lab1'; .\scripts\phase1-week1.ps1
```

Raw output:

```text
Smoke test gate started
1) Node inventory and readiness
NAME          STATUS   ROLES           AGE   VERSION        INTERNAL-IP     EXTERNAL-IP   OS-IMAGE                         KERNEL-VERSION                 CONTAINER-RUNTIME
orange-lab1   Ready    control-plane   11h   v1.36.4+k3s1   192.168.1.210   <none>        Debian GNU/Linux 12 (bookworm)   6.1.0-52-cloud-amd64 (amd64)   containerd://2.3.4-k3s1.36
2) Cluster pod overview
NAMESPACE       NAME                                                   READY   STATUS      RESTARTS      AGE
authorization   openfga-87b5b7bcc-tvhfc                                1/1     Running     0             18m
identity        keycloak-0                                             1/1     Running     0             9h
identity        keycloak-postgresql-0                                  1/1     Running     0             9h
identity        spire-agent-xrhst                                      1/1     Running     0             14m
identity        spire-server-0                                         2/2     Running     0             14m
identity        spire-spiffe-csi-driver-qhhpc                          2/2     Running     0             14m
identity        spire-spiffe-oidc-discovery-provider-ddd748766-wqktn   2/2     Running     0             14m
kube-system     coredns-54996dc9b4-79nd9                               1/1     Running     0             11h
kube-system     helm-install-traefik-47xbt                             0/1     Completed   1 (11h ago)   11h
kube-system     helm-install-traefik-crd-z224p                         0/1     Completed   0             11h
kube-system     local-path-provisioner-77b9867795-pcrzw                1/1     Running     0             11h
kube-system     metrics-server-6dc596dfb8-vs6xf                        1/1     Running     0             11h
kube-system     svclb-traefik-cce0b4d5-ljmlm                           2/2     Running     0             11h
kube-system     traefik-59b7647586-8zwm4                               1/1     Running     0             11h
secrets         openbao-0                                              1/1     Running     0             18m
storage         minio-8fdd4d44f-mdjr8                                  1/1     Running     0             18m
3) Waiting for platform workloads to become Ready
Waiting for Keycloak pods to become Ready
pod/keycloak-0 condition met
pod/keycloak-postgresql-0 condition met
Waiting for SPIRE pods to become Ready
pod/spire-agent-xrhst condition met
pod/spire-server-0 condition met
pod/spire-spiffe-csi-driver-qhhpc condition met
pod/spire-spiffe-oidc-discovery-provider-ddd748766-wqktn condition met
Waiting for OpenBao pods to become Ready
pod/openbao-0 condition met
Waiting for MinIO pods to become Ready
pod/minio-8fdd4d44f-mdjr8 condition met
Waiting for OpenFGA pods to become Ready
pod/openfga-87b5b7bcc-tvhfc condition met
4) Verifying service endpoint population
Warning: v1 Endpoints is deprecated in v1.33+; use discovery.k8s.io/v1 EndpointSlice
Keycloak endpoint: 10.42.0.13
Warning: v1 Endpoints is deprecated in v1.33+; use discovery.k8s.io/v1 EndpointSlice
SPIRE server endpoint: 10.42.0.24
Warning: v1 Endpoints is deprecated in v1.33+; use discovery.k8s.io/v1 EndpointSlice
OpenBao endpoint: 10.42.0.16
Warning: v1 Endpoints is deprecated in v1.33+; use discovery.k8s.io/v1 EndpointSlice
MinIO endpoint: 10.42.0.20
Warning: v1 Endpoints is deprecated in v1.33+; use discovery.k8s.io/v1 EndpointSlice
OpenFGA endpoint: 10.42.0.17
5) Keycloak OIDC health check through the API server proxy
Smoke test gate passed
```

## Week 4 entrypoint demonstration command and raw output

Command used:

```powershell
Set-Location -LiteralPath 'C:\Projects\Orange-Lab1'; .\scripts\phase2-week4.ps1
```

Raw output:

```text
Phase 2 Week 4 validation started
1) Cluster OIDC discovery document
{"issuer":"https://kubernetes.default.svc.cluster.local","jwks_uri":"https://192.168.1.210:6443/openid/v1/jwks","response_types_supported":["id_token"],"subject_types_supported":["public"],"id_token_signing_alg_values_supported":["RS256"]}
2) Cluster JWKS document
{"keys":[{"use":"sig","kty":"RSA","kid":"WnIHKRUdrHykaIfLLJgiuoMXzqTtUObEFwKh71GBRmU","alg":"RS256","n":"pPTaApjddVfRFvAJkkaDUbf26Hl9unObufSmcKCU63kzdU2YCa-lUbLl7OM9yqku-hPLv828MdFcw5AtGoqr76UnGUvpHmlOUNzFad1ZUh9er6K_n4-AArAVLPzJCWrQU_K8xfv8dzGCuOhh06OCfzN2FGucwC9Wz4n3IqhqD1sjcz2jXxPe8Lcw2pKt-bTbqZ69gJ-pUU3SWfkTYf4Shys9ObhOIA1idAxTTtoDrdu1v2VIkH4P-VFcm20_431-5UnbH_iXIqulDQI1NvYCf5xAbo5iJIfPFE8bqfG0KVBNoi0yqHF8qGEtOsidFgel6G89GJ-epIp7lG_WBHHX9w","e":"AQAB"}]}
3) Applying the projected-token demo workload
serviceaccount/workload-identity-demo created
deployment.apps/workload-identity-demo created
Waiting for deployment "workload-identity-demo" rollout to finish: 0 out of 1 new replicas have been updated...
Waiting for deployment "workload-identity-demo" rollout to finish: 0 of 1 updated replicas are available...
deployment "workload-identity-demo" successfully rolled out
4) Reading the projected token from the demo workload
Projected token issuer: https://kubernetes.default.svc.cluster.local
Projected token subject: system:serviceaccount:identity:workload-identity-demo
Projected token audience: workload-identity-demo
Projected token exp: 1788345643
5) Validating Keycloak admin automation path
Defaulted container "keycloak" out of: keycloak, prepare-write-dirs (init)
Logging into http://127.0.0.1:8080 as user admin of realm master
Week 4 execution slice completed
```

## Recommended completion order

1. SPIRE
Reason: it is the core workload-identity substrate for Phase 2.

2. OpenBao
Reason: it is the first concrete consumer of workload identity for dynamic secrets.

3. MinIO
Reason: it completes the federated temporary-credential path for the zero-secret demonstration.

4. OpenFGA
Reason: it belongs to the final platform shape, but its main demonstrations are in Phase 3.

## Completion gate for Phase 1

Treat Phase 1 as complete only when all of the following are true:

1. `tofu plan` returns no drift after deploying all cited components.
2. `tofu state list` contains the platform modules for Keycloak, SPIRE, OpenBao, MinIO, and OpenFGA.
3. A smoke check confirms pod health for each deployed platform component.
4. The stack is rebuildable from a clean checkout with target-specific variables only.

All four gates are now satisfied in the `lab1` environment on 2026-09-02.