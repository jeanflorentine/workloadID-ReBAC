param(
    [string]$TargetHost = '192.168.1.210',
    [string]$SshUser = 'debian',
    [string]$SshKeyPath = 'C:/Users/jflorentin/.ssh/orange_lab1_bootstrap_ed25519',
    [string]$SpireManifestPath = '',
    [string]$OpenBaoManifestPath = '',
    [string]$SpireNamespace = 'identity',
    [string]$SpireAllowedNamespace = 'authorization',
    [string]$SpireAllowedDeployment = 'spire-demo-allowed',
    [string]$SpireAllowedServiceAccount = 'spire-demo-allowed',
    [string]$SpireDeniedNamespace = 'identity',
    [string]$SpireDeniedServiceAccount = 'spire-demo-denied',
    [string]$TrustDomain = 'orange.lab',
    [string]$OpenBaoNamespace = 'secrets',
    [string]$OpenBaoPodName = 'openbao-0',
    [string]$OpenBaoRoleName = 'phase2-end2end-authorized',
    [string]$OpenBaoPolicyName = 'phase2-end2end-read',
    [string]$OpenBaoSecretPath = 'secret/phase2-end2end',
    [string]$OpenBaoSecretValue = 'phase2-end2end-secret-ok',
    [string]$OpenBaoDeniedDeployment = 'openbao-authz-denied',
    [string]$OpenBaoRootToken = 'ChangeMe-OpenBao-Root!',
    [string]$MinIONamespace = 'storage',
    [string]$MinIOPodName = 'minio-8fdd4d44f-mdjr8',
    [string]$MinIOAlias = 'local',
    [string]$MinIOBucket = 'phase2-end2end',
    [string]$MinIOWorkUser = 'phase2-end2end-user',
    [string]$MinIOWorkUserPassword = 'ChangeMe-Phase2-End2End-User-Password!',
    [string]$MinIOTempAccessKeyName = 'phase2-end2end-temp',
    [string]$MinIOTempCredTtl = '24h',
    [int]$TimeoutSeconds = 900
)

$ErrorActionPreference = 'Stop'

function Invoke-Remote {
    param([string]$Command)

    & ssh -i $SshKeyPath -p 22 "$SshUser@$TargetHost" $Command
    if ($LASTEXITCODE -ne 0) {
        throw "Remote command failed: $Command"
    }
}

function Copy-ManifestToRemote {
    param(
        [string]$LocalPath,
        [string]$RemotePath
    )

    & scp -q -i $SshKeyPath -P 22 $LocalPath "${SshUser}@${TargetHost}:$RemotePath"
    if ($LASTEXITCODE -ne 0) {
        throw "Remote manifest copy failed: $LocalPath -> $RemotePath"
    }
}

