# Vivado XSIM runner + artifact cleanup for this repo.
#
# Run simulation:
#   .\sim\scripts\run_vivado_sim.ps1 -Top pc_tb
#   .\sim\scripts\run_vivado_sim.ps1 -All
#   .\sim\scripts\run_vivado_sim.ps1 -All -DeleteOddLogs
#
# Clean Vivado junk only (xvlog.log, xsim.dir, etc.):
#   .\sim\scripts\run_vivado_sim.ps1 -Clean
#
# Behavior:
# - Runs xvlog/xelab/xsim from sim/build (no tool logs in repo root)
# - Writes full simulation output log to sim/logs
# - Writes current run logs to sim/logs/current/<tb_top>/
# - Moves previous current run logs to sim/logs/temp/<timestamp>/ (accumulates; delete manually)
# - Removes sim/build (including xsim.dir) and stray Vivado artifacts after each run

param(
    [switch]$Clean,

    [ValidateSet(
      "pc_tb",
      "instruction_cache_tb",
      "target_buffer_tb",
      "if_id_tb",
      "decoder_tb",
      "register_file_tb",
      "dispatch_hazard_tb",
      "even_lane_tb",
      "odd_lane_tb",
      "id_ex_dispatch_tb",
      "forward_unit_tb",
      "ex_mem_tb",
      "memory_cache_tb",
      "scoreboard_tb",
      "ex_mem_wb_tb"
    )]
    [string]$Top,

    [switch]$All,
    [switch]$DeleteOddLogs,

    [string]$VivadoRoot = "C:\FPGA\2025.2\Vivado"
)

$ErrorActionPreference = "Stop"

$AllTops = @(
  "pc_tb",
  "instruction_cache_tb",
  "target_buffer_tb",
  "if_id_tb",
  "decoder_tb",
  "register_file_tb",
  #"dispatch_hazard_tb",
  "even_lane_tb",
  "odd_lane_tb",
  "id_ex_dispatch_tb",
  "forward_unit_tb",
  "ex_mem_tb",
  "memory_cache_tb",
  "scoreboard_tb",
  "ex_mem_wb_tb"
)

