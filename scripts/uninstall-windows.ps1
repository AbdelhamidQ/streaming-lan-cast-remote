<#
.SYNOPSIS
    Stops and removes Streaming LAN Cast (TV Remote Edition) startup registration on Windows.
#>
param(
    [switch]$RemoveFiles
)

$ErrorActionPreference = 'SilentlyContinue'
$InstallDir = Join-Path $env:LOCALAPPDATA 'Programs\Streaming LAN Cast'
$TokenFile  = Join-Path $env:USERPROFILE '.streaming-lan-cast\token'

if (Test-Path $TokenFile) {
    $tok = (Get-Content -Raw $TokenFile).Trim()
    if ($tok) {
        Invoke-WebRequest -UseBasicParsing -TimeoutSec 3 -Method Post `
            -Uri 'http://127.0.0.1:9988/quit' -Headers @{ 'X-LanCast-Token' = $tok } | Out-Null
        Start-Sleep -Seconds 2
    }
}

Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'Streaming LAN Cast'

if ($RemoveFiles -and (Test-Path $InstallDir)) {
    Remove-Item -Recurse -Force $InstallDir
    Write-Host "Removed $InstallDir" -ForegroundColor Green
} else {
    Write-Host "Stopped helper and removed auto-start entry. Re-run with -RemoveFiles to delete '$InstallDir'." -ForegroundColor Yellow
}
