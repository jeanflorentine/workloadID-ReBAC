param(
    [string]$TargetHost = '192.168.1.210',
    [string]$SshUser = 'debian',
    [string]$SshKeyPath = 'C:/Users/jflorentin/.ssh/orange_lab1_bootstrap_ed25519',
    [string]$ManifestPath = '',
    [string]$OpenBaoNamespace = 'secrets',
    [string]$OpenBaoPodName = 'openbao-0',
    [string]$OpenBaoRoleName = 'phase2-week6-authorized',
    [string]$OpenBaoPolicyName = 'phase2-week6-read',
    [string]$OpenBaoSecretPath = 'secret/phase2-week6',
    [string]$OpenBaoSecretValue = 'phase2-week6-secret-ok',
    [string]$OpenBaoAuthorizedDeployment = 'openbao-authz-ok',
    [string]$OpenBaoDeniedDeployment = 'openbao-authz-denied',
    [string]$OpenBaoAuthorizedServiceAccount = 'openbao-authz-ok',
    [string]$OpenBaoRootToken = 'ChangeMe-OpenBao-Root!',
    [string]$MinIONamespace = 'storage',
    [string]$MinIOPodName = 'minio-8fdd4d44f-mdjr8',
    [string]$MinIOAlias = 'local',
    [string]$MinIOBucket = 'phase2-week6',
    [string]$MinIOWorkUser = 'phase2-week6-user',
    [string]$MinIOWorkUserPassword = 'ChangeMe-Week6-User-Password!',
    [string]$MinIOTempAccessKeyName = 'phase2-week6-temp',
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

function Invoke-Week6Suite {
    param(
        [string]$Namespace,
        [string]$OpenBaoPod,
        [string]$OpenBaoRole,
        [string]$OpenBaoPolicy,
        [string]$SecretPath,
        [string]$SecretValue,
        [string]$AuthorizedDeployment,
        [string]$DeniedDeployment,
        [string]$AuthorizedServiceAccount,
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
    $remoteScriptPath = '/tmp/week6-zero-secret-suite.sh'

    $scriptTemplate = @'
#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="__NAMESPACE__"
OPENBAO_POD="__OPENBAO_POD__"
OPENBAO_ROLE="__OPENBAO_ROLE__"
OPENBAO_POLICY="__OPENBAO_POLICY__"
OPENBAO_SECRET_PATH="__OPENBAO_SECRET_PATH__"
OPENBAO_SECRET_VALUE="__OPENBAO_SECRET_VALUE__"
AUTHORIZED_DEPLOYMENT="__AUTHORIZED_DEPLOYMENT__"
DENIED_DEPLOYMENT="__DENIED_DEPLOYMENT__"
AUTHORIZED_SERVICE_ACCOUNT="__AUTHORIZED_SERVICE_ACCOUNT__"
OPENBAO_ROOT_TOKEN="__OPENBAO_ROOT_TOKEN__"

MINIO_NAMESPACE="__MINIO_NAMESPACE__"
MINIO_POD="__MINIO_POD__"
MINIO_ALIAS="__MINIO_ALIAS__"
MINIO_BUCKET="__MINIO_BUCKET__"
MINIO_USER="__MINIO_USER__"
MINIO_USER_PASSWORD="__MINIO_USER_PASSWORD__"
MINIO_TEMP_KEY_NAME="__MINIO_TEMP_KEY_NAME__"
MINIO_TEMP_TTL="__MINIO_TEMP_TTL__"

OPENBAO_ADDR="http://127.0.0.1:8200"

kao() {
    sudo k3s kubectl -n "$NAMESPACE" exec "$OPENBAO_POD" -- "$@"
}

kaosh() {
    sudo k3s kubectl -n "$NAMESPACE" exec "$OPENBAO_POD" -- sh -lc "$1"
}

kminiosh() {
    sudo k3s kubectl -n "$MINIO_NAMESPACE" exec "$MINIO_POD" -- sh -lc "$1"
}

AUTHORIZED_JWT="$(sudo k3s kubectl -n "$NAMESPACE" exec deploy/"$AUTHORIZED_DEPLOYMENT" -- cat /var/run/secrets/kubernetes.io/serviceaccount/token)"
DENIED_JWT="$(sudo k3s kubectl -n "$NAMESPACE" exec deploy/"$DENIED_DEPLOYMENT" -- cat /var/run/secrets/kubernetes.io/serviceaccount/token)"
TOKEN_REVIEWER_JWT="$(kaosh 'cat /var/run/secrets/kubernetes.io/serviceaccount/token')"

if [[ -z "$AUTHORIZED_JWT" || -z "$DENIED_JWT" || -z "$TOKEN_REVIEWER_JWT" ]]; then
    echo "Failed to collect one or more Kubernetes JWT values for Week 6" >&2
    exit 1
fi

kao env VAULT_ADDR="$OPENBAO_ADDR" VAULT_TOKEN="$OPENBAO_ROOT_TOKEN" vault auth enable kubernetes >/dev/null 2>&1 || true
kao env VAULT_ADDR="$OPENBAO_ADDR" VAULT_TOKEN="$OPENBAO_ROOT_TOKEN" vault write auth/kubernetes/config \
    token_reviewer_jwt="$TOKEN_REVIEWER_JWT" \
    kubernetes_host="https://kubernetes.default.svc:443" \
    kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt >/dev/null

kaosh "cat >/tmp/${OPENBAO_POLICY}.hcl <<'POL'
path \"secret/data/phase2-week6\" {
  capabilities = [\"read\"]
}
POL
VAULT_ADDR=$OPENBAO_ADDR VAULT_TOKEN='$OPENBAO_ROOT_TOKEN' vault policy write '$OPENBAO_POLICY' /tmp/${OPENBAO_POLICY}.hcl >/dev/null"

kao env VAULT_ADDR="$OPENBAO_ADDR" VAULT_TOKEN="$OPENBAO_ROOT_TOKEN" vault write "auth/kubernetes/role/$OPENBAO_ROLE" \
    bound_service_account_names="$AUTHORIZED_SERVICE_ACCOUNT" \
    bound_service_account_namespaces="$NAMESPACE" \
    policies="$OPENBAO_POLICY" \
    ttl=15m >/dev/null

kao env VAULT_ADDR="$OPENBAO_ADDR" VAULT_TOKEN="$OPENBAO_ROOT_TOKEN" vault kv put "$OPENBAO_SECRET_PATH" message="$OPENBAO_SECRET_VALUE" >/dev/null

AUTHORIZED_LOGIN_JSON="$(kao env VAULT_ADDR="$OPENBAO_ADDR" VAULT_TOKEN="$OPENBAO_ROOT_TOKEN" vault write -format=json auth/kubernetes/login role="$OPENBAO_ROLE" jwt="$AUTHORIZED_JWT")"
OPENBAO_CLIENT_TOKEN="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["auth"]["client_token"])' "$AUTHORIZED_LOGIN_JSON")"
OPENBAO_LEASE_TTL="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["auth"]["lease_duration"])' "$AUTHORIZED_LOGIN_JSON")"

AUTHORIZED_SECRET_JSON="$(kao env VAULT_ADDR="$OPENBAO_ADDR" VAULT_TOKEN="$OPENBAO_CLIENT_TOKEN" vault kv get -format=json "$OPENBAO_SECRET_PATH")"
OPENBAO_AUTHORIZED_SECRET="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["data"]["data"]["message"])' "$AUTHORIZED_SECRET_JSON")"

set +e
DENIED_LOGIN_OUTPUT="$(kao env VAULT_ADDR="$OPENBAO_ADDR" VAULT_TOKEN="$OPENBAO_ROOT_TOKEN" vault write -format=json auth/kubernetes/login role="$OPENBAO_ROLE" jwt="$DENIED_JWT" 2>&1)"
DENIED_LOGIN_CODE=$?
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
    \$MC alias set tempwk6 http://127.0.0.1:9000 '$MINIO_TEMP_ACCESS_KEY' '$MINIO_TEMP_SECRET_KEY' >/dev/null; \
    printf 'week6-proof %s\n' \"\$(date -u +%Y-%m-%dT%H:%M:%SZ)\" > /tmp/week6-proof.txt; \
    \$MC cp /tmp/week6-proof.txt tempwk6/$MINIO_BUCKET/week6-proof.txt >/dev/null; \
    \$MC cat tempwk6/$MINIO_BUCKET/week6-proof.txt"

set +e
MINIO_NEGATIVE_OUTPUT="$(kminiosh "MC=/opt/bitnami/minio-client/bin/mc; \
    \
    \$MC alias set tempwk6bad http://127.0.0.1:9000 '$MINIO_TEMP_ACCESS_KEY' 'wrong-secret-for-negative-test' >/dev/null 2>&1; \
    \$MC ls tempwk6bad/$MINIO_BUCKET" 2>&1)"
MINIO_NEGATIVE_CODE=$?
set -e

echo "OPENBAO_AUTHORIZED_TTL=$OPENBAO_LEASE_TTL"
echo "OPENBAO_AUTHORIZED_SECRET=$OPENBAO_AUTHORIZED_SECRET"
echo "OPENBAO_DENIED_LOGIN_CODE=$DENIED_LOGIN_CODE"
echo "OPENBAO_DENIED_LOGIN_OUTPUT_BEGIN"
echo "$DENIED_LOGIN_OUTPUT"
echo "OPENBAO_DENIED_LOGIN_OUTPUT_END"

echo "MINIO_TEMP_ACCESSKEY_STATUS=$MINIO_TEMP_STATUS"
echo "MINIO_TEMP_CREDS_MODE=accesskey-expiry"
echo "MINIO_NEGATIVE_CODE=$MINIO_NEGATIVE_CODE"
echo "MINIO_NEGATIVE_OUTPUT_BEGIN"
echo "$MINIO_NEGATIVE_OUTPUT"
echo "MINIO_NEGATIVE_OUTPUT_END"
'@

    $scriptContent = $scriptTemplate
    $scriptContent = $scriptContent.Replace('__NAMESPACE__', $Namespace)
    $scriptContent = $scriptContent.Replace('__OPENBAO_POD__', $OpenBaoPod)
    $scriptContent = $scriptContent.Replace('__OPENBAO_ROLE__', $OpenBaoRole)
    $scriptContent = $scriptContent.Replace('__OPENBAO_POLICY__', $OpenBaoPolicy)
    $scriptContent = $scriptContent.Replace('__OPENBAO_SECRET_PATH__', $SecretPath)
    $scriptContent = $scriptContent.Replace('__OPENBAO_SECRET_VALUE__', $SecretValue)
    $scriptContent = $scriptContent.Replace('__AUTHORIZED_DEPLOYMENT__', $AuthorizedDeployment)
    $scriptContent = $scriptContent.Replace('__DENIED_DEPLOYMENT__', $DeniedDeployment)
    $scriptContent = $scriptContent.Replace('__AUTHORIZED_SERVICE_ACCOUNT__', $AuthorizedServiceAccount)
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

if ([string]::IsNullOrWhiteSpace($ManifestPath)) {
    $ManifestPath = Join-Path $PSScriptRoot '..\kubernetes\overlays\lab1\week6-zero-secret-demo.yaml'
}

$resolvedManifestPath = (Resolve-Path -LiteralPath $ManifestPath).Path
$remoteManifestPath = '/tmp/week6-zero-secret-demo.yaml'

Write-Host 'Phase 2 Week 6 validation started'

Write-Host '1) Checking OpenBao and MinIO platform health'
Invoke-Remote "sudo k3s kubectl wait --for=condition=Ready pod -n $OpenBaoNamespace -l app.kubernetes.io/instance=openbao --timeout=${TimeoutSeconds}s"
Invoke-Remote "sudo k3s kubectl wait --for=condition=Ready pod -n $MinIONamespace -l app.kubernetes.io/instance=minio --timeout=${TimeoutSeconds}s"
Invoke-Remote "sudo k3s kubectl -n $OpenBaoNamespace get pods,svc"
Invoke-Remote "sudo k3s kubectl -n $MinIONamespace get pods,svc"

Write-Host '2) Applying Week 6 workload demo manifests'
Copy-ManifestToRemote -LocalPath $resolvedManifestPath -RemotePath $remoteManifestPath
Invoke-Remote "sudo k3s kubectl apply -f $remoteManifestPath"
Invoke-Remote "sudo k3s kubectl -n $OpenBaoNamespace rollout status deploy/$OpenBaoAuthorizedDeployment --timeout=${TimeoutSeconds}s"
Invoke-Remote "sudo k3s kubectl -n $OpenBaoNamespace rollout status deploy/$OpenBaoDeniedDeployment --timeout=${TimeoutSeconds}s"

Write-Host '3) Running OpenBao identity-based secret and MinIO temporary-credential checks'
$week6Output = Invoke-Week6Suite `
    -Namespace $OpenBaoNamespace `
    -OpenBaoPod $OpenBaoPodName `
    -OpenBaoRole $OpenBaoRoleName `
    -OpenBaoPolicy $OpenBaoPolicyName `
    -SecretPath $OpenBaoSecretPath `
    -SecretValue $OpenBaoSecretValue `
    -AuthorizedDeployment $OpenBaoAuthorizedDeployment `
    -DeniedDeployment $OpenBaoDeniedDeployment `
    -AuthorizedServiceAccount $OpenBaoAuthorizedServiceAccount `
    -OpenBaoToken $OpenBaoRootToken `
    -MinIONs $MinIONamespace `
    -MinIOPod $MinIOPodName `
    -MinIOAliasName $MinIOAlias `
    -MinIOBucketName $MinIOBucket `
    -MinIOUser $MinIOWorkUser `
    -MinIOUserPasswordValue $MinIOWorkUserPassword `
    -MinIOTempKeyName $MinIOTempAccessKeyName `
    -MinIOTempTtl $MinIOTempCredTtl

$week6Output | Write-Host

$ttlLine = ($week6Output | Where-Object { $_ -match '^OPENBAO_AUTHORIZED_TTL=' } | Select-Object -Last 1)
$secretLine = ($week6Output | Where-Object { $_ -match '^OPENBAO_AUTHORIZED_SECRET=' } | Select-Object -Last 1)
$deniedLine = ($week6Output | Where-Object { $_ -match '^OPENBAO_DENIED_LOGIN_CODE=' } | Select-Object -Last 1)
$minioStatusLine = ($week6Output | Where-Object { $_ -match '^MINIO_TEMP_ACCESSKEY_STATUS=' } | Select-Object -Last 1)
$minioNegLine = ($week6Output | Where-Object { $_ -match '^MINIO_NEGATIVE_CODE=' } | Select-Object -Last 1)

if (-not $ttlLine -or -not $secretLine -or -not $deniedLine -or -not $minioStatusLine -or -not $minioNegLine) {
    throw 'Week 6 suite output is missing one or more required status markers.'
}

$ttlValue = ($ttlLine -replace '^OPENBAO_AUTHORIZED_TTL=', '').Trim()
$secretValue = ($secretLine -replace '^OPENBAO_AUTHORIZED_SECRET=', '').Trim()
$deniedCode = ($deniedLine -replace '^OPENBAO_DENIED_LOGIN_CODE=', '').Trim()
$minioStatus = ($minioStatusLine -replace '^MINIO_TEMP_ACCESSKEY_STATUS=', '').Trim()
$minioNegativeCode = ($minioNegLine -replace '^MINIO_NEGATIVE_CODE=', '').Trim()

if ([int]$ttlValue -le 0) {
    throw "Authorized OpenBao login did not return a positive lease TTL: $ttlValue"
}

if ($secretValue -ne $OpenBaoSecretValue) {
    throw "OpenBao authorized secret mismatch. Expected '$OpenBaoSecretValue' but got '$secretValue'"
}

if ($deniedCode -eq '0') {
    throw 'OpenBao unauthorized login unexpectedly succeeded.'
}

if ($minioStatus -ne 'success') {
    throw "MinIO temporary access key creation did not report success: $minioStatus"
}

if ($minioNegativeCode -eq '0') {
    throw 'MinIO negative check unexpectedly succeeded with wrong secret.'
}

Write-Host "OpenBao authorized lease TTL: $ttlValue"
Write-Host "OpenBao authorized secret value: $secretValue"
Write-Host "OpenBao unauthorized login exit code: $deniedCode"
Write-Host "MinIO temporary access-key status: $minioStatus"
Write-Host "MinIO negative check exit code: $minioNegativeCode"
Write-Host 'Week 6 execution slice completed'
