param(
    [ValidateSet('bootstrap','sync','validate','plan','apply')]
    [string]$Action,
    [string]$TargetHost = '192.168.1.210',
    [string]$SshUser = 'debian',
    [string]$SshKeyPath = 'C:/Users/jflorentin/.ssh/orange_lab1_bootstrap_ed25519',
    [string]$LocalTofuPath = 'C:/Projects/Orange-Lab1/tofu',
    [string]$RemoteWorkspacePath = '/home/debian/Orange-Lab1',
    [string]$RemoteEnvPath = '/home/debian/Orange-Lab1/envs/lab1',
    [string]$KubeconfigOverride = '/home/debian/Orange-Lab1/envs/lab1/orange-lab1.yaml',
    [string]$ProxmoxUsername = 'root@pam',
    [string]$LocalProxmoxPasswordEnvVar = 'PROXMOX_VE_PASSWORD',
    [string]$LocalProxmoxApiTokenEnvVar = 'PROXMOX_VE_API_TOKEN',
    [switch]$AutoApprove
)

$ErrorActionPreference = 'Stop'

function Invoke-Remote {
    param([string]$Command)

    & ssh -i $SshKeyPath -p 22 "$SshUser@$TargetHost" $Command
    if ($LASTEXITCODE -ne 0) {
        throw "Remote command failed: $Command"
    }
}

function Copy-ToRemote {
    param(
        [string]$LocalPath,
        [string]$RemotePath
    )

    & scp -r -i $SshKeyPath -P 22 $LocalPath "${SshUser}@${TargetHost}:$RemotePath"
    if ($LASTEXITCODE -ne 0) {
        throw "Copy failed: $LocalPath -> $RemotePath"
    }
}

function ConvertTo-BashSingleQuoted {
    param([string]$Value)

    if ($null -eq $Value) {
        return "''"
    }

    if ($Value.Contains("'")) {
        throw 'Value contains a single quote which is not supported by this helper quoting mode.'
    }

    return "'$Value'"
}

function Get-ProxmoxEnvPrefix {
    $password = [Environment]::GetEnvironmentVariable($LocalProxmoxPasswordEnvVar)
    $apiToken = [Environment]::GetEnvironmentVariable($LocalProxmoxApiTokenEnvVar)

    if ([string]::IsNullOrWhiteSpace($password) -and [string]::IsNullOrWhiteSpace($apiToken)) {
        throw "Missing Proxmox secret in local shell. Set either $LocalProxmoxPasswordEnvVar or $LocalProxmoxApiTokenEnvVar in PowerShell, then rerun."
    }

    $parts = @("PROXMOX_VE_USERNAME=$(ConvertTo-BashSingleQuoted -Value $ProxmoxUsername)")

    if (-not [string]::IsNullOrWhiteSpace($password)) {
        $parts += "PROXMOX_VE_PASSWORD=$(ConvertTo-BashSingleQuoted -Value $password)"
    }

    if (-not [string]::IsNullOrWhiteSpace($apiToken)) {
        $parts += "PROXMOX_VE_API_TOKEN=$(ConvertTo-BashSingleQuoted -Value $apiToken)"
    }

    return ($parts -join ' ')
}

switch ($Action) {
    'bootstrap' {
        Write-Host 'Installing prerequisites and OpenTofu on the Debian VM'
        Invoke-Remote "sudo apt-get update && sudo apt-get install -y git gpg lsb-release ca-certificates"
        Invoke-Remote "sudo install -m 0755 -d /etc/apt/keyrings && curl -fsSL https://packages.opentofu.org/opentofu/tofu/gpgkey | sudo gpg --dearmor -o /etc/apt/keyrings/opentofu.gpg && sudo chmod a+r /etc/apt/keyrings/opentofu.gpg && echo 'deb [signed-by=/etc/apt/keyrings/opentofu.gpg] https://packages.opentofu.org/opentofu/tofu/any/ any main' | sudo tee /etc/apt/sources.list.d/opentofu.list >/dev/null && sudo apt-get update && sudo apt-get install -y tofu"
        Invoke-Remote 'tofu version'
    }
    'sync' {
        if (-not (Test-Path -LiteralPath $LocalTofuPath)) {
            throw "Local path not found: $LocalTofuPath"
        }

        Write-Host "Copying $LocalTofuPath to $RemoteWorkspacePath"
        Copy-ToRemote -LocalPath $LocalTofuPath -RemotePath $RemoteWorkspacePath
    }
    'validate' {
        Write-Host 'Running remote init + validate in lab1 environment'
        Invoke-Remote "cd $RemoteEnvPath && rm -rf .terraform && tofu init -backend=false -input=false -no-color && tofu validate -no-color"
    }
    'plan' {
        $proxmoxEnvPrefix = Get-ProxmoxEnvPrefix
        Write-Host 'Running remote plan with Linux-safe kubeconfig override'
        Invoke-Remote "cd $RemoteEnvPath && $proxmoxEnvPrefix tofu plan -refresh=false -input=false -no-color -var-file=terraform.tfvars -var 'kubeconfig_path=$KubeconfigOverride'"
    }
    'apply' {
        $proxmoxEnvPrefix = Get-ProxmoxEnvPrefix
        if ($AutoApprove) {
            Write-Host 'Running remote apply with Linux-safe kubeconfig override (auto-approve enabled)'
            Invoke-Remote "cd $RemoteEnvPath && $proxmoxEnvPrefix tofu apply -refresh=false -input=false -no-color -auto-approve -var-file=terraform.tfvars -var 'kubeconfig_path=$KubeconfigOverride'"
        }
        else {
            Write-Host 'Running remote apply with Linux-safe kubeconfig override (interactive approval on VM)'
            Invoke-Remote "cd $RemoteEnvPath && $proxmoxEnvPrefix tofu apply -refresh=false -input=false -no-color -var-file=terraform.tfvars -var 'kubeconfig_path=$KubeconfigOverride'"
        }
    }
}
