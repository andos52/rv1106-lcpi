[CmdletBinding()]
param(
    [string]$Image,
    [string]$Tool = "C:\Users\yoy70\SocToolKit\bin\windows\upgrade_tool.exe",
    [switch]$ListOnly,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
    Write-Host "flash-usb: ERROR: $Message" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path -LiteralPath $Tool)) {
    Fail "upgrade_tool not found: $Tool"
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "flash-usb: WARN: not elevated; Maskrom access usually needs Administrator." -ForegroundColor Yellow
}

Write-Host "flash-usb: tool: $Tool"
& $Tool -v
if ($LASTEXITCODE -ne 0) { Fail "upgrade_tool -v failed with exit code $LASTEXITCODE" }

Write-Host "flash-usb: scanning for Rockchip Maskrom/Loader devices"
$devices = (& $Tool ld 2>&1 | Out-String)
$devices.Trim() | Write-Host

if ($ListOnly) { exit 0 }

$hasDevice = $devices -match '(?i)maskrom|loader'
if (-not $hasDevice) {
    if (-not $Force) {
        Fail "no Maskrom/Loader device found. Put the board into flash mode (BOOT + USB, or 'reboot loader') and retry. Use -Force to try anyway."
    }
    Write-Host "flash-usb: WARN: no Maskrom/Loader detected, continuing because -Force is set." -ForegroundColor Yellow
}

if ([string]::IsNullOrWhiteSpace($Image)) {
    Fail "specify -Image <update.img>"
}
if (-not (Test-Path -LiteralPath $Image)) {
    Fail "image not found: $Image"
}
$Image = (Resolve-Path -LiteralPath $Image).Path
$size = (Get-Item -LiteralPath $Image).Length
Write-Host ("flash-usb: image: {0} ({1:N0} bytes)" -f $Image, $size)
Write-Host ("flash-usb: sha256: {0}" -f (Get-FileHash -LiteralPath $Image -Algorithm SHA256).Hash.ToLower())

if (-not $Force) {
    $answer = Read-Host "Type FLASH to write this image to the board"
    if ($answer -ne 'FLASH') { Fail "aborted by user" }
}

Write-Host "flash-usb: flashing (do not disconnect USB/power)"
& $Tool uf $Image
$code = $LASTEXITCODE
if ($code -ne 0) { Fail "upgrade_tool uf failed with exit code $code" }

Write-Host "flash-usb: done. Power-cycle the board and check the UART log." -ForegroundColor Green