function Invoke-EndToEndSuite {
    param(
        [string]$AllowedNamespace,
        [string]$AllowedDeployment,
        [string]$AllowedServiceAccount,
        [string]$DeniedNamespace,
        [string]$DeniedDeployment,
        [string]$OpenBaoNs,
        [string]$OpenBaoPod,
        [string]$OpenBaoRole,
        [string]$OpenBaoPolicy,
        [string]$SecretPath,
        [string]$SecretValue,
        [string]$OpenBaoToken,
        [string]$MinIONs,
        [string]$MinIOPod,
        [string]$MinIOAliasName,
        [string]$MinIOBucketName,
        [string]$MinIOUser,
        [string]$MinIOUserPasswordValue,
        [string]$MinIOTempKeyName,
        [string]$MinIOTempTtl
    )

    $localScriptPath = [System.IO.Path]::GetTempFileName()
    $remoteScriptPath = '/tmp/phase2-end2end-suite.sh'

    $scriptTemplate = @'
#!/usr/bin/env bash
set -euo pipefail

ALLOWED_NAMESPACE="__ALLOWED_NAMESPACE__"
ALLOWED_DEPLOYMENT="__ALLOWED_DEPLOYMENT__"
ALLOWED_SERVICE_ACCOUNT="__ALLOWED_SERVICE_ACCOUNT__"
DENIED_NAMESPACE="__DENIED_NAMESPACE__"
DENIED_DEPLOYMENT="__DENIED_DEPLOYMENT__"

OPENBAO_NAMESPACE="__OPENBAO_NAMESPACE__"
OPENBAO_POD="__OPENBAO_POD__"
OPENBAO_ROLE="__OPENBAO_ROLE__"
OPENBAO_POLICY="__OPENBAO_POLICY__"
OPENBAO_SECRET_PATH="__OPENBAO_SECRET_PATH__"
OPENBAO_SECRET_VALUE="__OPENBAO_SECRET_VALUE__"
OPENBAO_ROOT_TOKEN="__OPENBAO_ROOT_TOKEN__"
OPENBAO_ADDR="http://127.0.0.1:8200"

MINIO_NAMESPACE="__MINIO_NAMESPACE__"
MINIO_POD="__MINIO_POD__"
MINIO_ALIAS="__MINIO_ALIAS__"
MINIO_BUCKET="__MINIO_BUCKET__"
MINIO_USER="__MINIO_USER__"
MINIO_USER_PASSWORD="__MINIO_USER_PASSWORD__"
MINIO_TEMP_KEY_NAME="__MINIO_TEMP_KEY_NAME__"
MINIO_TEMP_TTL="__MINIO_TEMP_TTL__"

kao() {
    sudo k3s kubectl -n "$OPENBAO_NAMESPACE" exec "$OPENBAO_POD" -- "$@"
}

kaosh() {
    sudo k3s kubectl -n "$OPENBAO_NAMESPACE" exec "$OPENBAO_POD" -- sh -lc "$1"
}

kminiosh() {
    sudo k3s kubectl -n "$MINIO_NAMESPACE" exec "$MINIO_POD" -- sh -lc "$1"
}

AUTHORIZED_JWT="$(sudo k3s kubectl -n "$ALLOWED_NAMESPACE" exec deploy/"$ALLOWED_DEPLOYMENT" -- cat /var/run/secrets/kubernetes.io/serviceaccount/token)"
DENIED_JWT="$(sudo k3s kubectl -n "$DENIED_NAMESPACE" exec deploy/"$DENIED_DEPLOYMENT" -- cat /var/run/secrets/kubernetes.io/serviceaccount/token)"
TOKEN_REVIEWER_JWT="$(kaosh 'cat /var/run/secrets/kubernetes.io/serviceaccount/token')"

if [[ -z "$AUTHORIZED_JWT" || -z "$DENIED_JWT" || -z "$TOKEN_REVIEWER_JWT" ]]; then
    echo "Failed to collect one or more Kubernetes JWT values for end-to-end phase 2 suite" >&2
    exit 1
fi

kao env VAULT_ADDR="$OPENBAO_ADDR" VAULT_TOKEN="$OPENBAO_ROOT_TOKEN" vault auth enable kubernetes >/dev/null 2>&1 || true
kao env VAULT_ADDR="$OPENBAO_ADDR" VAULT_TOKEN="$OPENBAO_ROOT_TOKEN" vault write auth/kubernetes/config \
    token_reviewer_jwt="$TOKEN_REVIEWER_JWT" \
    kubernetes_host="https://kubernetes.default.svc:443" \
    kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt >/dev/null

kaosh "cat >/tmp/${OPENBAO_POLICY}.hcl <<'POL'
path \"secret/data/phase2-end2end\" {
  capabilities = [\"read\"]
}
POL
VAULT_ADDR=$OPENBAO_ADDR VAULT_TOKEN='$OPENBAO_ROOT_TOKEN' vault policy write '$OPENBAO_POLICY' /tmp/${OPENBAO_POLICY}.hcl >/dev/null"

kao env VAULT_ADDR="$OPENBAO_ADDR" VAULT_TOKEN="$OPENBAO_ROOT_TOKEN" vault write "auth/kubernetes/role/$OPENBAO_ROLE" \
    bound_service_account_names="$ALLOWED_SERVICE_ACCOUNT" \
    bound_service_account_namespaces="$ALLOWED_NAMESPACE" \
    policies="$OPENBAO_POLICY" \
    ttl=15m >/dev/null

kao env VAULT_ADDR="$OPENBAO_ADDR" VAULT_TOKEN="$OPENBAO_ROOT_TOKEN" vault kv put "$OPENBAO_SECRET_PATH" message="$OPENBAO_SECRET_VALUE" >/dev/null

AUTHORIZED_LOGIN_JSON="$(kao env VAULT_ADDR="$OPENBAO_ADDR" VAULT_TOKEN="$OPENBAO_ROOT_TOKEN" vault write -format=json auth/kubernetes/login role="$OPENBAO_ROLE" jwt="$AUTHORIZED_JWT")"
OPENBAO_CLIENT_TOKEN="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["auth"]["client_token"])' "$AUTHORIZED_LOGIN_JSON")"
OPENBAO_LEASE_TTL="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["auth"]["lease_duration"])' "$AUTHORIZED_LOGIN_JSON")"

AUTHORIZED_SECRET_JSON="$(kao env VAULT_ADDR="$OPENBAO_ADDR" VAULT_TOKEN="$OPENBAO_CLIENT_TOKEN" vault kv get -format=json "$OPENBAO_SECRET_PATH")"
OPENBAO_AUTHORIZED_SECRET="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["data"]["data"]["message"])' "$AUTHORIZED_SECRET_JSON")"

set +e
OPENBAO_DENIED_OUTPUT="$(kao env VAULT_ADDR="$OPENBAO_ADDR" VAULT_TOKEN="$OPENBAO_ROOT_TOKEN" vault write -format=json auth/kubernetes/login role="$OPENBAO_ROLE" jwt="$DENIED_JWT" 2>&1)"
OPENBAO_DENIED_CODE=$?
set -e

MINIO_ROOT_USER="$(kminiosh 'cat /opt/bitnami/minio/secrets/root-user')"
MINIO_ROOT_PASSWORD="$(kminiosh 'cat /opt/bitnami/minio/secrets/root-password')"

kminiosh "MC=/opt/bitnami/minio-client/bin/mc; \
    \
    \$MC alias set $MINIO_ALIAS http://127.0.0.1:9000 '$MINIO_ROOT_USER' '$MINIO_ROOT_PASSWORD' >/dev/null; \
    \$MC admin user info $MINIO_ALIAS '$MINIO_USER' >/dev/null 2>&1 || \$MC admin user add $MINIO_ALIAS '$MINIO_USER' '$MINIO_USER_PASSWORD' >/dev/null; \
    \$MC admin policy attach $MINIO_ALIAS readwrite --user '$MINIO_USER' >/dev/null 2>&1 || true; \
    \$MC mb --ignore-existing $MINIO_ALIAS/$MINIO_BUCKET >/dev/null"

MINIO_TEMP_CRED_JSON="$(kminiosh "MC=/opt/bitnami/minio-client/bin/mc; \
    \
    \$MC alias set $MINIO_ALIAS http://127.0.0.1:9000 '$MINIO_ROOT_USER' '$MINIO_ROOT_PASSWORD' >/dev/null; \
    \$MC admin accesskey create $MINIO_ALIAS '$MINIO_USER' --name '$MINIO_TEMP_KEY_NAME' --expiry-duration '$MINIO_TEMP_TTL' --json")"

MINIO_TEMP_ACCESS_KEY="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["accessKey"])' "$MINIO_TEMP_CRED_JSON")"
MINIO_TEMP_SECRET_KEY="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["secretKey"])' "$MINIO_TEMP_CRED_JSON")"
MINIO_TEMP_STATUS="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1]).get("status", ""))' "$MINIO_TEMP_CRED_JSON")"

kminiosh "MC=/opt/bitnami/minio-client/bin/mc; \
    \
    \$MC alias set tempend2end http://127.0.0.1:9000 '$MINIO_TEMP_ACCESS_KEY' '$MINIO_TEMP_SECRET_KEY' >/dev/null; \
    printf 'phase2-end2end-proof %s\n' \"\$(date -u +%Y-%m-%dT%H:%M:%SZ)\" > /tmp/phase2-end2end-proof.txt; \
    \$MC cp /tmp/phase2-end2end-proof.txt tempend2end/$MINIO_BUCKET/phase2-end2end-proof.txt >/dev/null; \
    \$MC cat tempend2end/$MINIO_BUCKET/phase2-end2end-proof.txt"

set +e
MINIO_NEGATIVE_OUTPUT="$(kminiosh "MC=/opt/bitnami/minio-client/bin/mc; \
    \
    \$MC alias set tempend2endbad http://127.0.0.1:9000 '$MINIO_TEMP_ACCESS_KEY' 'wrong-secret-for-negative-test' >/dev/null 2>&1; \
    \$MC ls tempend2endbad/$MINIO_BUCKET" 2>&1)"
MINIO_NEGATIVE_CODE=$?
set -e

kao env VAULT_ADDR="$OPENBAO_ADDR" VAULT_TOKEN="$OPENBAO_ROOT_TOKEN" vault write "auth/kubernetes/role/$OPENBAO_ROLE" \
    bound_service_account_names="phase2-end2end-revoked" \
    bound_service_account_namespaces="$ALLOWED_NAMESPACE" \
    policies="$OPENBAO_POLICY" \
    ttl=15m >/dev/null

set +e
REVOCATION_DENIED_OUTPUT="$(kao env VAULT_ADDR="$OPENBAO_ADDR" VAULT_TOKEN="$OPENBAO_ROOT_TOKEN" vault write -format=json auth/kubernetes/login role="$OPENBAO_ROLE" jwt="$AUTHORIZED_JWT" 2>&1)"
REVOCATION_DENIED_CODE=$?
set -e

kao env VAULT_ADDR="$OPENBAO_ADDR" VAULT_TOKEN="$OPENBAO_ROOT_TOKEN" vault write "auth/kubernetes/role/$OPENBAO_ROLE" \
    bound_service_account_names="$ALLOWED_SERVICE_ACCOUNT" \
    bound_service_account_namespaces="$ALLOWED_NAMESPACE" \
    policies="$OPENBAO_POLICY" \
    ttl=15m >/dev/null

echo "E2E_OPENBAO_AUTHORIZED_TTL=$OPENBAO_LEASE_TTL"
echo "E2E_OPENBAO_AUTHORIZED_SECRET=$OPENBAO_AUTHORIZED_SECRET"
echo "E2E_OPENBAO_DENIED_CODE=$OPENBAO_DENIED_CODE"
echo "E2E_OPENBAO_DENIED_OUTPUT_BEGIN"
echo "$OPENBAO_DENIED_OUTPUT"
echo "E2E_OPENBAO_DENIED_OUTPUT_END"

echo "E2E_MINIO_TEMP_STATUS=$MINIO_TEMP_STATUS"
echo "E2E_MINIO_NEGATIVE_CODE=$MINIO_NEGATIVE_CODE"
echo "E2E_MINIO_NEGATIVE_OUTPUT_BEGIN"
echo "$MINIO_NEGATIVE_OUTPUT"
echo "E2E_MINIO_NEGATIVE_OUTPUT_END"

echo "E2E_REVOCATION_DENIED_CODE=$REVOCATION_DENIED_CODE"
echo "E2E_REVOCATION_DENIED_OUTPUT_BEGIN"
echo "$REVOCATION_DENIED_OUTPUT"
echo "E2E_REVOCATION_DENIED_OUTPUT_END"
'@

    $scriptContent = $scriptTemplate
    $scriptContent = $scriptContent.Replace('__ALLOWED_NAMESPACE__', $AllowedNamespace)
    $scriptContent = $scriptContent.Replace('__ALLOWED_DEPLOYMENT__', $AllowedDeployment)
    $scriptContent = $scriptContent.Replace('__ALLOWED_SERVICE_ACCOUNT__', $AllowedServiceAccount)
    $scriptContent = $scriptContent.Replace('__DENIED_NAMESPACE__', $DeniedNamespace)
    $scriptContent = $scriptContent.Replace('__DENIED_DEPLOYMENT__', $DeniedDeployment)
    $scriptContent = $scriptContent.Replace('__OPENBAO_NAMESPACE__', $OpenBaoNs)
    $scriptContent = $scriptContent.Replace('__OPENBAO_POD__', $OpenBaoPod)
    $scriptContent = $scriptContent.Replace('__OPENBAO_ROLE__', $OpenBaoRole)
    $scriptContent = $scriptContent.Replace('__OPENBAO_POLICY__', $OpenBaoPolicy)
    $scriptContent = $scriptContent.Replace('__OPENBAO_SECRET_PATH__', $SecretPath)
    $scriptContent = $scriptContent.Replace('__OPENBAO_SECRET_VALUE__', $SecretValue)
    $scriptContent = $scriptContent.Replace('__OPENBAO_ROOT_TOKEN__', $OpenBaoToken)
    $scriptContent = $scriptContent.Replace('__MINIO_NAMESPACE__', $MinIONs)
    $scriptContent = $scriptContent.Replace('__MINIO_POD__', $MinIOPod)
    $scriptContent = $scriptContent.Replace('__MINIO_ALIAS__', $MinIOAliasName)
    $scriptContent = $scriptContent.Replace('__MINIO_BUCKET__', $MinIOBucketName)
    $scriptContent = $scriptContent.Replace('__MINIO_USER__', $MinIOUser)
    $scriptContent = $scriptContent.Replace('__MINIO_USER_PASSWORD__', $MinIOUserPasswordValue)
    $scriptContent = $scriptContent.Replace('__MINIO_TEMP_KEY_NAME__', $MinIOTempKeyName)
    $scriptContent = $scriptContent.Replace('__MINIO_TEMP_TTL__', $MinIOTempTtl)

    $scriptContent = $scriptContent -replace "`r`n", "`n"
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($localScriptPath, $scriptContent, $utf8NoBom)

    try {
        Copy-ManifestToRemote -LocalPath $localScriptPath -RemotePath $remoteScriptPath
        Invoke-Remote "chmod 700 $remoteScriptPath"
        return Invoke-Remote "bash $remoteScriptPath"
    }
    finally {
        Remove-Item -LiteralPath $localScriptPath -ErrorAction SilentlyContinue
    }
}

