param(
    [string]$TargetHost = '192.168.1.210',
    [string]$SshUser = 'debian',
    [string]$SshKeyPath = 'C:/Users/jflorentin/.ssh/orange_lab1_bootstrap_ed25519',
    [string]$ManifestPath = '',
    [string]$Namespace = 'identity',
    [string]$DeploymentName = 'workload-identity-demo',
    [string]$ServiceAccountName = 'workload-identity-demo',
    [string]$ProjectedTokenFile = 'workload-identity-demo.jwt',
    [string]$ProjectedTokenAudience = 'workload-identity-demo',
    [string]$KeycloakAdminUser = 'admin',
    [string]$KeycloakAdminPassword = 'ChangeMe-OrangeLab1!',
    [string]$TokenExchangeRealm = 'workload-identity',
    [string]$TokenExchangeClientId = 'requester-client',
    [string]$TokenExchangeClientSecret = 'secret',
    [string]$TokenExchangeTargetClientId = 'target-client1',
    [string]$TokenExchangeSubjectIssuerAlias = 'k8s-cluster-issuer',
    [string]$TokenExchangeNegativeAudience = 'downstream-api-invalid',
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

function Ensure-KeycloakTokenExchangeFeature {
    param([string]$Namespace)

    $currentExtraArgs = Invoke-Remote ('sudo k3s kubectl -n {0} set env statefulset/keycloak --list | grep "^KEYCLOAK_EXTRA_ARGS="' -f $Namespace)
    $hasAuthorization = $currentExtraArgs -match '(^|[\s,=])authorization(?::v1)?($|[\s,])' -or $currentExtraArgs -match '(^|\s)--feature-authorization=enabled(\s|$)'
    $hasTokenExchange = $currentExtraArgs -match '(^|[\s,=])token-exchange(?::v1)?($|[\s,])' -or $currentExtraArgs -match '(^|[\s,=])token-exchange-standard(?::v2)?($|[\s,])' -or $currentExtraArgs -match '(^|\s)--feature-token-exchange=enabled(\s|$)' -or $currentExtraArgs -match '(^|\s)--feature-token-exchange-standard=enabled(\s|$)'
    $hasAdminFineGrainedAuthz = $currentExtraArgs -match '(^|[\s,=])admin-fine-grained-authz(?::v2)?($|[\s,])' -or $currentExtraArgs -match '(^|\s)--feature-admin-fine-grained-authz=enabled(\s|$)'
    $requiresUpdate = -not ($hasAuthorization -and $hasTokenExchange -and $hasAdminFineGrainedAuthz)

    if (-not $requiresUpdate) {
        Write-Host 'Keycloak authorization, token-exchange, and admin fine-grained authz features already enabled'
        return
    }

    Write-Host 'Enabling Keycloak authorization, token-exchange, and admin fine-grained authz feature flags'
    Invoke-Remote "sudo k3s kubectl -n $Namespace set env statefulset/keycloak KEYCLOAK_EXTRA_ARGS='--features=authorization,admin-fine-grained-authz,token-exchange'"
    Invoke-Remote "sudo k3s kubectl -n $Namespace rollout status statefulset/keycloak --timeout=${TimeoutSeconds}s"
}

function Invoke-Rfc8693Suite {
        param(
                [string]$WorkloadNamespace,
                [string]$WorkloadDeploymentName,
                [string]$WorkloadTokenFile,
                [string]$Realm,
                [string]$ClientId,
                [string]$ClientSecret,
                [string]$TargetClientId,
                [string]$SubjectIssuerAlias,
                [string]$NegativeAudience,
                [string]$ApiServerIssuer,
                [string]$ApiServerJwksUri,
                [string]$AdminUser,
                [string]$AdminPassword
        )

        $localScriptPath = [System.IO.Path]::GetTempFileName()
        $remoteScriptPath = '/tmp/week4-rfc8693-suite.sh'

        $scriptTemplate = @'
#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="__NAMESPACE__"
WORKLOAD_DEPLOYMENT="__WORKLOAD_DEPLOYMENT__"
WORKLOAD_TOKEN_FILE="__WORKLOAD_TOKEN_FILE__"

REALM="__REALM__"
CLIENT_ID="__CLIENT_ID__"
CLIENT_SECRET="__CLIENT_SECRET__"
TARGET_CLIENT_ID="__TARGET_CLIENT_ID__"
SUBJECT_ISSUER_ALIAS="__SUBJECT_ISSUER_ALIAS__"
NEGATIVE_AUDIENCE="__NEGATIVE_AUDIENCE__"

APISERVER_ISSUER="__APISERVER_ISSUER__"
APISERVER_JWKS_URI="__APISERVER_JWKS_URI__"

ADMIN_USER="__ADMIN_USER__"
ADMIN_PASSWORD="__ADMIN_PASSWORD__"

kexec() {
    sudo k3s kubectl -n "$NAMESPACE" exec -i keycloak-0 -- "$@"
}

ksh() {
    sudo k3s kubectl -n "$NAMESPACE" exec keycloak-0 -- sh -lc "$1"
}

KCADM="/opt/bitnami/keycloak/bin/kcadm.sh"

kexec "$KCADM" config credentials \
    --config /tmp/kcadm.config \
    --server http://127.0.0.1:8080 \
    --realm master \
    --user "$ADMIN_USER" \
    --password "$ADMIN_PASSWORD" >/dev/null

kexec "$KCADM" delete "realms/$REALM" --config /tmp/kcadm.config >/dev/null 2>&1 || true
kexec "$KCADM" create realms --config /tmp/kcadm.config -s realm="$REALM" -s enabled=true >/dev/null

kexec "$KCADM" create client-scopes -r "$REALM" --config /tmp/kcadm.config \
    -s name=default-scope1 \
    -s protocol=openid-connect \
    -s 'attributes."include.in.token.scope"=true' >/dev/null

SUBJECT_CLIENT_ID="subject-client"

kexec "$KCADM" create clients -r "$REALM" --config /tmp/kcadm.config \
    -s clientId="$SUBJECT_CLIENT_ID" \
    -s enabled=true \
    -s protocol=openid-connect \
    -s publicClient=false \
    -s secret="secret" \
    -s fullScopeAllowed=false \
    -s 'attributes."standard.token.exchange.enabled"=true' \
    -s standardFlowEnabled=false \
    -s directAccessGrantsEnabled=true \
    -s serviceAccountsEnabled=true \
    -s 'defaultClientScopes=["service_account","acr","default-scope1","roles","basic"]' >/dev/null

kexec "$KCADM" create clients -r "$REALM" --config /tmp/kcadm.config \
    -s clientId="$CLIENT_ID" \
    -s enabled=true \
    -s protocol=openid-connect \
    -s publicClient=false \
    -s secret="$CLIENT_SECRET" \
    -s fullScopeAllowed=false \
    -s 'attributes."standard.token.exchange.enabled"=true' \
    -s standardFlowEnabled=false \
    -s directAccessGrantsEnabled=true \
    -s serviceAccountsEnabled=true \
    -s 'defaultClientScopes=["service_account","acr","default-scope1","roles","basic"]' >/dev/null

kexec "$KCADM" create clients -r "$REALM" --config /tmp/kcadm.config \
    -s clientId="$TARGET_CLIENT_ID" \
    -s enabled=true \
    -s protocol=openid-connect \
    -s publicClient=false \
    -s secret="$CLIENT_SECRET" \
    -s authorizationServicesEnabled=true \
    -s standardFlowEnabled=false \
    -s directAccessGrantsEnabled=false \
    -s serviceAccountsEnabled=true \
    -s fullScopeAllowed=false \
    -s 'defaultClientScopes=["acr","roles","basic"]' >/dev/null

kexec "$KCADM" create clients -r "$REALM" --config /tmp/kcadm.config \
    -s clientId=target-client2 \
    -s enabled=true \
    -s protocol=openid-connect \
    -s publicClient=true \
    -s standardFlowEnabled=false \
    -s directAccessGrantsEnabled=false \
    -s 'defaultClientScopes=["acr","roles","basic"]' >/dev/null

REQUESTER_CLIENT_UUID="$(kexec "$KCADM" get clients -r "$REALM" --config /tmp/kcadm.config -q clientId="$CLIENT_ID" --fields id,clientId | tr -d '[:space:]' | sed -n "s/.*\"id\":\"\([^\"]*\)\",\"clientId\":\"$CLIENT_ID\".*/\1/p" | head -n1)"
SUBJECT_CLIENT_UUID="$(kexec "$KCADM" get clients -r "$REALM" --config /tmp/kcadm.config -q clientId="$SUBJECT_CLIENT_ID" --fields id,clientId | tr -d '[:space:]' | sed -n "s/.*\"id\":\"\([^\"]*\)\",\"clientId\":\"$SUBJECT_CLIENT_ID\".*/\1/p" | head -n1)"
TARGET_CLIENT_UUID="$(kexec "$KCADM" get clients -r "$REALM" --config /tmp/kcadm.config -q clientId="$TARGET_CLIENT_ID" --fields id,clientId | tr -d '[:space:]' | sed -n "s/.*\"id\":\"\([^\"]*\)\",\"clientId\":\"$TARGET_CLIENT_ID\".*/\1/p" | head -n1)"
SCOPE_UUID="$(kexec "$KCADM" get client-scopes -r "$REALM" --config /tmp/kcadm.config -q name=default-scope1 --fields id,name | tr -d '[:space:]' | sed -n 's/.*"id":"\([^\"]*\)","name":"default-scope1".*/\1/p' | head -n1)"
REALM_MANAGEMENT_CLIENT_UUID="$(kexec "$KCADM" get clients -r "$REALM" --config /tmp/kcadm.config -q clientId=realm-management --fields id,clientId | tr -d '[:space:]' | sed -n 's/.*"id":"\([^"]*\)","clientId":"realm-management".*/\1/p' | head -n1)"

kexec "$KCADM" update "clients/$TARGET_CLIENT_UUID/management/permissions" -r "$REALM" --config /tmp/kcadm.config -s enabled=true >/dev/null
TOKEN_EXCHANGE_PERMISSION_ID="$(kexec "$KCADM" get "clients/$TARGET_CLIENT_UUID/management/permissions" -r "$REALM" --config /tmp/kcadm.config | tr -d '[:space:]' | sed -n 's/.*"token-exchange":"\([^"]*\)".*/\1/p' | head -n1)"

if [[ -z "$REQUESTER_CLIENT_UUID" || -z "$SUBJECT_CLIENT_UUID" || -z "$TARGET_CLIENT_UUID" || -z "$SCOPE_UUID" || -z "$REALM_MANAGEMENT_CLIENT_UUID" || -z "$TOKEN_EXCHANGE_PERMISSION_ID" ]]; then
    echo 'Failed to resolve one or more Keycloak UUIDs for the token-exchange fixture' >&2
    echo "REQUESTER_CLIENT_UUID=$REQUESTER_CLIENT_UUID" >&2
    echo "SUBJECT_CLIENT_UUID=$SUBJECT_CLIENT_UUID" >&2
    echo "TARGET_CLIENT_UUID=$TARGET_CLIENT_UUID" >&2
    echo "SCOPE_UUID=$SCOPE_UUID" >&2
    echo "REALM_MANAGEMENT_CLIENT_UUID=$REALM_MANAGEMENT_CLIENT_UUID" >&2
    echo "TOKEN_EXCHANGE_PERMISSION_ID=$TOKEN_EXCHANGE_PERMISSION_ID" >&2
    exit 1
fi

kexec "$KCADM" create "clients/$TARGET_CLIENT_UUID/roles" -r "$REALM" --config /tmp/kcadm.config \
    -s name="${TARGET_CLIENT_ID}-role" >/dev/null

kexec "$KCADM" add-roles -r "$REALM" --config /tmp/kcadm.config \
    --uusername "service-account-$SUBJECT_CLIENT_ID" \
    --cclientid "$TARGET_CLIENT_ID" \
    --rolename "${TARGET_CLIENT_ID}-role" >/dev/null

printf '%s' "{\"name\":\"requester-client-policy\",\"description\":\"Allow requester-client to exchange tokens\",\"clients\":[\"$REQUESTER_CLIENT_UUID\"]}" | kexec sh -c 'cat >/tmp/requester-client-policy.json'
kexec "$KCADM" create "clients/$REALM_MANAGEMENT_CLIENT_UUID/authz/resource-server/policy/client" -r "$REALM" --config /tmp/kcadm.config -f /tmp/requester-client-policy.json >/dev/null

kexec "$KCADM" update "clients/$REALM_MANAGEMENT_CLIENT_UUID/authz/resource-server/permission/scope/$TOKEN_EXCHANGE_PERMISSION_ID" -r "$REALM" --config /tmp/kcadm.config -s 'policies=["requester-client-policy"]' >/dev/null

printf '%s' '{"name":"audience-requester-client","protocol":"openid-connect","protocolMapper":"oidc-audience-mapper","config":{"included.client.audience":"requester-client","id.token.claim":"false","lightweight.claim":"false","access.token.claim":"true","introspection.token.claim":"true"}}' | kexec sh -c 'cat >/tmp/subject-audience.json'
kexec "$KCADM" create "clients/$SUBJECT_CLIENT_UUID/protocol-mappers/models" -r "$REALM" --config /tmp/kcadm.config -f /tmp/subject-audience.json >/dev/null

SUBJECT_TOKEN_RESPONSE="$(ksh "curl -sS -X POST http://127.0.0.1:8080/realms/$REALM/protocol/openid-connect/token -H 'Content-Type: application/x-www-form-urlencoded' --data-urlencode 'grant_type=client_credentials' --data-urlencode 'client_id=$SUBJECT_CLIENT_ID' --data-urlencode 'client_secret=secret'")"
echo "SUBJECT_TOKEN_RESPONSE_BEGIN"
echo "$SUBJECT_TOKEN_RESPONSE"
echo "SUBJECT_TOKEN_RESPONSE_END"
SUBJECT_TOKEN="$(printf '%s' "$SUBJECT_TOKEN_RESPONSE" | sed -n 's/.*\"access_token\":\"\([^\"]*\)\".*/\1/p')"
if [[ -z "$SUBJECT_TOKEN" ]]; then
    echo 'Failed to extract subject token access_token from Keycloak response.' >&2
    exit 1
fi

SUBJECT_CLAIMS_JSON="$(python3 -c 'import base64, json, sys; token = sys.argv[1].strip(); parts = token.split(".");
if len(parts) < 2: raise SystemExit("subject token is not a JWT");
payload = parts[1] + "=" * (-len(parts[1]) % 4);
claims = json.loads(base64.urlsafe_b64decode(payload.encode("ascii")));
print(json.dumps(claims, separators=(",", ":")))' "$SUBJECT_TOKEN")"
echo "SUBJECT_TOKEN_CLAIMS=$SUBJECT_CLAIMS_JSON"
echo "SUBJECT_TOKEN_DETAILS_BEGIN"
python3 -c 'import json, sys; claims = json.loads(sys.argv[1]); aud = claims.get("aud", []); aud = aud if isinstance(aud, list) else [aud]; print("issuer={0}".format(claims.get("iss", ""))); print("subject={0}".format(claims.get("sub", ""))); print("aud={0}".format(",".join(aud))); print("azp={0}".format(claims.get("azp", ""))); print("scope={0}".format(claims.get("scope", "")))' "$SUBJECT_CLAIMS_JSON"
echo "SUBJECT_TOKEN_DETAILS_END"
python3 -c 'import json, sys; claims = json.loads(sys.argv[1]); aud = claims.get("aud", []); aud = aud if isinstance(aud, list) else [aud]; print("SUBJECT_TOKEN_SUMMARY issuer={0} subject={1} aud={2} azp={3} scope={4}".format(claims.get("iss", ""), claims.get("sub", ""), ",".join(aud), claims.get("azp", ""), claims.get("scope", "")))' "$SUBJECT_CLAIMS_JSON"

POSITIVE_STATUS="$(ksh "curl -sS -o /tmp/rfc8693-positive.json -w '%{http_code}' -X POST http://127.0.0.1:8080/realms/$REALM/protocol/openid-connect/token -H 'Content-Type: application/x-www-form-urlencoded' --data-urlencode 'grant_type=urn:ietf:params:oauth:grant-type:token-exchange' --data-urlencode 'client_id=$CLIENT_ID' --data-urlencode 'client_secret=$CLIENT_SECRET' --data-urlencode 'subject_token=$SUBJECT_TOKEN' --data-urlencode 'subject_token_type=urn:ietf:params:oauth:token-type:access_token' --data-urlencode 'requested_token_type=urn:ietf:params:oauth:token-type:access_token' --data-urlencode 'audience=$TARGET_CLIENT_ID'")"
POSITIVE_BODY="$(kexec cat /tmp/rfc8693-positive.json)"
EXCHANGED_TOKEN=""
if [[ "$POSITIVE_STATUS" == "200" ]]; then
    EXCHANGED_TOKEN="$(printf '%s' "$POSITIVE_BODY" | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p')"
fi

NEGATIVE_STATUS="$(ksh "curl -sS -o /tmp/rfc8693-negative.json -w '%{http_code}' -X POST http://127.0.0.1:8080/realms/$REALM/protocol/openid-connect/token -H 'Content-Type: application/x-www-form-urlencoded' --data-urlencode 'grant_type=urn:ietf:params:oauth:grant-type:token-exchange' --data-urlencode 'client_id=$CLIENT_ID' --data-urlencode 'client_secret=$CLIENT_SECRET' --data-urlencode 'subject_token=$SUBJECT_TOKEN' --data-urlencode 'subject_token_type=urn:ietf:params:oauth:token-type:access_token' --data-urlencode 'requested_token_type=urn:ietf:params:oauth:token-type:access_token' --data-urlencode 'audience=$NEGATIVE_AUDIENCE'")"

echo "RFC8693_POSITIVE_HTTP=$POSITIVE_STATUS"
echo "RFC8693_NEGATIVE_HTTP=$NEGATIVE_STATUS"
echo "RFC8693_EXCHANGED_TOKEN=$EXCHANGED_TOKEN"
echo "RFC8693_POSITIVE_BODY_BEGIN"
echo "$POSITIVE_BODY"
echo "RFC8693_POSITIVE_BODY_END"
echo "RFC8693_NEGATIVE_BODY_BEGIN"
kexec cat /tmp/rfc8693-negative.json
echo "RFC8693_NEGATIVE_BODY_END"
'@

        $scriptContent = $scriptTemplate
        $scriptContent = $scriptContent.Replace('__NAMESPACE__', $WorkloadNamespace)
        $scriptContent = $scriptContent.Replace('__WORKLOAD_DEPLOYMENT__', $WorkloadDeploymentName)
        $scriptContent = $scriptContent.Replace('__WORKLOAD_TOKEN_FILE__', $WorkloadTokenFile)
        $scriptContent = $scriptContent.Replace('__REALM__', $Realm)
        $scriptContent = $scriptContent.Replace('__CLIENT_ID__', $ClientId)
        $scriptContent = $scriptContent.Replace('__CLIENT_SECRET__', $ClientSecret)
        $scriptContent = $scriptContent.Replace('__TARGET_CLIENT_ID__', $TargetClientId)
        $scriptContent = $scriptContent.Replace('__SUBJECT_ISSUER_ALIAS__', $SubjectIssuerAlias)
        $scriptContent = $scriptContent.Replace('__NEGATIVE_AUDIENCE__', $NegativeAudience)
        $scriptContent = $scriptContent.Replace('__APISERVER_ISSUER__', $ApiServerIssuer)
        $scriptContent = $scriptContent.Replace('__APISERVER_JWKS_URI__', $ApiServerJwksUri)
        $scriptContent = $scriptContent.Replace('__ADMIN_USER__', $AdminUser)
        $scriptContent = $scriptContent.Replace('__ADMIN_PASSWORD__', $AdminPassword)

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

function Get-JwtPayloadClaims {
    param([string]$Jwt)

    $parts = $Jwt.Trim().Split('.')
    if ($parts.Count -lt 2) {
        throw 'The projected token is not a valid JWT.'
    }

    $payload = $parts[1].Replace('-', '+').Replace('_', '/')
    switch ($payload.Length % 4) {
        0 { }
        2 { $payload += '==' }
        3 { $payload += '=' }
        default { throw 'The projected token payload is not valid base64url.' }
    }

    $json = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($payload))
    return $json | ConvertFrom-Json
}

if ([string]::IsNullOrWhiteSpace($ManifestPath)) {
    $ManifestPath = Join-Path $PSScriptRoot '..\kubernetes\overlays\lab1\week4-workload-identity-demo.yaml'
}

$resolvedManifestPath = (Resolve-Path -LiteralPath $ManifestPath).Path
$remoteManifestPath = '/tmp/week4-workload-identity-demo.yaml'

Write-Host 'Phase 2 Week 4 validation started'

Write-Host '1) Cluster OIDC discovery document'
$oidcDiscovery = Invoke-Remote 'sudo k3s kubectl get --raw /.well-known/openid-configuration'
$oidcDiscovery | Write-Host
$oidcConfig = $oidcDiscovery | ConvertFrom-Json

Write-Host '2) Cluster JWKS document'
$jwks = Invoke-Remote 'sudo k3s kubectl get --raw /openid/v1/jwks'
$jwks | Write-Host

Write-Host '3) Applying the projected-token demo workload'
Copy-ManifestToRemote -LocalPath $resolvedManifestPath -RemotePath $remoteManifestPath
Invoke-Remote "sudo k3s kubectl apply -f $remoteManifestPath"
Invoke-Remote "sudo k3s kubectl -n $Namespace rollout status deploy/$DeploymentName --timeout=${TimeoutSeconds}s"

Write-Host '4) Reading the projected token from the demo workload'
$projectedToken = Invoke-Remote "sudo k3s kubectl -n $Namespace exec deploy/$DeploymentName -- cat /var/run/secrets/tokens/$ProjectedTokenFile"
$claims = Get-JwtPayloadClaims -Jwt $projectedToken

if ($claims.iss -ne 'https://kubernetes.default.svc.cluster.local') {
    throw "Unexpected JWT issuer: $($claims.iss)"
}

$expectedSubject = "system:serviceaccount:${Namespace}:${ServiceAccountName}"
if ($claims.sub -ne $expectedSubject) {
    throw "Unexpected JWT subject: $($claims.sub)"
}

$audiences = @($claims.aud)
if (-not ($audiences -contains $ProjectedTokenAudience)) {
    throw "Projected token audience missing expected value: $ProjectedTokenAudience"
}

if (-not $claims.exp) {
    throw 'Projected token is missing an exp claim.'
}

Write-Host "Projected token issuer: $($claims.iss)"
Write-Host "Projected token subject: $($claims.sub)"
Write-Host "Projected token audience: $($audiences -join ', ')"
Write-Host "Projected token exp: $($claims.exp)"

Write-Host '5) Validating Keycloak admin automation path'
Invoke-Remote "sudo k3s kubectl -n $Namespace exec keycloak-0 -- /opt/bitnami/keycloak/bin/kcadm.sh config credentials --config /tmp/kcadm.config --server http://127.0.0.1:8080 --realm master --user $KeycloakAdminUser --password '$KeycloakAdminPassword' >/dev/null"

Write-Host '6) Ensuring Keycloak token-exchange feature is enabled'
Ensure-KeycloakTokenExchangeFeature -Namespace $Namespace

Write-Host '7) Seeding Keycloak and running RFC 8693 token exchange tests'
$rfc8693Output = Invoke-Rfc8693Suite `
    -WorkloadNamespace $Namespace `
    -WorkloadDeploymentName $DeploymentName `
    -WorkloadTokenFile $ProjectedTokenFile `
    -Realm $TokenExchangeRealm `
    -ClientId $TokenExchangeClientId `
    -ClientSecret $TokenExchangeClientSecret `
    -TargetClientId $TokenExchangeTargetClientId `
    -SubjectIssuerAlias $TokenExchangeSubjectIssuerAlias `
    -NegativeAudience $TokenExchangeNegativeAudience `
    -ApiServerIssuer $oidcConfig.issuer `
    -ApiServerJwksUri $oidcConfig.jwks_uri `
    -AdminUser $KeycloakAdminUser `
    -AdminPassword $KeycloakAdminPassword

$rfc8693Output | Write-Host

$positiveHttp = ($rfc8693Output | Where-Object { $_ -match '^RFC8693_POSITIVE_HTTP=' } | Select-Object -Last 1)
$negativeHttp = ($rfc8693Output | Where-Object { $_ -match '^RFC8693_NEGATIVE_HTTP=' } | Select-Object -Last 1)
$exchangedTokenLine = ($rfc8693Output | Where-Object { $_ -match '^RFC8693_EXCHANGED_TOKEN=' } | Select-Object -Last 1)
$positiveBodyStart = $rfc8693Output.IndexOf('RFC8693_POSITIVE_BODY_BEGIN')
$positiveBodyEnd = $rfc8693Output.IndexOf('RFC8693_POSITIVE_BODY_END')

if (-not $positiveHttp) {
    throw 'Missing positive RFC 8693 HTTP status marker in test output.'
}

if (-not $negativeHttp) {
    throw 'Missing negative RFC 8693 HTTP status marker in test output.'
}

if (-not $exchangedTokenLine) {
    throw 'Missing exchanged token marker in RFC 8693 output.'
}

$positiveCode = ($positiveHttp -replace '^RFC8693_POSITIVE_HTTP=', '').Trim()
$negativeCode = ($negativeHttp -replace '^RFC8693_NEGATIVE_HTTP=', '').Trim()
$exchangedToken = ($exchangedTokenLine -replace '^RFC8693_EXCHANGED_TOKEN=', '').Trim()

if ($positiveCode -ne '200') {
    $positiveBody = ''
    if ($positiveBodyStart -ge 0 -and $positiveBodyEnd -gt $positiveBodyStart) {
        $positiveBody = (($rfc8693Output[($positiveBodyStart + 1)..($positiveBodyEnd - 1)]) -join "`n").Trim()
    }

    if ($positiveBody -match 'Client not allowed to exchange') {
        throw 'Positive RFC 8693 flow failed with HTTP 403: client is not allowed to exchange. In this Keycloak build, token-exchange permission grant is still required for the configured identity provider and target client.'
    }

    throw "Positive RFC 8693 flow failed with HTTP $positiveCode"
}

if ($negativeCode -eq '200') {
    throw 'Negative RFC 8693 flow unexpectedly returned HTTP 200.'
}

$exchangedClaims = Get-JwtPayloadClaims -Jwt $exchangedToken
$exchangedAudiences = @($exchangedClaims.aud)
if (-not ($exchangedAudiences -contains $TokenExchangeTargetClientId)) {
    throw "Exchanged token audience missing expected target: $TokenExchangeTargetClientId"
}

Write-Host "RFC 8693 positive flow HTTP: $positiveCode"
Write-Host "RFC 8693 negative flow HTTP: $negativeCode"
Write-Host "Exchanged token issuer: $($exchangedClaims.iss)"
Write-Host "Exchanged token subject: $($exchangedClaims.sub)"
Write-Host "Exchanged token audience: $($exchangedAudiences -join ', ')"

Write-Host 'Week 4 execution slice completed'