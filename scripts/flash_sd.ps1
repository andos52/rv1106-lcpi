[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Image,
    [Parameter(Mandatory = $true)][int]$DiskNumber,
    [switch]$Verify,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
    Write-Host "flash-sd: ERROR: $Message" -ForegroundColor Red
    exit 1
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { Fail "raw disk write needs an elevated PowerShell" }

if (-not (Test-Path -LiteralPath $Image)) { Fail "image not found: $Image" }
$Image = (Resolve-Path -LiteralPath $Image).Path
$fs = [System.IO.File]::OpenRead($Image)
$imageLength = $fs.Length
$sourceHash = (Get-FileHash -LiteralPath $Image -Algorithm SHA256).Hash.ToLower()
$fs.Close()

$disk = Get-Disk -Number $DiskNumber -ErrorAction Stop
if ($disk.IsSystem -or $disk.IsBoot) {
    Fail "disk $DiskNumber is the system/boot disk"
}

Write-Host "flash-sd: target disk"
$disk | Select-Object Number, FriendlyName, SerialNumber, BusType, Size, IsSystem, IsBoot | Format-List | Out-Host
Get-Partition -DiskNumber $DiskNumber -ErrorAction SilentlyContinue |
    Select-Object PartitionNumber, DriveLetter, Size, Type | Format-Table -AutoSize | Out-Host

if ($disk.BusType -notin @('USB', 'SD', 'MMC') -and -not $Force) {
    Fail "disk $DiskNumber has BusType '$($disk.BusType)'; use -Force only if you are sure"
}

Write-Host ("flash-sd: image: {0} ({1:N0} bytes)" -f $Image, $imageLength)
Write-Host "flash-sd: sha256: $sourceHash"
Write-Host "flash-sd: ALL DATA ON DISK $DiskNumber WILL BE ERASED" -ForegroundColor Red

if (-not $Force) {
    $answer = Read-Host "Type ERASE $DiskNumber to continue"
    if ($answer -ne "ERASE $DiskNumber") { Fail "aborted by user" }
}

$devicePath = "\\.\PhysicalDrive$DiskNumber"
$bufferSize = 4MB
$buffer = [byte[]]::new($bufferSize)

Write-Host "flash-sd: taking disk offline"
Set-Disk -Number $DiskNumber -IsOffline $true

try {
    $in = [System.IO.File]::OpenRead($Image)
    try {
        $out = [System.IO.FileStream]::new(
            $devicePath,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Write,
            [System.IO.FileShare]::None
        )
        try {
            $total = 0L
            while (($read = $in.Read($buffer, 0, $buffer.Length)) -gt 0) {
                $out.Write($buffer, 0, $read)
                $total += $read
                $pct = [math]::Min(100, [math]::Round($total * 100.0 / $imageLength))
                Write-Progress -Activity "Writing $Image" -Status ("{0:N0} / {1:N0} bytes" -f $total, $imageLength) -PercentComplete $pct
            }
            $out.Flush($true)
        } finally {
            $out.Dispose()
        }
    } finally {
        $in.Dispose()
    }
    Write-Progress -Activity "Writing $Image" -Completed

    if ($Verify) {
        Write-Host "flash-sd: verifying read-back"
        $sha = [System.Security.Cryptography.SHA256]::Create()
        $dev = [System.IO.FileStream]::new(
            $devicePath,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            [System.IO.FileShare]::ReadWrite
        )
        try {
            $remaining = $imageLength
            $readBuf = [byte[]]::new($bufferSize)
            while ($remaining -gt 0) {
                $want = [int][math]::Min([long]$readBuf.Length, $remaining)
                $got = $dev.Read($readBuf, 0, $want)
                if ($got -le 0) { Fail "short read while verifying" }
                $sha.TransformBlock($readBuf, 0, $got, $null, 0) | Out-Null
                $remaining -= $got
            }
            $sha.TransformFinalBlock($readBuf, 0, 0) | Out-Null
            $deviceHash = ([BitConverter]::ToString($sha.Hash) -replace '-', '').ToLower()
            if ($deviceHash -ne $sourceHash) {
                Fail "verification mismatch: device=$deviceHash image=$sourceHash"
            }
            Write-Host "flash-sd: verify OK"
        } finally {
            $dev.Dispose()
            $sha.Dispose()
        }
    }
} finally {
    Write-Host "flash-sd: bringing disk online"
    Set-Disk -Number $DiskNumber -IsOffline $false
}

Write-Host "flash-sd: done. Insert the card into the board and power it on." -ForegroundColor Green

