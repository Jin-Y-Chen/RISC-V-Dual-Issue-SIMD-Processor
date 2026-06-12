# Run Vivado XSIM for a selected TB and archive logs under sim/logs.
#
# Example:
#   .\sim\scripts\run_vivado_sim.ps1 -Top pc_tb
#   .\sim\scripts\run_vivado_sim.ps1 -All
#   .\sim\scripts\run_vivado_sim.ps1 -All -DeleteOddLogs
#
# Behavior:
# - Runs xvlog/xelab/xsim from repo root
# - Writes full simulation output log to sim/logs
# - Writes current run logs to sim/logs/current/<tb_top>/
# - Moves previous current run logs to sim/logs/temp/
# - Removes xsim.dir and root-generated simulator artifacts by default

param(
    [ValidateSet(
      "pc_tb",
      "if_id_tb",
      "decoder_tb",
      "register_file_tb",
      "dispatch_hazard_tb",
      "even_lane_tb",
      "odd_lane_tb",
      "id_ex_dispatch_tb",
      "forward_unit_tb",
      "ex_mem_tb"
    )]
    [string]$Top,

    [switch]$All,
    [switch]$DeleteOddLogs,

    [string]$VivadoRoot = "C:\FPGA\2025.2\Vivado"
)

$ErrorActionPreference = "Stop"

$AllTops = @(
  "pc_tb",
  "if_id_tb",
  "decoder_tb",
  "register_file_tb",
  #"dispatch_hazard_tb",
  "even_lane_tb",
  "odd_lane_tb",
  "id_ex_dispatch_tb",
  "forward_unit_tb"
  #"ex_mem_tb"
)

if ($All -and $Top) {
  throw "Use either -All or -Top, not both."
}
if (-not $All -and -not $Top) {
  throw "Provide one target (-Top <tb>) or run all (-All)."
}

function Get-TbSources([string]$TbTop) {
    switch ($TbTop) {
        "pc_tb" {
            return @(
                "rtl/common/rv_dis_pkg.sv",
                "rtl/s1_fetch/pc.sv",
                "sim/tb/s1_fetch/pc_tb.sv"
            )
        }
        "if_id_tb" {
            return @(
                "rtl/common/rv_dis_pkg.sv",
                "rtl/s2_decode/if_id.sv",
                "sim/tb/s2_decode/if_id_tb.sv"
            )
        }
        "decoder_tb" {
            return @(
                "rtl/common/rv_dis_pkg.sv",
                "rtl/s2_decode/decode_pkg.sv",
                "rtl/s2_decode/decoder.sv",
                "sim/tb/s2_decode/decoder_tb.sv"
            )
        }
        "register_file_tb" {
            return @(
                "rtl/common/rv_dis_pkg.sv",
                "rtl/s2_decode/decode_pkg.sv",
                "rtl/s2_decode/register_file.sv",
                "sim/tb/s2_decode/register_file_tb.sv"
            )
        }
        "dispatch_hazard_tb" {
            return @(
                "rtl/common/rv_dis_pkg.sv",
                "rtl/s2_decode/decode_pkg.sv",
                "sim/tb/s2_decode/dispatch_hazard_tb.sv"
            )
        }
        "even_lane_tb" {
            return @(
                "rtl/common/rv_dis_pkg.sv",
                "rtl/s2_decode/decode_pkg.sv",
                "rtl/s3_execution/even_lane/scalar_alu.sv",
                "rtl/s3_execution/even_lane/even_lane.sv",
                "sim/tb/s3_execute/even_lane_tb.sv"
            )
        }
        "odd_lane_tb" {
            return @(
                "rtl/common/rv_dis_pkg.sv",
                "rtl/s2_decode/decode_pkg.sv",
                "rtl/s3_execution/odd_lane/branch_unit.sv",
                "rtl/s3_execution/odd_lane/memory_access.sv",
                "rtl/s3_execution/odd_lane/odd_lane.sv",
                "sim/tb/s3_execute/odd_lane_tb.sv"
            )
        }
        "id_ex_dispatch_tb" {
            return @(
                "rtl/common/rv_dis_pkg.sv",
                "rtl/s3_execution/id_ex_dispatch.sv",
                "sim/tb/s3_execute/id_ex_dispatch_tb.sv"
            )
        }
        "forward_unit_tb" {
            return @(
                "rtl/common/rv_dis_pkg.sv",
                "rtl/s3_execution/forward_unit.sv",
                "sim/tb/s3_execute/forward_unit_tb.sv"
            )
        }
        "ex_mem_tb" {
            return @(
                "rtl/common/rv_dis_pkg.sv",
                "rtl/s4_memory/ex_mem_even.sv",
                "rtl/s4_memory/ex_mem_odd.sv",
                "sim/tb/s4_memory/ex_mem_tb.sv"
            )
        }
        default {
            throw "Unsupported top: $TbTop"
        }
    }
}

