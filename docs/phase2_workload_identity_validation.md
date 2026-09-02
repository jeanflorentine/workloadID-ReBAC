# Phase 2 Workload Identity Validation

## Purpose

This document turns Phase 2 into an executable validation plan.

The goal is not only to deploy SPIRE, OpenBao, MinIO, and supporting Keycloak configuration, but to demonstrate concrete workload-identity behaviors with explicit success criteria and repeatable acceptance commands.

Current execution status and latest validated outcomes are tracked separately in `docs/phase2_completion_status.md`.

## Workflow schemas used by this validation plan

1. Week 4 script workflow: `docs/diagrams/phase2-week4-workflow.mmd`.
2. Week 5 script workflow: `docs/diagrams/phase2-week5-workflow.mmd`.
3. Week 6 script workflow: `docs/diagrams/phase2-week6-workflow.mmd`.
4. End-to-end script workflow: `docs/diagrams/phase2-end2end-workflow.mmd`.

## Technical trust schemas for architecture analysis

Use this second schema family when the objective is technical PKI and IAM understanding rather than operator execution order.

### Static view (deployment and trust relationships at rest)

1. Phase 2 static trust architecture: `docs/diagrams/phase2-static-trust-architecture.mmd`.

### Dynamic view (runtime interactions during proof scenarios)

1. Week 4 token exchange sequence: `docs/diagrams/phase2-week4-token-exchange-sequence.mmd`.
2. Week 5 SPIRE workload identity sequence: `docs/diagrams/phase2-week5-spire-sequence.mmd`.
3. Week 6 OpenBao and MinIO zero-secret sequence: `docs/diagrams/phase2-week6-openbao-minio-sequence.mmd`.

These dynamic sequence diagrams are intentionally aligned with the Week 4, Week 5, and Week 6 acceptance scripts, including positive and negative branches.

Placement recommendation:

1. Keep this document focused on requirements, criteria, and acceptance commands.
2. Keep diagram source files versioned under `docs/diagrams/` and referenced from here.
3. Keep workflow diagrams for operator run order and technical trust diagrams for PKI and IAM semantics.

## Execution status on 2026-09-02

Phase 2 scripts currently used in the `lab1` environment:

1. `scripts/phase2-week4.ps1`
2. `scripts/phase2-week5.ps1`
3. `scripts/phase2-week6.ps1`

Validated so far:

1. Week 4 token-exchange proof is complete.
2. Week 5 SPIRE workload-identity proof is complete.
3. Week 6 OpenBao and MinIO zero-secret execution slice is complete.

Still pending in Phase 2:

1. No pending baseline proof items as of 2026-09-02.

## Week 4: Cluster token and Keycloak token-exchange proof

### Component to deploy

1. Keycloak workload-identity configuration
2. Demo workload with a projected ServiceAccount token
3. Optional realm, client, and token-exchange settings if not already seeded

### Demonstration scenario

A demo pod receives a projected Kubernetes ServiceAccount token. The cluster issuer metadata and JWKS are inspected. That token is then exchanged through Keycloak using RFC 8693 so that the workload receives a short-lived downstream token with the expected audience and claims.

### Exact success criteria

1. The cluster OIDC discovery document is reachable.
2. The cluster JWKS endpoint is reachable.
3. The demo pod can read its projected token.
4. Keycloak token exchange returns HTTP 200.
5. The exchanged token contains the expected issuer, audience, subject, and expiry.
6. A negative test with the wrong audience, client, or policy binding fails.

### Exact smoke or acceptance commands

```powershell
ssh -i C:/Users/jflorentin/.ssh/orange_lab1_bootstrap_ed25519 debian@192.168.1.210 "sudo k3s kubectl get --raw /.well-known/openid-configuration"
ssh -i C:/Users/jflorentin/.ssh/orange_lab1_bootstrap_ed25519 debian@192.168.1.210 "sudo k3s kubectl get --raw /openid/v1/jwks"
ssh -i C:/Users/jflorentin/.ssh/orange_lab1_bootstrap_ed25519 debian@192.168.1.210 "sudo k3s kubectl exec -n identity deploy/<demo-pod> -- cat /var/run/secrets/tokens/<projected-token-file>"
curl -k -X POST https://<keycloak-host>/realms/<realm>/protocol/openid-connect/token -d "grant_type=urn:ietf:params:oauth:grant-type:token-exchange" -d "client_id=<client>" -d "client_secret=<secret>" -d "subject_token=<jwt>" -d "subject_token_type=urn:ietf:params:oauth:token-type:jwt" -d "requested_token_type=urn:ietf:params:oauth:token-type:access_token"
```

