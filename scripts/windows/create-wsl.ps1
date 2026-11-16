# create-wsl.ps1 - create a dedicated WSL distribution (Ubuntu 24.04) for building crDroid.
# Other WSL distributions are not touched (no "wsl --shutdown", .wslconfig is only shown, not changed).
# Run in a normal PowerShell window:
#   powershell -ExecutionPolicy Bypass -File scripts\windows\create-wsl.ps1 -Location D:\WSL\crdroid
#   -Name      name of the distribution (default: crdroid)
#   -Location  folder for the virtual disk; needs ~350 GB free, preferably on an SSD
param(
    [string]$Name = 'crdroid',
    [Parameter(Mandatory = $true)][string]$Location
)
$ErrorActionPreference = 'Continue'
$env:WSL_UTF8 = '1'
$Rootfs = 'https://cloud-images.ubuntu.com/wsl/noble/current/ubuntu-noble-wsl-amd64-wsl.rootfs.tar.gz'
function Distros { (& wsl.exe -l -q) -replace "`0", '' | ForEach-Object { $_.Trim() } | Where-Object { $_ } }
function Finish($code) { Read-Host 'Press Enter to close'; exit $code }

& wsl.exe --version | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host 'WSL is not installed. In an administrator PowerShell run:  wsl --install --no-distribution' -ForegroundColor Red
    Write-Host 'then restart Windows and run this script again.' -ForegroundColor Red
    Finish 1
}
if ((Distros) -contains $Name) { Write-Host "Distribution '$Name' already exists - nothing to do." -ForegroundColor Yellow; Finish 0 }
New-Item -ItemType Directory -Force -Path $Location | Out-Null

Write-Host "Installing Ubuntu 24.04 as '$Name' into $Location ..." -ForegroundColor Green
Write-Host 'When Ubuntu opens: create a user name and password, then type  exit' -ForegroundColor Cyan
& wsl.exe --install Ubuntu-24.04 --name $Name --location $Location

if (-not ((Distros) -contains $Name)) {
    Write-Host 'Direct install not possible (older WSL?) - importing the official Ubuntu image instead.' -ForegroundColor Yellow
    $tar = Join-Path $Location 'ubuntu-noble-wsl-amd64-wsl.rootfs.tar.gz'
    if (-not (Test-Path $tar)) {
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $Rootfs -OutFile $tar -UseBasicParsing
    }
    & wsl.exe --import $Name $Location $tar --version 2
    if ((Distros) -contains $Name) {
        Remove-Item $tar -ErrorAction SilentlyContinue
        Write-Host 'Imported. scripts/01-setup-host.sh will create your user (it asks for it).' -ForegroundColor Cyan
    } else {
        Write-Host 'Import failed.' -ForegroundColor Red; Finish 1
    }
}

# sparse disk: space freed inside Linux is given back to Windows
& wsl.exe --terminate $Name
& wsl.exe --manage $Name --set-sparse true

$ramGB = [math]::Floor((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
$cpus = [Environment]::ProcessorCount
$memGB = [math]::Floor($ramGB * 0.8)
$cfg = Join-Path $env:USERPROFILE '.wslconfig'
Write-Host ''
Write-Host "=== Your current $cfg ===" -ForegroundColor Green
if (Test-Path $cfg) { Get-Content $cfg } else { Write-Host '(does not exist)' }
Write-Host ''
Write-Host 'Recommended for building Android (section [wsl2], applies to ALL WSL distributions):' -ForegroundColor Cyan
Write-Host '  [wsl2]'
Write-Host "  memory=${memGB}GB"
Write-Host "  processors=$cpus"
Write-Host '  swap=16GB'
Write-Host '  swapFile=' -NoNewline; Write-Host ((Join-Path $Location 'swap.vhdx') -replace '\\', '\\')
Write-Host 'After changing .wslconfig run  wsl --shutdown  once (this stops ALL distributions).' -ForegroundColor Yellow
Write-Host ''
& wsl.exe -l -v
Write-Host "Next: open the distribution with  wsl -d $Name  and follow docs/setup.md" -ForegroundColor Cyan
Finish 0