function Invoke-OneTb([string]$TbTop, [string]$RepoRoot, [string]$CurrentDir, [string]$SettingsBat) {
  $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
  $tbOutDir = Join-Path $CurrentDir $TbTop

  $srcs = Get-TbSources $TbTop
  foreach ($src in $srcs) {
    $fullPath = Join-Path $RepoRoot $src
    if (-not (Test-Path $fullPath)) {
      throw "Missing source file for ${TbTop}: $src"
    }
  }

  New-Item -ItemType Directory -Force -Path $tbOutDir | Out-Null

  $snapshot = "${TbTop}_sim"
  $srcArg = ($srcs -join " ")
  $runCmd = "xvlog --sv -i sim/tb $srcArg && xelab $TbTop -s $snapshot && xsim $snapshot -runall"

  Push-Location $RepoRoot
  try {
    cmd /c """$SettingsBat"" && $runCmd"
    if ($LASTEXITCODE -ne 0) {
      throw "Vivado simulation failed for top '$TbTop' (exit $LASTEXITCODE)."
    }

    $xsimLog = Join-Path $RepoRoot "xsim.log"
    if (-not (Test-Path $xsimLog)) {
      throw "xsim.log not found after simulation."
    }

    $xsimText = Get-Content -Raw $xsimLog
    $xsimLines = Get-Content $xsimLog
    $result = "unknown"
    if ($xsimText -match '\*\*\* SUMMARY:\s*(.+?)\s*\*\*\*') {
      $result = $Matches[1].Trim()
    }

    $summaryLines = @(
      "top:    $TbTop",
      "time:   $timestamp",
      "result: $result"
    )

    # Hide xsim session/system metadata while keeping full TB output.
    $tbLines = $xsimLines | Where-Object {
      ($_ -notmatch '^\s*#') -and
      ($_ -notmatch '^\s*source\s+xsim\.dir\/') -and
      ($_ -notmatch '^\s*INFO:\s*\[Common 17-206\]')
    }

    $failLines = $tbLines | Where-Object {
      ($_ -match '^\s*Error:\s+\[FAIL\]') -or
      ($_ -match '^\s*\[FAIL\]') -or
      ($_ -match '^\s*Fatal:')
    }

    $tbLines | Set-Content (Join-Path $tbOutDir "tb.log")
    $summaryLines | Set-Content (Join-Path $tbOutDir "summary.txt")

    $artifactNames = @(
      "xvlog.log", "xvlog.pb",
      "xelab.log", "xelab.pb",
      "xsim.log",  "xsim.jou",
      "xsim_*.backup.log", "xsim_*.backup.jou"
    )

    Remove-Item (Join-Path $RepoRoot "xsim.dir") -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $RepoRoot "sim\xsim.dir") -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $RepoRoot "$snapshot.wdb") -Force -ErrorAction SilentlyContinue

    foreach ($pattern in $artifactNames) {
      Get-ChildItem -Path $RepoRoot -Filter $pattern -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue
    }

    Write-Host "OK  top:       $TbTop"
    Write-Host "OK  tb.log:    $(Join-Path $tbOutDir 'tb.log')"
    Write-Host "OK  summary:   $(Join-Path $tbOutDir 'summary.txt')"
    Write-Host "    result:    $result"

    if ($failLines.Count -gt 0) {
      Write-Host "    fail details:"
      foreach ($line in $failLines) {
        Write-Host "      $line"
      }
    }

    return [pscustomobject]@{
      Top = $TbTop
      Result = $result
      Archive = $tbOutDir
      Failed = (($result -match '(?i)failed') -or ($failLines.Count -gt 0))
    }
  }
  finally {
    Pop-Location
  }
}

function Rotate-CurrentToTemp([string]$LogsRoot) {
  $currentDir = Join-Path $LogsRoot "current"
  $tempDir = Join-Path $LogsRoot "temp"

  New-Item -ItemType Directory -Force -Path $currentDir | Out-Null
  New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

  # 1) Delete old temp contents completely.
  Get-ChildItem -Path $tempDir -Force -ErrorAction SilentlyContinue |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

  # 2) Move previous current contents into temp.
  $currentItems = Get-ChildItem -Path $currentDir -Force -ErrorAction SilentlyContinue
  foreach ($item in $currentItems) {
    Move-Item -Path $item.FullName -Destination $tempDir -Force
  }

  Write-Host "Prepared logs folders: moved current -> temp, temp refreshed."
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$logsRoot = Join-Path $repoRoot "sim\logs"
$currentDir = Join-Path $logsRoot "current"
$settingsBat = Join-Path $VivadoRoot "settings64.bat"
if (-not (Test-Path $settingsBat)) {
  throw "Vivado settings not found: $settingsBat"
}

Rotate-CurrentToTemp -LogsRoot $logsRoot

if ($DeleteOddLogs) {
  Get-ChildItem -Path $logsRoot -Directory -Filter "odd_lane_tb_*" -ErrorAction SilentlyContinue |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}

$topsToRun = if ($All) { $AllTops } else { @($Top) }
$results = @()
foreach ($tb in $topsToRun) {
  Write-Host "=== RUN $tb ==="
  try {
    $results += Invoke-OneTb -TbTop $tb -RepoRoot $repoRoot -CurrentDir $currentDir -SettingsBat $settingsBat
  }
  catch {
    if ($All) {
      Write-Host "SKIP $tb - $($_.Exception.Message)"
      $results += [pscustomobject]@{
        Top = $tb
        Result = "SKIPPED"
        Archive = ""
        Failed = $false
      }
      continue
    }
    throw
  }
}

if ($All) {
  Write-Host ""
  Write-Host "=== ALL SUMMARY ==="
  foreach ($r in $results) {
    Write-Host ("{0,-18} {1}" -f $r.Top, $r.Result)
  }
}

if (($results | Where-Object { $_.Failed }).Count -gt 0) {
  exit 1
}
