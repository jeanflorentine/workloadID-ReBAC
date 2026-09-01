param(
    [string]$TargetPlatform = 'local-hypervisor'
)

Write-Host 'Orange Lab 1 workstation bootstrap'
Write-Host "Selected target platform: $TargetPlatform"
Write-Host ''
Write-Host 'Recommended sequence:'
Write-Host '1. Run scripts/check-prereqs.ps1'
Write-Host '2. Copy tofu/envs/lab1/terraform.tfvars.example to terraform.tfvars'
Write-Host '3. Copy tofu/envs/lab1/backend.hcl.example to backend.hcl if needed'
Write-Host '4. Review docs/portability_strategy.md and docs/local_hypervisor_decision.md'
Write-Host '5. Initialize the chosen IaC tool in tofu/envs/lab1'
