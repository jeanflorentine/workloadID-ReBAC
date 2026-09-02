param(
    [string]$TargetHost = '192.168.1.210',
    [string]$SshUser = 'debian',
    [string]$SshKeyPath = 'C:/Users/jflorentin/.ssh/orange_lab1_bootstrap_ed25519',
    [string]$KeycloakNamespace = 'identity',
    [string]$KeycloakReleaseName = 'keycloak',
    [string]$SpireNamespace = 'identity',
    [string]$OpenBaoNamespace = 'secrets',
    [string]$MinIONamespace = 'storage',
    [string]$OpenFGANamespace = 'authorization',
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

function Wait-ForReadyPods {
    param(
        [string]$Namespace,
        [string]$LabelSelector,
        [string]$DisplayName
    )

    Write-Host "Waiting for $DisplayName pods to become Ready"
    Invoke-Remote "sudo k3s kubectl wait --for=condition=Ready pod -n $Namespace -l $LabelSelector --timeout=${TimeoutSeconds}s"
}

function Assert-ServiceEndpoint {
    param(
        [string]$Namespace,
        [string]$ServiceName,
        [string]$DisplayName
    )

    $endpoint = Invoke-Remote "sudo k3s kubectl get endpoints -n $Namespace $ServiceName -o jsonpath='{.subsets[0].addresses[0].ip}'"
    if ([string]::IsNullOrWhiteSpace($endpoint)) {
        throw "No ready endpoint found for $DisplayName service $ServiceName in namespace $Namespace"
    }

    Write-Host "$DisplayName endpoint: $endpoint"
}

Write-Host 'Smoke test gate started'
Write-Host '1) Node inventory and readiness'
Invoke-Remote "sudo k3s kubectl get nodes -o wide"

Write-Host '2) Cluster pod overview'
Invoke-Remote "sudo k3s kubectl get pods -A"

Write-Host '3) Waiting for platform workloads to become Ready'
Wait-ForReadyPods -Namespace $KeycloakNamespace -LabelSelector "app.kubernetes.io/instance=$KeycloakReleaseName" -DisplayName 'Keycloak'
Wait-ForReadyPods -Namespace $SpireNamespace -LabelSelector 'app.kubernetes.io/instance=spire' -DisplayName 'SPIRE'
Wait-ForReadyPods -Namespace $OpenBaoNamespace -LabelSelector 'app.kubernetes.io/instance=openbao' -DisplayName 'OpenBao'
Wait-ForReadyPods -Namespace $MinIONamespace -LabelSelector 'app.kubernetes.io/instance=minio' -DisplayName 'MinIO'
Wait-ForReadyPods -Namespace $OpenFGANamespace -LabelSelector 'app.kubernetes.io/instance=openfga' -DisplayName 'OpenFGA'

Write-Host '4) Verifying service endpoint population'
Assert-ServiceEndpoint -Namespace $KeycloakNamespace -ServiceName $KeycloakReleaseName -DisplayName 'Keycloak'
Assert-ServiceEndpoint -Namespace $SpireNamespace -ServiceName 'spire-server' -DisplayName 'SPIRE server'
Assert-ServiceEndpoint -Namespace $OpenBaoNamespace -ServiceName 'openbao' -DisplayName 'OpenBao'
Assert-ServiceEndpoint -Namespace $MinIONamespace -ServiceName 'minio' -DisplayName 'MinIO'
Assert-ServiceEndpoint -Namespace $OpenFGANamespace -ServiceName 'openfga' -DisplayName 'OpenFGA'

Write-Host '5) Keycloak OIDC health check through the API server proxy'
Invoke-Remote "sudo k3s kubectl get --raw='/api/v1/namespaces/$KeycloakNamespace/services/http:${KeycloakReleaseName}:80/proxy/realms/master/.well-known/openid-configuration' > /dev/null"

Write-Host 'Smoke test gate passed'
