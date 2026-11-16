# build-all.ps1 - start the complete first build from Windows.
# Starts the WSL distribution and runs scripts/build-all.sh inside it (in tmux, session
# "crdroid-build"). Closing the window keeps the build running; start this again to see it.
# Usage: double-click build-all.bat, or
#   powershell -ExecutionPolicy Bypass -File scripts\windows\build-all.ps1 [-Restart] [-Distro <name>]
#   -Restart  forget the progress of an unfinished run and start over
#   -Distro   WSL distribution (default: WSL_DISTRO from config.env, otherwise "crdroid")
param([switch]$Restart, [string]$Distro)

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
if ($list -notcontains $Distro) {
    Write-Host "WSL distribution '$Distro' not found - create it first (docs/setup.md)." -ForegroundColor Red
    exit 1
}
$Repo = (wsl.exe -d $Distro --exec wslpath -a $Root | Select-Object -First 1)
if (-not $Repo) { Write-Host "Could not translate $Root into a WSL path." -ForegroundColor Red; exit 1 }

$opt = if ($Restart) { '--restart' } else { '' }
if ($opt) { wsl.exe -d $Distro --exec bash "$Repo/scripts/build-all.sh" $opt }
else { wsl.exe -d $Distro --exec bash "$Repo/scripts/build-all.sh" }
