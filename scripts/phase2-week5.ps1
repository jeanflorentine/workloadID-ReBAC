param(
    [string]$TargetHost = '192.168.1.210',
    [string]$SshUser = 'debian',
    [string]$SshKeyPath = 'C:/Users/jflorentin/.ssh/orange_lab1_bootstrap_ed25519',
    [string]$ManifestPath = '',
    [string]$SpireNamespace = 'identity',
    [string]$AllowedNamespace = 'authorization',
    [string]$AllowedDeploymentName = 'spire-demo-allowed',
    [string]$AllowedServiceAccount = 'spire-demo-allowed',
    [string]$DeniedNamespace = 'identity',
    [string]$DeniedDeploymentName = 'spire-demo-denied',
    [string]$DeniedServiceAccount = 'spire-demo-denied',
    [string]$TrustDomain = 'orange.lab',
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

if ([string]::IsNullOrWhiteSpace($ManifestPath)) {
    $ManifestPath = Join-Path $PSScriptRoot '..\kubernetes\overlays\lab1\week5-spire-identity-demo.yaml'
}

$resolvedManifestPath = (Resolve-Path -LiteralPath $ManifestPath).Path
$remoteManifestPath = '/tmp/week5-spire-identity-demo.yaml'

Write-Host 'Phase 2 Week 5 validation started'

Write-Host '1) Checking SPIRE control plane health'
Invoke-Remote "sudo k3s kubectl wait --for=condition=Ready pod -n $SpireNamespace -l app.kubernetes.io/instance=spire --timeout=${TimeoutSeconds}s"
Invoke-Remote "sudo k3s kubectl -n $SpireNamespace get pods -o wide"

Write-Host '2) Applying Week 5 SPIRE identity demo workloads'
Copy-ManifestToRemote -LocalPath $resolvedManifestPath -RemotePath $remoteManifestPath
Invoke-Remote "sudo k3s kubectl apply -f $remoteManifestPath"
Invoke-Remote "sudo k3s kubectl -n $AllowedNamespace rollout status deploy/$AllowedDeploymentName --timeout=${TimeoutSeconds}s"
Invoke-Remote "sudo k3s kubectl -n $DeniedNamespace rollout status deploy/$DeniedDeploymentName --timeout=${TimeoutSeconds}s"

Write-Host '3) Inspecting SPIRE registration entries'
$entriesOutput = Invoke-Remote "sudo k3s kubectl -n $SpireNamespace exec statefulset/spire-server -c spire-server -- /opt/spire/bin/spire-server entry show"
$entriesOutput | Write-Host

$allowedSpiffeId = "spiffe://$TrustDomain/ns/$AllowedNamespace/sa/$AllowedServiceAccount"
$deniedSpiffeId = "spiffe://$TrustDomain/ns/$DeniedNamespace/sa/$DeniedServiceAccount"

$hasAllowedEntry = $entriesOutput -match [regex]::Escape($allowedSpiffeId)
$hasDeniedEntry = $entriesOutput -match [regex]::Escape($deniedSpiffeId)

if (-not $hasAllowedEntry) {
    throw "Expected SPIRE entry for allowed workload was not found: $allowedSpiffeId"
}

if ($hasDeniedEntry) {
    throw "Denied workload unexpectedly received a SPIRE entry: $deniedSpiffeId"
}

Write-Host '4) Inspecting SPIRE trust bundle'
$bundleOutput = Invoke-Remote "sudo k3s kubectl -n $SpireNamespace exec statefulset/spire-server -c spire-server -- /opt/spire/bin/spire-server bundle show"
$bundleOutput | Write-Host

if (-not ($bundleOutput -match 'BEGIN CERTIFICATE')) {
    throw 'SPIRE trust bundle output did not include an X.509 certificate.'
}

Write-Host 'WEEK5_SPIRE_ALLOWED_ENTRY=true'
Write-Host 'WEEK5_SPIRE_DENIED_ENTRY=false'
Write-Host "WEEK5_SPIRE_ALLOWED_ID=$allowedSpiffeId"
Write-Host "WEEK5_SPIRE_DENIED_ID=$deniedSpiffeId"
Write-Host 'Week 5 execution slice completed'