## Week 5: SPIRE workload identity proof

### Component to deploy

1. SPIRE server
2. SPIRE agent
3. Two demo workloads bound to SPIFFE identities

### Demonstration scenario

Two workloads receive SPIFFE identities through SPIRE. Each workload proves its identity from SPIRE-issued material rather than from a static secret. A trust-based call succeeds for the allowed workload and fails for an unauthorized one.

### Exact success criteria

1. SPIRE server and SPIRE agent pods are healthy.
2. Registration entries exist for the intended workloads.
3. The expected SPIFFE IDs are visible from the workloads.
4. SVID material is present and rotated automatically.
5. A trust-based workload-to-workload call succeeds.
6. A workload without the expected identity binding is denied.

### Exact smoke or acceptance commands

```powershell
Set-Location -LiteralPath 'C:\Projects\Orange-Lab1'; .\scripts\phase2-week5.ps1
ssh -i C:/Users/jflorentin/.ssh/orange_lab1_bootstrap_ed25519 debian@192.168.1.210 "sudo k3s kubectl get pods -n spire"
ssh -i C:/Users/jflorentin/.ssh/orange_lab1_bootstrap_ed25519 debian@192.168.1.210 "sudo k3s kubectl exec -n spire deploy/spire-server -- /opt/spire/bin/spire-server entry show"
ssh -i C:/Users/jflorentin/.ssh/orange_lab1_bootstrap_ed25519 debian@192.168.1.210 "sudo k3s kubectl exec -n <app-namespace> <workload-pod> -- printenv | grep SPIFFE"
ssh -i C:/Users/jflorentin/.ssh/orange_lab1_bootstrap_ed25519 debian@192.168.1.210 "sudo k3s kubectl exec -n <app-namespace> <workload-pod> -- ls /run/spire/sockets"
```

## Week 6A: OpenBao dynamic-secret proof

### Component to deploy

1. OpenBao
2. Kubernetes authentication method in OpenBao
3. Policy and role bindings for one authorized and one unauthorized workload

### Demonstration scenario

An authorized pod authenticates to OpenBao with its Kubernetes identity and receives a dynamic secret with a lease and TTL. An unauthorized pod using a different ServiceAccount, namespace, or role binding is denied.

### Exact success criteria

1. OpenBao pods are healthy.
2. Kubernetes auth is configured and reachable.
3. The authorized workload obtains an OpenBao token.
4. The workload can read the intended secret or dynamic credential.
5. The returned lease has a TTL.
6. The unauthorized workload receives an authorization failure.

### Exact smoke or acceptance commands

