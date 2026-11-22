<#
.SYNOPSIS
    Installs Streaming LAN Cast (TV Remote Edition) helper and extension files on Windows.
.DESCRIPTION
    Copies the patched helper and custom Chrome extension to %LOCALAPPDATA%\Programs\Streaming LAN Cast,
    creates an isolated Python 3.12 virtual environment (using uv if installed, else python),
    registers silent auto-start at Windows login, starts the helper, and prints your pairing token.
#>
$ErrorActionPreference = 'Stop'

$RepoRoot   = Split-Path -Parent $PSScriptRoot
$InstallDir = Join-Path $env:LOCALAPPDATA 'Programs\Streaming LAN Cast'
$VenvDir    = Join-Path $InstallDir 'venv'
$ExtDir     = Join-Path $InstallDir 'custom-extension'
$HelperDst  = Join-Path $InstallDir 'streaming-lan-cast-helper.py'
$VbsPath    = Join-Path $InstallDir 'run-hidden.vbs'
$TokenFile  = Join-Path $env:USERPROFILE '.streaming-lan-cast\token'

Write-Host "==> Installing Streaming LAN Cast (TV Remote) to: $InstallDir" -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

# 1. Stop any running helper cleanly
if (Test-Path $TokenFile) {
    $tok = (Get-Content -Raw $TokenFile).Trim()
    if ($tok) {
        try {
            Invoke-WebRequest -UseBasicParsing -TimeoutSec 3 -Method Post `
                -Uri 'http://127.0.0.1:9988/quit' -Headers @{ 'X-LanCast-Token' = $tok } | Out-Null
            Start-Sleep -Seconds 2
        } catch {}
    }
}
Get-Process -Name 'streaming-lan-cast-helper' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

# 2. Copy helper script and unpacked extension
Copy-Item -Force (Join-Path $RepoRoot 'helper\streaming-lan-cast-helper.py') $HelperDst
if (Test-Path $ExtDir) { Remove-Item -Recurse -Force $ExtDir }
Copy-Item -Recurse -Force (Join-Path $RepoRoot 'extension') $ExtDir

# 3. Create Python venv & install dependencies
$ReqFile = Join-Path $RepoRoot 'requirements.txt'
$uv = Get-Command uv -ErrorAction SilentlyContinue
if ($uv) {
    Write-Host "==> Creating Python 3.12 venv with uv..." -ForegroundColor Cyan
    & $uv.Source venv --python 3.12 --allow-existing $VenvDir
    & $uv.Source pip install --python (Join-Path $VenvDir 'Scripts\python.exe') -r $ReqFile
} else {
    $py = Get-Command python -ErrorAction SilentlyContinue
    if (-not $py) {
        throw "Neither 'uv' nor 'python' was found on PATH. Install Python 3.10+ or uv (https://docs.astral.sh/uv/) and re-run."
    }
    Write-Host "==> Creating Python venv..." -ForegroundColor Cyan
    if (-not (Test-Path (Join-Path $VenvDir 'Scripts\python.exe'))) {
        & $py.Source -m venv $VenvDir
    }
    & (Join-Path $VenvDir 'Scripts\pip.exe') install --upgrade -r $ReqFile
}

# 4. Check for ffmpeg (needed for disguised-extension / fMP4 HLS DLNA remuxing & seeking)
$localFfmpeg = Join-Path $InstallDir 'ffmpeg.exe'
$pathFfmpeg  = Get-Command ffmpeg -ErrorAction SilentlyContinue
if (-not (Test-Path $localFfmpeg) -and -not $pathFfmpeg) {
    Write-Warning "ffmpeg was not found. Attempting to install via winget (Gyan.FFmpeg)..."
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget) {
        & $winget.Source install -e --id Gyan.FFmpeg --accept-source-agreements --accept-package-agreements
    } else {
        Write-Warning "Please install ffmpeg manually and ensure 'ffmpeg.exe' is on PATH or in '$InstallDir'."
    }
}

# 5. Create silent launcher & register auto-start on login
$vbsContent = @"
' Streaming LAN Cast (TV Remote): start the local helper silently
dir = Left(WScript.ScriptFullName, InStrRev(WScript.ScriptFullName, "\"))
CreateObject("WScript.Shell").Run """" & dir & "venv\Scripts\pythonw.exe"" """ & dir & "streaming-lan-cast-helper.py"" --serve", 0, False
"@
Set-Content -Path $VbsPath -Value $vbsContent -Encoding ASCII

Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' `
    -Name 'Streaming LAN Cast' `
    -Value "wscript.exe `"$VbsPath`""

# 6. Start helper detached and wait for token
Write-Host "==> Starting helper..." -ForegroundColor Cyan
Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{
    CommandLine = "wscript.exe `"$VbsPath`""
} | Out-Null

$token = ''
for ($i = 0; $i -lt 25; $i++) {
    Start-Sleep -Milliseconds 300
    if (Test-Path $TokenFile) {
        $t = (Get-Content -Raw $TokenFile).Trim()
        if ($t) { $token = $t; break }
    }
}

Write-Host ""
Write-Host "Installation complete!" -ForegroundColor Green
Write-Host "  Helper URL : http://127.0.0.1:9988"
if ($token) {
    Write-Host "  Token      : $token" -ForegroundColor Yellow
} else {
    Write-Host "  Token file : $TokenFile (check after helper finishes starting)" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "Next steps in Chrome / Edge / Brave:" -ForegroundColor Cyan
Write-Host "  1. Open chrome://extensions and turn ON 'Developer mode' (top-right)."
Write-Host "  2. Click 'Load unpacked' and select:"
Write-Host "     $ExtDir" -ForegroundColor White
Write-Host "  3. Pin the extension, click it -> Open options -> paste your Token -> Save."
Write-Host "  4. Make sure your Wi-Fi network profile is set to Private and allow Windows Firewall on first cast."