if ([string]::IsNullOrWhiteSpace($SpireManifestPath)) {
    $SpireManifestPath = Join-Path $PSScriptRoot '..\kubernetes\overlays\lab1\week5-spire-identity-demo.yaml'
}

if ([string]::IsNullOrWhiteSpace($OpenBaoManifestPath)) {
    $OpenBaoManifestPath = Join-Path $PSScriptRoot '..\kubernetes\overlays\lab1\week6-zero-secret-demo.yaml'
}

$resolvedSpireManifestPath = (Resolve-Path -LiteralPath $SpireManifestPath).Path
$resolvedOpenBaoManifestPath = (Resolve-Path -LiteralPath $OpenBaoManifestPath).Path
$remoteSpireManifestPath = '/tmp/week5-spire-identity-demo.yaml'
$remoteOpenBaoManifestPath = '/tmp/week6-zero-secret-demo.yaml'

Write-Host 'Phase 2 end-to-end zero-secret validation started'

Write-Host '1) Checking SPIRE, OpenBao, and MinIO control planes'
Invoke-Remote "sudo k3s kubectl wait --for=condition=Ready pod -n $SpireNamespace -l app.kubernetes.io/instance=spire --timeout=${TimeoutSeconds}s"
Invoke-Remote "sudo k3s kubectl wait --for=condition=Ready pod -n $OpenBaoNamespace -l app.kubernetes.io/instance=openbao --timeout=${TimeoutSeconds}s"
Invoke-Remote "sudo k3s kubectl wait --for=condition=Ready pod -n $MinIONamespace -l app.kubernetes.io/instance=minio --timeout=${TimeoutSeconds}s"

