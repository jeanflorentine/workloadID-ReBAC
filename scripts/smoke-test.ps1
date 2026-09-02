param(
    [string]$TargetHost = '192.168.1.210',
    [string]$SshUser = 'debian',
    [string]$SshKeyPath = 'C:/Users/jflorentin/.ssh/orange_lab1_bootstrap_ed25519',
    [string]$Namespace = 'identity',
    [string]$ReleaseName = 'keycloak',
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

Write-Host 'Smoke test gate started'
Write-Host '1) Node inventory and readiness'
Invoke-Remote "sudo k3s kubectl get nodes -o wide"

Write-Host '2) Cluster pod overview'
Invoke-Remote "sudo k3s kubectl get pods -A"

Write-Host '3) Waiting for Keycloak components to become Ready'
Invoke-Remote "sudo k3s kubectl wait --for=condition=Ready pod -n $Namespace -l app.kubernetes.io/instance=$ReleaseName --timeout=${TimeoutSeconds}s"

Write-Host '4) Verifying service endpoint population'
$endpoint = Invoke-Remote "sudo k3s kubectl get endpoints -n $Namespace $ReleaseName -o jsonpath='{.subsets[0].addresses[0].ip}'"
if ([string]::IsNullOrWhiteSpace($endpoint)) {
    throw "No ready endpoint found for service $ReleaseName in namespace $Namespace"
}

Write-Host "5) App health check through service endpoint ($endpoint)"
Invoke-Remote "sudo k3s kubectl get --raw='/api/v1/namespaces/$Namespace/services/http:${ReleaseName}:80/proxy/realms/master/.well-known/openid-configuration' > /dev/null"

Write-Host 'Smoke test gate passed'
