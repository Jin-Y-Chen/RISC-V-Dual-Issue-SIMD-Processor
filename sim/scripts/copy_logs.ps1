# Copy newest XSim simulate.log + waveform (.wdb) into sim/logs/.
#
#   cd C:\Users\Jin\Documents\Github\RISC-V-Dual-Issue-SIMD-Processor
#   .\sim\scripts\copy_logs.ps1
#
# Optional: -VivadoProjectDir "C:\path\to\Vivado\RISC-V"

param(
    [string]$VivadoProjectDir = "C:\Users\Jin\Documents\Vivado\RISC-V"
)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$LogsRoot = Join-Path $RepoRoot "sim\logs"
$LatestDir = Join-Path $LogsRoot "latest"
$WaveName = "waveform.wdb"

New-Item -ItemType Directory -Force -Path $LatestDir | Out-Null

$searchRoots = @()
if (Test-Path $VivadoProjectDir) { $searchRoots += $VivadoProjectDir }

$cfg = Join-Path $PSScriptRoot "sim_log_paths.cfg"
if (Test-Path $cfg) {
    Get-Content $cfg | ForEach-Object {
        if ($_ -match '^project_dir=(.+)$') {
            $p = $Matches[1].Trim()
            if (Test-Path $p) { $searchRoots += $p }
        }
    }
}

$searchRoots = $searchRoots | Select-Object -Unique
if ($searchRoots.Count -eq 0) {
    Write-Error "Vivado project not found. Pass -VivadoProjectDir."
}

$foundLogs = foreach ($root in $searchRoots) {
    Get-ChildItem -Path $root -Recurse -Filter "simulate.log" -ErrorAction SilentlyContinue
}

if (-not $foundLogs) {
    Write-Host "No simulate.log found. Run Vivado simulation first (run 1000ns)."
    exit 1
}

$bestLog = $foundLogs | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$xsimDir = $bestLog.Directory.FullName
$logText = Get-Content -Raw $bestLog.FullName

$label = "run"
if ($logText -match '\[INFO\]\s+(\S+)\s+-') {
    $label = $Matches[1]
}

$result = "unknown"
if ($logText -match '\*\*\* SUMMARY:\s*(.+?)\s*\*\*\*') {
    $result = $Matches[1].Trim()
}

# Prefer .wdb next to simulate.log; else newest .wdb under project
$waveSrc = Get-ChildItem -Path $xsimDir -Filter "*.wdb" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (-not $waveSrc) {
    $allWdb = foreach ($root in $searchRoots) {
        Get-ChildItem -Path $root -Recurse -Filter "*.wdb" -ErrorAction SilentlyContinue
    }
    $waveSrc = $allWdb | Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$archive = Join-Path $LogsRoot "${label}_${stamp}"
New-Item -ItemType Directory -Force -Path $archive | Out-Null

Copy-Item -Force $bestLog.FullName (Join-Path $LatestDir "simulate.log")
Copy-Item -Force $bestLog.FullName (Join-Path $archive "simulate.log")

$waveNote = "none"
if ($waveSrc) {
    Copy-Item -Force $waveSrc.FullName (Join-Path $LatestDir $WaveName)
    Copy-Item -Force $waveSrc.FullName (Join-Path $archive $WaveName)
    $waveNote = $WaveName
}

$summary = @(
    "label:    $label"
    "time:     $stamp"
    "result:   $result"
    "waveform: $waveNote"
)
$summary | Set-Content (Join-Path $LatestDir "summary.txt")
$summary | Set-Content (Join-Path $archive "summary.txt")
$archive | Set-Content (Join-Path $LogsRoot "_latest_run.txt")

Write-Host "OK  $LatestDir\simulate.log"
Write-Host "     $result"
if ($waveSrc) {
    Write-Host "OK  $LatestDir\$WaveName"
} else {
    Write-Host "    (no .wdb - log signals in Vivado, re-run sim, then copy again)"
}