Write-Host '2) Ensuring Week 5 and Week 6 workloads are deployed'
Copy-ManifestToRemote -LocalPath $resolvedSpireManifestPath -RemotePath $remoteSpireManifestPath
Copy-ManifestToRemote -LocalPath $resolvedOpenBaoManifestPath -RemotePath $remoteOpenBaoManifestPath
Invoke-Remote "sudo k3s kubectl apply -f $remoteSpireManifestPath"
Invoke-Remote "sudo k3s kubectl apply -f $remoteOpenBaoManifestPath"
Invoke-Remote "sudo k3s kubectl -n $SpireAllowedNamespace rollout status deploy/$SpireAllowedDeployment --timeout=${TimeoutSeconds}s"
Invoke-Remote "sudo k3s kubectl -n $OpenBaoNamespace rollout status deploy/$OpenBaoDeniedDeployment --timeout=${TimeoutSeconds}s"

Write-Host '3) Verifying SPIRE identity bindings for allowed and denied identities'
$entriesOutput = Invoke-Remote "sudo k3s kubectl -n $SpireNamespace exec statefulset/spire-server -c spire-server -- /opt/spire/bin/spire-server entry show"
$entriesOutput | Write-Host

$allowedSpiffeId = "spiffe://$TrustDomain/ns/$SpireAllowedNamespace/sa/$SpireAllowedServiceAccount"
$deniedSpiffeId = "spiffe://$TrustDomain/ns/$SpireDeniedNamespace/sa/$SpireDeniedServiceAccount"

