$tools = @(
    'git',
    'ssh',
    'kubectl',
    'helm',
    'tofu',
    'terraform'
)

$results = foreach ($tool in $tools) {
    $command = Get-Command $tool -ErrorAction SilentlyContinue
    [pscustomobject]@{
        Tool  = $tool
        Found = [bool]$command
        Path  = if ($command) { $command.Source } else { '' }
    }
}

$results | Format-Table -AutoSize
