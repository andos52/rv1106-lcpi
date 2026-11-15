[CmdletBinding()]
param(
    [int]$Minutes = 5
)

$ErrorActionPreference = 'Stop'

$script = Join-Path $PSScriptRoot 'status.sh'
if (-not (Test-Path -LiteralPath $script)) {
    throw "status.sh not found: $script"
}

$drive = $script.Substring(0, 1).ToLower()
$linuxPath = "/mnt/$drive/" + $script.Substring(2).Replace('\', '/')

& wsl -d Ubuntu bash $linuxPath $Minutes
