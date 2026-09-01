param(
    [string]$KubeContext = ''
)

Write-Host 'Smoke test checklist'
Write-Host '1. Confirm the VM is reachable.'
Write-Host '2. Confirm kubectl can access the cluster.'
Write-Host '3. Confirm the node is Ready.'
Write-Host '4. Confirm Keycloak and one supporting component are healthy.'

if ($KubeContext) {
    Write-Host "Requested kube context: $KubeContext"
}