$hasAllowedEntry = $entriesOutput -match [regex]::Escape($allowedSpiffeId)
$hasDeniedEntry = $entriesOutput -match [regex]::Escape($deniedSpiffeId)

if (-not $hasAllowedEntry) {
    throw "Expected SPIRE entry for allowed workload was not found: $allowedSpiffeId"
}

if ($hasDeniedEntry) {
    throw "Denied SPIRE workload unexpectedly received an identity entry: $deniedSpiffeId"
}

Write-Host 'E2E_SPIRE_ALLOWED_ENTRY=true'
Write-Host 'E2E_SPIRE_DENIED_ENTRY=false'
Write-Host "E2E_SPIRE_ALLOWED_ID=$allowedSpiffeId"
Write-Host "E2E_SPIRE_DENIED_ID=$deniedSpiffeId"

Write-Host '4) Verifying workload manifest does not embed static credentials'
$embeddedEnvValues = Invoke-Remote "sudo k3s kubectl -n $SpireAllowedNamespace get deploy/$SpireAllowedDeployment -o jsonpath='{.spec.template.spec.containers[*].env[*].value}'"
$embeddedSecretRefs = Invoke-Remote "sudo k3s kubectl -n $SpireAllowedNamespace get deploy/$SpireAllowedDeployment -o jsonpath='{.spec.template.spec.containers[*].envFrom[*].secretRef.name}'"