```powershell
Set-Location -LiteralPath 'C:\Projects\Orange-Lab1'; .\scripts\phase2-week6.ps1
ssh -i C:/Users/jflorentin/.ssh/orange_lab1_bootstrap_ed25519 debian@192.168.1.210 "sudo k3s kubectl get pods -n secrets"
ssh -i C:/Users/jflorentin/.ssh/orange_lab1_bootstrap_ed25519 debian@192.168.1.210 "sudo k3s kubectl exec -n <app-namespace> <authorized-pod> -- sh -c 'cat /var/run/secrets/kubernetes.io/serviceaccount/token'"
curl -s -X POST https://<openbao-host>/v1/auth/kubernetes/login -d '{"role":"<role>","jwt":"<jwt>"}'
curl -s -H "X-Vault-Token: <token>" https://<openbao-host>/v1/<secret-path>
curl -s -o /dev/null -w "%{http_code}`n" -X POST https://<openbao-host>/v1/auth/kubernetes/login -d '{"role":"<role>","jwt":"<unauthorized-jwt>"}'
```

## Week 6B: MinIO federated temporary-credential proof

### Component to deploy

1. MinIO
2. Identity federation or web-identity integration
3. Demo workload that reads or writes an object using temporary credentials only

### Demonstration scenario

A workload exchanges federated identity for short-lived S3-compatible credentials, accesses a MinIO bucket, and then loses access when the token expires or when the identity binding is incorrect.

### Mandatory Week 6 closure checklist

Week 6 is considered complete only when both implementations are covered:

1. Implementation 1.1: one pod obtains a dynamic secret from OpenBao or Vault through Kubernetes authentication.
2. Implementation 1.2: one pod obtains temporary MinIO credentials by exchanging a federated identity token.

Current validated state in this lab:

1. Implementation 1.1 is validated by `scripts/phase2-week6.ps1` and `scripts/phase2-end2end-zero-secret.ps1`.
2. Implementation 1.2 is currently validated in `accesskey-expiry` mode (short-lived MinIO access keys) and marked for strict STS web-identity exchange hardening when MinIO OpenID provider is enabled.

### Exact success criteria

1. MinIO pods are healthy.
2. Temporary credentials are issued successfully.
3. A bucket read or write operation succeeds with those credentials.
4. The credentials are visibly time-limited.
5. A negative test with an invalid identity or expired token fails.

### Exact smoke or acceptance commands

```powershell
Set-Location -LiteralPath 'C:\Projects\Orange-Lab1'; .\scripts\phase2-week6.ps1
ssh -i C:/Users/jflorentin/.ssh/orange_lab1_bootstrap_ed25519 debian@192.168.1.210 "sudo k3s kubectl get pods -n storage"
curl -k -X POST "https://<minio-host>/?Action=AssumeRoleWithWebIdentity&Version=2011-06-15&WebIdentityToken=<token>"
AWS_ACCESS_KEY_ID=<access-key> AWS_SECRET_ACCESS_KEY=<secret-key> AWS_SESSION_TOKEN=<session-token> aws --endpoint-url https://<minio-host> s3 ls s3://<bucket>
AWS_ACCESS_KEY_ID=<access-key> AWS_SECRET_ACCESS_KEY=<secret-key> AWS_SESSION_TOKEN=<session-token> aws --endpoint-url https://<minio-host> s3 cp <file> s3://<bucket>/
```

## End-of-phase proof: Zero-secret end-to-end demonstration

### Component to deploy

1. One demo application
2. SPIRE-backed workload identity
3. OpenBao secret retrieval
4. MinIO object access
5. Optional Keycloak token exchange if the application also needs an OAuth downstream token

### Demonstration scenario

One application runs on the cluster with no long-lived application secret stored in source control or static Kubernetes manifests. It proves its workload identity, retrieves a secret from OpenBao, accesses MinIO with temporary credentials, and fails when the identity-to-policy mapping is removed.

### Exact success criteria

1. No static application credential is embedded in manifests.
2. The application can retrieve its runtime secret from OpenBao.
3. The application can access MinIO using temporary credentials only.
4. The access path is identity-driven and time-limited.
5. Removing the workload binding or policy causes the flow to fail.
6. The same demonstration is repeatable from a clean environment.

### Exact smoke or acceptance commands

```powershell
Set-Location -LiteralPath 'C:\Projects\Orange-Lab1'; .\scripts\phase2-end2end-zero-secret.ps1
ssh -i C:/Users/jflorentin/.ssh/orange_lab1_bootstrap_ed25519 debian@192.168.1.210 "sudo k3s kubectl get pods -A"
ssh -i C:/Users/jflorentin/.ssh/orange_lab1_bootstrap_ed25519 debian@192.168.1.210 "sudo k3s kubectl get secrets -A"
ssh -i C:/Users/jflorentin/.ssh/orange_lab1_bootstrap_ed25519 debian@192.168.1.210 "sudo k3s kubectl logs -n <app-namespace> deploy/<demo-app>"
ssh -i C:/Users/jflorentin/.ssh/orange_lab1_bootstrap_ed25519 debian@192.168.1.210 "sudo k3s kubectl exec -n <app-namespace> deploy/<demo-app> -- <runtime-check-command>"
```

## Transposition note to hyperscaler commercial services

Use this mapping when moving the same Week 6 zero-secret pattern to public cloud platforms:

1. Kubernetes workload identity:
AWS EKS IRSA, Azure AKS Workload Identity, Google GKE Workload Identity.
2. Secret manager with workload-authn:
HashiCorp Vault or OpenBao equivalent, AWS Secrets Manager plus IAM role, Azure Key Vault plus managed identity, Google Secret Manager plus Workload Identity Federation.
3. Object storage temporary credentials:
MinIO STS pattern maps to AWS STS for S3, Azure user delegation SAS for Blob Storage, and Google short-lived access tokens for Cloud Storage.
4. Policy and authorization model:
OpenFGA and ReBAC policy concepts map to IAM conditions and policy bindings on each hyperscaler.

## Notes on execution

1. Replace placeholders before running commands.
2. Keep all validation commands under version control as scripts where possible.
3. Preserve at least one positive path and one negative path for each workload-identity proof.
4. Treat Phase 2 as complete only when the end-to-end zero-secret demonstration passes, not only when the components are installed.

## Annexe: agent self-reference

This document now separates operator workflows from technical trust analysis by referencing a dedicated static architecture diagram and dedicated dynamic sequence diagrams for Week 4, Week 5, and Week 6.