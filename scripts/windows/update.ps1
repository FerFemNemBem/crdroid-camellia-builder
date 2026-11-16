# update.ps1 - check for crDroid updates and build/publish them, from Windows.
# Starts the WSL distribution and runs scripts/update.sh inside it:
#   1. check whether anything is new on GitHub
#   2. on request: build and publish (inside tmux, session "crdroid-update")
# Usage: double-click update.bat, or
#   powershell -ExecutionPolicy Bypass -File scripts\windows\update.ps1 [-Build] [-Force] [-Distro <name>]
#   -Build   build without asking if something is new
#   -Force   build even if nothing is new
#   -Distro  WSL distribution (default: WSL_DISTRO from config.env, otherwise "crdroid")
param([switch]$Build, [switch]$Force, [string]$Distro)

$Session = 'crdroid-update'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

if (-not $Distro) {
    $Distro = 'crdroid'
    $cfg = Join-Path $Root 'config.env'
    if (Test-Path $cfg) {
        $line = Get-Content $cfg | Where-Object { $_ -match '^\s*WSL_DISTRO\s*=' } | Select-Object -Last 1
        if ($line) { $Distro = ($line -replace '^\s*WSL_DISTRO\s*=\s*', '' -replace '#.*$', '').Trim().Trim('"').Trim("'") }
    }
}
$list = (wsl.exe -l -q) -replace "`0", '' | ForEach-Object { $_.Trim() }
if ($list -notcontains $Distro) { Write-Host "WSL distribution '$Distro' not found." -ForegroundColor Red; exit 1 }

function Wsl { wsl.exe -d $Distro --exec @args }
$Repo = (Wsl wslpath -a $Root | Select-Object -First 1)
if (-not $Repo) { Write-Host "Could not translate $Root into a WSL path." -ForegroundColor Red; exit 1 }
$Update = "$Repo/scripts/update.sh"

# Already running? Attach to it again.
Wsl tmux has-session -t $Session 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host 'An update is already running - showing it (closing this window keeps it running).' -ForegroundColor Yellow
    Wsl tmux attach -t $Session
    exit 0
}

$doBuild = $Build -or $Force
if (-not $Force) {
    Write-Host 'Checking for new crDroid sources ...' -ForegroundColor Cyan
    Wsl bash $Update check
    $rc = $LASTEXITCODE
    if ($rc -eq 1) { Write-Host 'Check failed - see the log in OUTPUT_DIR/logs/update.log' -ForegroundColor Red; exit 1 }
    if ($rc -eq 0) {
        Write-Host "`nNothing new." -ForegroundColor Green
        $a = Read-Host 'Build anyway? (y/N)'
        if ($a -ne 'y') { exit 0 }
        $Force = $true; $doBuild = $true
    } elseif (-not $doBuild) {
        $a = Read-Host "`nUpdates available. Build and publish now (15-60 min)? (Y/n)"
        if ($a -eq 'n') { exit 0 }
        $doBuild = $true
    }
}
if (-not $doBuild) { exit 0 }

$opt = if ($Force) { '--force' } else { '' }
Write-Host "`nStarting the build in tmux (session '$Session')." -ForegroundColor Cyan
Write-Host 'Keep this window open (minimizing is fine). Closed it by accident? Start the script again - it re-attaches.' -ForegroundColor Yellow
Start-Sleep -Seconds 3
Wsl tmux new-session -s $Session "bash '$Update' build $opt; echo; read -p 'Finished - press Enter to close ' x"