if (-not [string]::IsNullOrWhiteSpace($embeddedEnvValues)) {
    throw "Deployment $SpireAllowedDeployment contains static environment values. Expected zero embedded credentials."
}

if (-not [string]::IsNullOrWhiteSpace($embeddedSecretRefs)) {
    throw "Deployment $SpireAllowedDeployment references envFrom Secret objects. Expected zero embedded application credentials."
}

Write-Host 'E2E_STATIC_APP_CREDENTIALS=false'

Write-Host '5) Running OpenBao and MinIO zero-secret suite and revocation gate'
$e2eOutput = Invoke-EndToEndSuite `
    -AllowedNamespace $SpireAllowedNamespace `
    -AllowedDeployment $SpireAllowedDeployment `
    -AllowedServiceAccount $SpireAllowedServiceAccount `
    -DeniedNamespace $OpenBaoNamespace `
    -DeniedDeployment $OpenBaoDeniedDeployment `
    -OpenBaoNs $OpenBaoNamespace `
    -OpenBaoPod $OpenBaoPodName `
    -OpenBaoRole $OpenBaoRoleName `
    -OpenBaoPolicy $OpenBaoPolicyName `
    -SecretPath $OpenBaoSecretPath `
    -SecretValue $OpenBaoSecretValue `
    -OpenBaoToken $OpenBaoRootToken `
    -MinIONs $MinIONamespace `
    -MinIOPod $MinIOPodName `
    -MinIOAliasName $MinIOAlias `
    -MinIOBucketName $MinIOBucket `
    -MinIOUser $MinIOWorkUser `
    -MinIOUserPasswordValue $MinIOWorkUserPassword `
    -MinIOTempKeyName $MinIOTempAccessKeyName `
    -MinIOTempTtl $MinIOTempCredTtl