function Remove-VivadoRootArtifacts([string]$RepoRoot) {
  $artifactNames = @(
    "xvlog.log", "xvlog.pb",
    "xelab.log", "xelab.pb",
    "xsim.log",  "xsim.jou",
    "xsim_*.backup.log", "xsim_*.backup.jou",
    "*.wdb",
    "dfx_runtime.txt"
  )

  $runtimePaths = @(
    (Join-Path $RepoRoot "dfx_runtime.txt"),
    (Join-Path $RepoRoot "sim\dfx_runtime.txt"),
    (Join-Path $RepoRoot "sim\build\dfx_runtime.txt")
  )

  foreach ($path in $runtimePaths) {
    Remove-Item $path -Force -ErrorAction SilentlyContinue
  }

  $xsimDirPaths = @(
    (Join-Path $RepoRoot "xsim.dir"),
    (Join-Path $RepoRoot "sim\xsim.dir"),
    (Join-Path $RepoRoot "sim\build\xsim.dir")
  )

  foreach ($dir in $xsimDirPaths) {
    Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
  }

  Get-ChildItem -Path $RepoRoot -Directory -Filter "xsim.dir" -Recurse -Depth 3 `
    -ErrorAction SilentlyContinue |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

  $simRoot = Join-Path $RepoRoot "sim"
  if (Test-Path $simRoot) {
    Get-ChildItem -Path $simRoot -Filter "dfx_runtime.txt" -Recurse `
      -ErrorAction SilentlyContinue |
      Remove-Item -Force -ErrorAction SilentlyContinue
  }

  foreach ($pattern in $artifactNames) {
    Get-ChildItem -Path $RepoRoot -Filter $pattern -Recurse -Depth 3 `
      -ErrorAction SilentlyContinue |
      Remove-Item -Force -ErrorAction SilentlyContinue
  }
}

function Remove-VivadoBuildDir([string]$BuildDir) {
  if (Test-Path $BuildDir) {
    Remove-Item $BuildDir -Recurse -Force -ErrorAction SilentlyContinue
  }
}

function Get-TbSources([string]$TbTop) {
    switch ($TbTop) {
        "pc_tb" {
            return @(
                "rtl/common/rv_dis_pkg.sv",
                "rtl/s1_fetch/core/pc.sv",
                "sim/tb/s1_fetch/pc_tb.sv"
            )
        }
        "instruction_cache_tb" {
            return @(
                "rtl/common/rv_dis_pkg.sv",
                "rtl/s1_fetch/core/instruction_cache.sv",
                "sim/tb/s1_fetch/instruction_cache_tb.sv"
            )
        }
        "target_buffer_tb" {
            return @(
                "rtl/common/rv_dis_pkg.sv",
                "rtl/s1_fetch/target/target_buffer.sv",
                "sim/tb/s1_fetch/target_buffer_tb.sv"
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
                "rtl/s2_decode/core/decode_pkg.sv",
                "rtl/s2_decode/core/decoder.sv",
                "sim/tb/s2_decode/decoder_tb.sv"
            )
        }
        "register_file_tb" {
            return @(
                "rtl/common/rv_dis_pkg.sv",
                "rtl/s2_decode/core/decode_pkg.sv",
                "rtl/s2_decode/core/register_file.sv",
                "sim/tb/s2_decode/register_file_tb.sv"
            )
        }
        "dispatch_hazard_tb" {
            return @(
                "rtl/common/rv_dis_pkg.sv",
                "rtl/s2_decode/core/decode_pkg.sv",
                "sim/tb/s2_decode/dispatch_hazard_tb.sv"
            )
        }
        "even_lane_tb" {
            return @(
                "rtl/common/rv_dis_pkg.sv",
                "rtl/s2_decode/core/decode_pkg.sv",
                "rtl/s3_execution/core/even_funct/scalar_alu.sv",
                "rtl/s3_execution/core/even_lane.sv",
                "sim/tb/s3_execute/even_lane_tb.sv"
            )
        }
        "odd_lane_tb" {
            return @(
                "rtl/common/rv_dis_pkg.sv",
                "rtl/s3_execution/core/odd_funct/branch_unit.sv",
                "rtl/s3_execution/core/odd_funct/memory_access.sv",
                "rtl/s3_execution/core/odd_lane.sv",
                "sim/tb/s3_execute/odd_lane_tb.sv"
            )
        }
        "id_ex_dispatch_tb" {
            return @(
                "rtl/common/rv_dis_pkg.sv",
                "rtl/s3_execution/dispatch_funct/scoreboard.sv",
                "rtl/s3_execution/id_ex_dispatch.sv",
                "sim/tb/s3_execute/id_ex_dispatch_tb.sv"
            )
        }
        "forward_unit_tb" {
            return @(
                "rtl/common/rv_dis_pkg.sv",
                "rtl/s3_execution/core/forward_unit.sv",
                "sim/tb/s3_execute/forward_unit_tb.sv"
            )
        }
        "ex_mem_tb" {
            return @(
                "rtl/common/rv_dis_pkg.sv",
                "rtl/s4_memory/ex_mem.sv",
                "sim/tb/s4_memory/ex_mem_tb.sv"
            )
        }
        "memory_cache_tb" {
            return @(
                "rtl/common/rv_dis_pkg.sv",
                "rtl/s4_memory/core/memory_cache.sv",
                "sim/tb/s4_memory/memory_cache_tb.sv"
            )
        }
        "scoreboard_tb" {
            return @(
                "rtl/common/rv_dis_pkg.sv",
                "rtl/s3_execution/dispatch_funct/scoreboard.sv",
                "sim/tb/s3_execute/scoreboard_tb.sv"
            )
        }
        "ex_mem_wb_tb" {
            return @(
                "rtl/common/rv_dis_pkg.sv",
                "rtl/s5_wback/ex_mem_wb.sv",
                "sim/tb/s5_wback/ex_mem_wb_tb.sv"
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
  $buildDir = Join-Path $RepoRoot "sim\build"

  $srcs = Get-TbSources $TbTop
  foreach ($src in $srcs) {
    $fullPath = Join-Path $RepoRoot $src
    if (-not (Test-Path $fullPath)) {
      throw "Missing source file for ${TbTop}: $src"
    }
  }

  New-Item -ItemType Directory -Force -Path $tbOutDir | Out-Null
  Remove-VivadoBuildDir -BuildDir $buildDir
  New-Item -ItemType Directory -Force -Path $buildDir | Out-Null

  $snapshot = "${TbTop}_sim"
  $srcArg = (($srcs | ForEach-Object { "../../$_" }) -join " ")
  $runCmd = "xvlog --sv -i ../../sim/tb $srcArg && xelab $TbTop -s $snapshot && xsim $snapshot -runall"

  Push-Location $buildDir
  try {
    cmd /c """$SettingsBat"" && $runCmd"
    if ($LASTEXITCODE -ne 0) {
      throw "Vivado simulation failed for top '$TbTop' (exit $LASTEXITCODE)."
    }

    $xsimLog = Join-Path $buildDir "xsim.log"
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

    Remove-Item (Join-Path $buildDir "$snapshot.wdb") -Force -ErrorAction SilentlyContinue
    Remove-VivadoBuildDir -BuildDir $buildDir
    Remove-VivadoRootArtifacts -RepoRoot $RepoRoot

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
    Remove-VivadoBuildDir -BuildDir $buildDir
    Remove-VivadoRootArtifacts -RepoRoot $RepoRoot
  }
}

function Rotate-CurrentToTemp([string]$LogsRoot) {
  $currentDir = Join-Path $LogsRoot "current"
  $tempDir = Join-Path $LogsRoot "temp"

  New-Item -ItemType Directory -Force -Path $currentDir | Out-Null
  New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

  $currentItems = @(Get-ChildItem -Path $currentDir -Force -ErrorAction SilentlyContinue)
  if ($currentItems.Count -eq 0) {
    Write-Host "Prepared logs folders: current empty, temp unchanged."
    return
  }

  $archiveDir = Join-Path $tempDir (Get-Date -Format "yyyyMMdd_HHmmss")
  New-Item -ItemType Directory -Force -Path $archiveDir | Out-Null

  foreach ($item in $currentItems) {
    Move-Item -Path $item.FullName -Destination $archiveDir -Force
  }

  Write-Host "Prepared logs folders: moved current -> temp/$(Split-Path $archiveDir -Leaf)."
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$buildDir = Join-Path $repoRoot "sim\build"

if ($Clean) {
  if ($Top -or $All -or $DeleteOddLogs) {
    throw "Use -Clean alone, or run simulation with -Top/-All."
  }

  Remove-VivadoBuildDir -BuildDir $buildDir
  Remove-VivadoRootArtifacts -RepoRoot $repoRoot
  Write-Host "OK  removed Vivado artifacts under $repoRoot"
  exit 0
}

if ($All -and $Top) {
  throw "Use either -All or -Top, not both."
}
if (-not $All -and -not $Top) {
  throw "Provide one target (-Top <tb> or -All) or use -Clean."
}

$logsRoot = Join-Path $repoRoot "sim\logs"
$currentDir = Join-Path $logsRoot "current"
$settingsBat = Join-Path $VivadoRoot "settings64.bat"
if (-not (Test-Path $settingsBat)) {
  throw "Vivado settings not found: $settingsBat"
}

Rotate-CurrentToTemp -LogsRoot $logsRoot
Remove-VivadoRootArtifacts -RepoRoot $repoRoot

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
