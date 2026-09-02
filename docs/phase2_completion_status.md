# Phase 2 Completion Status

## Interpretation used for this lab

Phase 2 is the workload-identity proof phase.

Under this interpretation, Phase 2 is not complete when the identity-related components merely exist in the cluster. It is complete only when they demonstrate identity-driven behavior through repeatable positive and negative runtime checks.

This means that the first completed milestone inside Phase 2 is the Week 4 Keycloak and Kubernetes token-exchange proof, not the entire end-of-phase zero-secret target.

## Scope baseline

The main proof areas for Phase 2 are:

1. Kubernetes projected ServiceAccount token validation
2. Keycloak RFC 8693 token exchange
3. SPIRE workload identity proof
4. OpenBao dynamic secret proof
5. MinIO temporary credential proof
6. End-to-end zero-secret demonstration

## Current status on 2026-09-02

### Latest validated achievement

Weeks 4, 5, and 6 execution slices are now complete in the `lab1` environment.

What is now proven:

1. The cluster OIDC discovery document is reachable.
2. The cluster JWKS endpoint is reachable.
3. The demo workload receives a projected Kubernetes ServiceAccount token.
4. The projected token claims are validated for issuer, subject, audience, and expiry.
5. Keycloak admin automation works through `kcadm.sh` inside the running Keycloak pod.
6. A positive RFC 8693 token exchange succeeds for the permitted target client.
7. A negative RFC 8693 token exchange fails for an invalid audience, which confirms that the exchange is not granted blindly.
8. SPIRE registration entries include the authorized Week 5 SPIFFE identity and exclude the denied one.
9. OpenBao Kubernetes-auth login succeeds for the authorized service account and fails for the denied one.
10. MinIO expiring access-key credentials are issued successfully, support a positive object operation, and fail the negative wrong-secret check.

### Clarifying explanation

The negative Week 4 test currently validates an unknown audience rejection, not an authorization denial against an existing but unauthorized audience.

That is still a valid negative proof for this milestone because it confirms that Keycloak refuses a token-exchange request when the requested audience does not resolve to a valid client.

A stronger negative proof can be added later by targeting a real client without granting the `token-exchange` permission for it.

## Status verdict

Phase 2 is in progress.

Weeks 4 through 6 are complete, but the full phase is not yet complete because the single end-to-end zero-secret demonstrator proof still remains to be validated.

## Important implementation note from this milestone

The final working Keycloak 26.1.4 model in this lab is:

1. Feature enablement uses `--features=authorization,admin-fine-grained-authz,token-exchange`.
2. The old realm-level `admin-permissions` client assumption is not the correct automation path for this runtime.
3. The working automation path enables management permissions on the target client and updates the generated `token-exchange` permission under `realm-management`.

## Detailed debugging record for the Keycloak realm and authorization path

This Week 4 proof took longer than expected because the initial automation model matched older or different Keycloak behavior assumptions more than the live Bitnami Keycloak 26.1.4 runtime used in this lab.

### What we first assumed and why it failed

The first implementation assumed that setting `adminPermissionsEnabled=true` on the realm would be enough to expose an `admin-permissions` client that could host the token-exchange authorization objects.

That assumption drove this initial authorization path:

1. create the `workload-identity` realm,
2. update the realm with `adminPermissionsEnabled=true`,
3. resolve a client with `clientId=admin-permissions`,
4. create a requester policy under that client,
5. create a scope permission for `token-exchange` under that same client.

In practice, that path failed repeatedly because the runtime never exposed the expected `admin-permissions` client.

### Failed possibilities that were tested and ruled out

The following possibilities were tested before the final fix was known:

1. Broken UUID parsing.
The first suspicion was that the `sed` extraction logic might be too brittle. That theory was disproved by querying the raw client list and confirming that `clientId=admin-permissions` returned an empty array, while the other expected clients were present.

2. Realm update succeeded but the client was delayed.
This was ruled out by reading the realm state back immediately after the update. `adminPermissionsEnabled` still came back as `false`, which showed that the field was not taking effect in the expected way.

3. Wrong feature set for modern token exchange.
Current Keycloak documentation pointed toward `token-exchange-standard` and `admin-fine-grained-authz`, so the first feature-alignment attempt moved the script in that direction.

4. Invalid feature flag syntax.
The first correction attempt used separate runtime flags such as `--feature-authorization=enabled` and `--feature-token-exchange-standard=enabled`. That crashed the Keycloak container on startup. The container logs showed `Unknown option: '--feature-authorization'`, which proved that this Bitnami runtime only accepts the consolidated `--features=` form.

5. Correct syntax but wrong feature name.
After changing to `--features=authorization,admin-fine-grained-authz,token-exchange-standard`, the pod still crash-looped. The logs then showed that `token-exchange-standard` itself was unrecognized by the running image, even though it appeared in current upstream documentation. The live runtime explicitly listed `token-exchange` as the accepted feature name.

6. Probe commands obscured by nested quoting.
Some direct diagnostic commands became hard to trust because nested PowerShell, SSH, and shell quoting caused the remote shell to wait for more input or to execute malformed inner commands. The reliable workaround was to send small scripts through SSH stdin instead of trying to keep the entire probe inside one deeply quoted one-liner.

### What the live runtime finally revealed