$e2eOutput | Write-Host

$ttlLine = ($e2eOutput | Where-Object { $_ -match '^E2E_OPENBAO_AUTHORIZED_TTL=' } | Select-Object -Last 1)
$secretLine = ($e2eOutput | Where-Object { $_ -match '^E2E_OPENBAO_AUTHORIZED_SECRET=' } | Select-Object -Last 1)
$deniedLine = ($e2eOutput | Where-Object { $_ -match '^E2E_OPENBAO_DENIED_CODE=' } | Select-Object -Last 1)
$minioStatusLine = ($e2eOutput | Where-Object { $_ -match '^E2E_MINIO_TEMP_STATUS=' } | Select-Object -Last 1)
$minioNegLine = ($e2eOutput | Where-Object { $_ -match '^E2E_MINIO_NEGATIVE_CODE=' } | Select-Object -Last 1)
$revokeLine = ($e2eOutput | Where-Object { $_ -match '^E2E_REVOCATION_DENIED_CODE=' } | Select-Object -Last 1)

if (-not $ttlLine -or -not $secretLine -or -not $deniedLine -or -not $minioStatusLine -or -not $minioNegLine -or -not $revokeLine) {
    throw 'End-to-end suite output is missing one or more required status markers.'
}

$ttlValue = ($ttlLine -replace '^E2E_OPENBAO_AUTHORIZED_TTL=', '').Trim()
$secretValue = ($secretLine -replace '^E2E_OPENBAO_AUTHORIZED_SECRET=', '').Trim()
$deniedCode = ($deniedLine -replace '^E2E_OPENBAO_DENIED_CODE=', '').Trim()
$minioStatus = ($minioStatusLine -replace '^E2E_MINIO_TEMP_STATUS=', '').Trim()
$minioNegativeCode = ($minioNegLine -replace '^E2E_MINIO_NEGATIVE_CODE=', '').Trim()
$revocationDeniedCode = ($revokeLine -replace '^E2E_REVOCATION_DENIED_CODE=', '').Trim()

if ([int]$ttlValue -le 0) {
    throw "Authorized OpenBao login did not return a positive lease TTL: $ttlValue"
}

if ($secretValue -ne $OpenBaoSecretValue) {
    throw "OpenBao authorized secret mismatch. Expected '$OpenBaoSecretValue' but got '$secretValue'"
}

if ($deniedCode -eq '0') {
    throw 'OpenBao denied-workload login unexpectedly succeeded.'
}

if ($minioStatus -ne 'success') {
    throw "MinIO temporary access-key creation did not report success: $minioStatus"
}

if ($minioNegativeCode -eq '0') {
    throw 'MinIO negative check unexpectedly succeeded with wrong secret.'
}

if ($revocationDeniedCode -eq '0') {
    throw 'Revocation gate failed: authorized workload still logged in after role binding was changed.'
}

Write-Host "OpenBao authorized lease TTL: $ttlValue"
Write-Host "OpenBao authorized secret value: $secretValue"
Write-Host "OpenBao denied-workload login code: $deniedCode"
Write-Host "MinIO temporary credential status: $minioStatus"
Write-Host "MinIO negative check code: $minioNegativeCode"
Write-Host "Revocation denied login code: $revocationDeniedCode"
Write-Host 'Phase 2 end-to-end zero-secret validation completed'
