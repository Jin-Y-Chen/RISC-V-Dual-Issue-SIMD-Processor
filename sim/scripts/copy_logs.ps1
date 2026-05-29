# Copy Vivado simulate.log -> sim/logs/latest/tb.log + summary.txt
#
#   .\sim\scripts\copy_logs.ps1

param(
    [string]$VivadoProjectDir = "C:\Users\Jin\Documents\Vivado\RISC-V"
)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$LogsRoot = Join-Path $RepoRoot "sim\logs"
$LatestDir = Join-Path $LogsRoot "latest"

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

$searchRoots = @($searchRoots | Select-Object -Unique)
if ($searchRoots.Count -eq 0) {
    Write-Error "Vivado project not found. Pass -VivadoProjectDir."
}

$found = @()
foreach ($root in $searchRoots) {
    $found += Get-ChildItem -Path $root -Recurse -Filter "simulate.log" -ErrorAction SilentlyContinue
}

if ($found.Count -eq 0) {
    Write-Host "No simulate.log found. Run simulation first."
    exit 1
}

$best = $found | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$src = $best.FullName
$text = Get-Content -Raw $src

$label = "run"
if ($text -match '\[INFO\]\s+(\S+)\s+-') {
    $label = $Matches[1]
}

$result = "unknown"
if ($text -match '\*\*\* SUMMARY:\s*(.+?)\s*\*\*\*') {
    $result = $Matches[1].Trim()
}

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$archive = Join-Path $LogsRoot "${label}_${stamp}"
New-Item -ItemType Directory -Force -Path $archive | Out-Null

function Copy-FileShared([string]$From, [string]$To) {
    $in = [System.IO.File]::Open($From, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    try {
        $out = [System.IO.File]::Create($To)
        try { $in.CopyTo($out) } finally { $out.Dispose() }
    } finally { $in.Dispose() }
}

$summaryLines = @(
    "label:  $label"
    "time:   $stamp"
    "result: $result"
)

foreach ($dir in @($LatestDir, $archive)) {
    Copy-FileShared $src (Join-Path $dir "tb.log")
    $summaryLines | Set-Content (Join-Path $dir "summary.txt")
}

$archive | Set-Content (Join-Path $LogsRoot "_latest_run.txt")

Write-Host "OK  $LatestDir\tb.log"
Write-Host "OK  $LatestDir\summary.txt"
Write-Host "     $result"