Once Keycloak was brought back with `--features=authorization,admin-fine-grained-authz,token-exchange`, the investigation shifted from documentation assumptions to live API inspection.

The decisive findings were:

1. The target client exposes `clients/<target-client-uuid>/management/permissions`.
2. That endpoint initially returned only `{ "enabled" : false }`.
3. Enabling it with `enabled=true` caused Keycloak to generate scope-permission metadata for that client, including a `token-exchange` permission id.
4. The generated authorization objects did not live under a separate `admin-permissions` client. They lived under the `realm-management` client authorization server.
5. The generated permission name followed the pattern `token-exchange.permission.client.<target-client-uuid>`.

This changed the correct model from a realm-level `admin-permissions` path to a per-target-client management-permissions path.

### The final working fix

The final fix combined three changes:

1. Use the feature list accepted by the running image: `authorization,admin-fine-grained-authz,token-exchange`.
2. Stop relying on `adminPermissionsEnabled=true` and stop resolving `clientId=admin-permissions`.
3. Enable management permissions on `target-client1`, resolve the generated `token-exchange` permission id, create the requester policy under `realm-management`, and update that generated scope permission to reference the requester policy.

After that change, the script passed the full Week 4 flow and the token exchange returned HTTP 200 for the allowed audience.

### Representative commands that exposed the real model

Command used to prove that the target client exposes management permissions:

```powershell
ssh -i C:/Users/jflorentin/.ssh/orange_lab1_bootstrap_ed25519 debian@192.168.1.210 "sudo k3s kubectl -n identity exec keycloak-0 -- /opt/bitnami/keycloak/bin/kcadm.sh get clients/<target-client-uuid>/management/permissions -r workload-identity --config /tmp/kcadm.config"
```

Rough output before enablement:

```text
{
	"enabled" : false
}
```

Rough output after enablement:

```text
{
	"enabled" : true,
	"resource" : "<resource-uuid>",
	"scopePermissions" : {
		"token-exchange" : "<permission-uuid>"
	}
}
```

Command used to inspect the actual authorization server that owned the generated permission:

```powershell
ssh -i C:/Users/jflorentin/.ssh/orange_lab1_bootstrap_ed25519 debian@192.168.1.210 "sudo k3s kubectl -n identity exec keycloak-0 -- /opt/bitnami/keycloak/bin/kcadm.sh get clients/<realm-management-uuid>/authz/resource-server -r workload-identity --config /tmp/kcadm.config"
```

Rough output:

```text
{
	"name" : "realm-management",
	"policyEnforcementMode" : "ENFORCING",
	"resources" : [ ],
	"policies" : [ ],
	"scopes" : [ ]
}
```

## Recorded evidence locations

1. Phase 2 validation plan: `docs/phase2_workload_identity_validation.md`.
2. Phase 2 current completion status: `docs/phase2_completion_status.md`.
3. Phase 1 completion baseline: `docs/phase1_completion_status.md`.
4. Phase 1 readiness gate: `scripts/phase1-week1.ps1`.
5. Phase 2 Week 4 execution script: `scripts/phase2-week4.ps1`.
6. Consolidated operational notes: `docs/runbooks.md`.

## Week 4 demonstration commands and rough output

Command used to restore the correct Keycloak feature set:

```powershell
ssh -i C:/Users/jflorentin/.ssh/orange_lab1_bootstrap_ed25519 debian@192.168.1.210 "sudo k3s kubectl -n identity set env statefulset/keycloak KEYCLOAK_EXTRA_ARGS='--features=authorization,admin-fine-grained-authz,token-exchange'; sudo k3s kubectl -n identity rollout status statefulset/keycloak --timeout=900s; sudo k3s kubectl -n identity get pods -o wide"
```

Rough output:

```text
statefulset.apps/keycloak env updated
Waiting for 1 pods to be ready...
partitioned roll out complete: 1 new pods have been updated...
keycloak-0   1/1   Running
```

Command used for the final Week 4 proof:

```powershell
Set-Location -LiteralPath 'C:\Projects\Orange-Lab1'; .\scripts\phase2-week4.ps1
```

Rough output:

```text
Phase 2 Week 4 validation started
1) Cluster OIDC discovery document
2) Cluster JWKS document
3) Applying the projected-token demo workload
4) Reading the projected token from the demo workload
Projected token issuer: https://kubernetes.default.svc.cluster.local
Projected token subject: system:serviceaccount:identity:workload-identity-demo
Projected token audience: workload-identity-demo
5) Validating Keycloak admin automation path
6) Ensuring Keycloak token-exchange feature is enabled
7) Seeding Keycloak and running RFC 8693 token exchange tests
RFC8693_POSITIVE_HTTP=200
RFC8693_NEGATIVE_HTTP=400
RFC8693_NEGATIVE_BODY_BEGIN
{"error":"invalid_client","error_description":"Audience not found"}
RFC8693_NEGATIVE_BODY_END
Exchanged token audience: target-client1
Week 4 execution slice completed
```

## Remaining Phase 2 execution order

1. End-to-end zero-secret demonstration

## Annexe: agent self-reference

This document records the current validated Phase 2 milestone and the exact operator-facing commands used to demonstrate it. It is intentionally separate from the Phase 2 validation plan so that the plan can remain stable while execution evidence evolves.
