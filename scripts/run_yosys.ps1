# Yosys elaboration / synthesis runner (WSL2 Ubuntu) for this repo.
#
#   .\scripts\run_yosys.ps1 -Top pc_tb
#   .\scripts\run_yosys.ps1 -All
#   .\scripts\run_yosys.ps1 -Top pc_tb -Synth
#   .\scripts\run_yosys.ps1 -SynthRtl
#   .\scripts\run_yosys.ps1 -Clean
#
# Logs: synth/reports/runs/latest/<top>/  |  build scratch: synth/build/yosys/

param(
    [switch]$Help,
    [switch]$Clean,

    [ValidateSet(
      "pc_tb",
      "instruction_cache_tb",
      "target_buffer_tb",
      "if_id_tb",
      "decoder_tb",
      "state_buffer_tb",
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
    [switch]$Synth,
    [switch]$Sim,
    [switch]$SynthRtl,
    [string]$RtlTop = "risc_dis_unit"
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "log_layout.ps1")

function Show-RunYosysHelp {
  @"
Usage: .\scripts\run_yosys.ps1 [flags]

Yosys RTL elaboration / synthesis (WSL). Optional Verilator TB self-test with -Sim.

Flags:
  -Top <name>     One testbench (e.g. pc_tb, decoder_tb)
  -All            All 15 unit TBs
  -Synth           Run synthesis on DUT (with -Top or -All)
  -Sim             Verilator compile + TB self-test
  -SynthRtl        Full-chip synthesis (default top: risc_dis_unit)
  -RtlTop <name>   Chip top for -SynthRtl
  -Clean           Remove Yosys build scratch only
  -DeleteOddLogs   Drop archived odd_lane_tb* logs before run
  -Help            Show this message

Examples:
  .\scripts\run_yosys.ps1 -Top pc_tb
  .\scripts\run_yosys.ps1 -Top pc_tb -Sim
  .\scripts\run_yosys.ps1 -All -Synth

Logs:  synth/reports/runs/latest/<top>/
Build: synth/build/yosys/  |  Verilator: sim/verilator/<top>/

-Sim requires Verilator + make + g++ in WSL. See scripts/README.md.

Shell wrappers: ./run-sim --help  ./run-synth --help  (repo root)
Use ./run-sim -TOP pc_tb from repo root.
"@
}

if ($Help) {
  Show-RunYosysHelp
  exit 0
}

$AllTops = @(
  "pc_tb",
  "instruction_cache_tb",
  "target_buffer_tb",
  "if_id_tb",
  "decoder_tb",
  "state_buffer_tb",
  "register_file_tb",
  "even_lane_tb",
  "odd_lane_tb",
  "id_ex_dispatch_tb",
  "forward_unit_tb",
  "ex_mem_tb",
  "memory_cache_tb",
  "scoreboard_tb",
  "ex_mem_wb_tb"
)

function Remove-YosysBuildDir([string]$YosysBuildDir) {
  if (Test-Path $YosysBuildDir) {
    Get-ChildItem -Path $YosysBuildDir -Force -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -ne ".gitkeep" } |
      Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
  }
}

function Write-Utf8NoBomLines([string]$Path, [string[]]$Lines) {
  $utf8NoBom = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllLines($Path, $Lines, $utf8NoBom)
}

function ConvertTo-WslPath([string]$WinPath) {
  if (Test-Path -LiteralPath $WinPath) {
    $resolved = (Resolve-Path -LiteralPath $WinPath).Path
  } else {
    $parent = Split-Path -Parent $WinPath
    $leaf = Split-Path -Leaf $WinPath
    if ($parent -and (Test-Path -LiteralPath $parent)) {
      $resolved = Join-Path (Resolve-Path -LiteralPath $parent).Path $leaf
    } else {
      $resolved = [System.IO.Path]::GetFullPath($WinPath)
    }
  }
  if ($resolved -match '^([A-Za-z]):\\(.*)$') {
    $drive = $Matches[1].ToLower()
    $rest = $Matches[2] -replace '\\', '/'
    return "/mnt/$drive/$rest"
  }
  if ($resolved -match '^([A-Za-z]):/(.*)$') {
    $drive = $Matches[1].ToLower()
    $rest = $Matches[2]
    return "/mnt/$drive/$rest"
  }
  throw "Cannot convert path to WSL: $WinPath"
}

function Assert-WslYosys {
  $check = wsl bash -lc "command -v yosys" 2>&1
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($check)) {
    throw @"
Yosys not found in WSL2 Ubuntu.
  wsl
  sudo apt update && sudo apt install -y yosys
"@
  }
}

function Assert-WslVerilator {
  $check = wsl bash -lc "command -v verilator" 2>&1
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($check)) {
    throw @"
Verilator not found in WSL2 Ubuntu (needed for -Sim).
  wsl
  sudo apt update && sudo apt install -y verilator g++ make
See scripts/README.md
"@
  }

  $buildTools = wsl bash -lc "command -v make && command -v g++" 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw @"
Verilator --binary needs make and g++ in WSL.
  wsl
  sudo apt update && sudo apt install -y build-essential
See scripts/README.md
"@
  }
}

function Get-RtlSources([string]$RepoRoot) {
  $pkgDir = Join-Path $RepoRoot "rtl\package"
  $ordered = @()
  foreach ($name in @("rv_dis_pkg.sv", "cache_pkg.sv")) {
    $path = Join-Path $pkgDir $name
    if (Test-Path $path) { $ordered += $path }
  }
  $rest = Get-ChildItem -Path (Join-Path $RepoRoot "rtl") -Filter "*.sv" -Recurse |
    Where-Object { $_.FullName -notmatch '\\package\\' } |
    Sort-Object FullName
  $ordered += $rest.FullName
  return $ordered | ForEach-Object {
    $_.Substring($RepoRoot.Length + 1) -replace '\\', '/'
  }
}

function Get-DutTopFromTb([string]$TbTop) {
  if ($TbTop -match '^(.*)_tb$') { return $Matches[1] }
  return $TbTop
}

function Get-RtlSourcesForTb([string]$TbTop) {
  return @(Get-TbSources $TbTop | Where-Object { $_ -notmatch '^tb/' })
}

function New-YosysScriptLines(
  [string]$WslRepo,
  [string[]]$Sources,
  [string]$TopModule,
  [bool]$DoSynth,
  [string]$OutBase
) {
  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add("# Auto-generated by run_yosys.ps1")
  foreach ($src in $Sources) {
    $norm = $src -replace '\\', '/'
    $lines.Add("read -sv $WslRepo/$norm")
  }
  $lines.Add("hierarchy -check -top $TopModule")
  if ($DoSynth) {
    $lines.Add("synth -top $TopModule")
  } else {
    $lines.Add("proc")
    $lines.Add("opt")
  }
  $lines.Add("stat")
  $lines.Add("write_verilog $WslRepo/synth/build/yosys/${OutBase}_out.v")
  $lines.Add("write_json $WslRepo/synth/build/yosys/${OutBase}_out.json")
  return $lines
}

function Invoke-WslBash([string]$Command) {
  wsl bash -lc $Command
  return $LASTEXITCODE
}

function Get-SimResultFromLog([string]$LogText) {
  if ($LogText -match '(?m)^\*\*\* SUMMARY: (\d+) passed, 0 failed - OK \*\*\*') {
    return "passed"
  }
  if ($LogText -match '(?m)^\*\*\* SUMMARY:') {
    return "failed"
  }
  if ($LogText -match '(?m)%Error:|^\[FAIL\]|TB FAILED|\$fatal') {
    return "failed"
  }
  return "failed"
}

function Invoke-VerilatorSim(
  [string]$TbTop,
  [string]$RepoRoot,
  [string]$RunOutDir
) {
  New-Item -ItemType Directory -Force -Path $RunOutDir | Out-Null

  $wslRepo = ConvertTo-WslPath $RepoRoot
  $verRel = "sim/verilator/$TbTop"
  $verBuild = Get-VerilatorBuildDir $RepoRoot $TbTop
  $srcs = Get-TbSources $TbTop

  foreach ($src in $srcs) {
    $fullPath = Join-Path $RepoRoot $src
    if (-not (Test-Path $fullPath)) {
      throw "Missing source file for ${TbTop} sim: $src"
    }
  }

  if (Test-Path $verBuild) {
    Remove-Item $verBuild -Recurse -Force -ErrorAction SilentlyContinue
  }
  New-Item -ItemType Directory -Force -Path $verBuild | Out-Null

  $quotedSrcs = ($srcs | ForEach-Object {
    $norm = $_ -replace '\\', '/'
    "'$wslRepo/$norm'"
  }) -join " "

  $compileCmd = @(
    "cd '$wslRepo' &&"
    "verilator --binary --timing --relative-includes -Wall -Wno-fatal"
    "--top-module $TbTop"
    "-Mdir '$verRel/obj_dir'"
    $quotedSrcs
    "> '$verRel/compile.log' 2>&1"
  ) -join " "
  Invoke-WslBash $compileCmd | Out-Null

  $compileLogPath = Join-Path $verBuild "compile.log"
  if (-not (Test-Path $compileLogPath)) {
    throw "Verilator compile log not found: $compileLogPath"
  }

  $compileText = Get-Content -Raw $compileLogPath
  if ($compileText -match '(?m)%Error:|^ERROR:') {
    Copy-Item $compileLogPath (Join-Path $RunOutDir "sim.log") -Force
    return [pscustomobject]@{
      Result = "failed"
      Failed = $true
      LogPath = Join-Path $RunOutDir "sim.log"
    }
  }

  $simCmd = "cd '$wslRepo' && $verRel/obj_dir/V$TbTop > $verRel/sim.log 2>&1"
  Invoke-WslBash $simCmd | Out-Null

  $simLogPath = Join-Path $verBuild "sim.log"
  if (-not (Test-Path $simLogPath)) {
    throw "Verilator sim log not found: $simLogPath"
  }

  $simOutPath = Join-Path $RunOutDir "sim.log"
  Copy-Item $simLogPath $simOutPath -Force

  $simText = Get-Content -Raw $simLogPath
  $simResult = Get-SimResultFromLog $simText
  $failed = ($simResult -ne "passed")

  return [pscustomobject]@{
    Result = $simResult
    Failed = $failed
    LogPath = $simOutPath
  }
}

function Invoke-WslYosys([string]$WslRepo, [string]$WslScriptPath, [string]$WslLogPath) {
  $cmd = "cd '$WslRepo' && yosys -l '$WslLogPath' '$WslScriptPath'"
  wsl bash -lc $cmd
  return $LASTEXITCODE
}

function Get-TbSources([string]$TbTop) {
    switch ($TbTop) {
        "pc_tb" {
            return @(
                "rtl/package/rv_dis_pkg.sv",
                "rtl/s1_fetch/core/pc.sv",
                "tb/s1_fetch/pc_tb.sv"
            )
        }
        "instruction_cache_tb" {
            return @(
                "rtl/package/rv_dis_pkg.sv",
                "rtl/package/cache_pkg.sv",
                "rtl/s1_fetch/core/instruction_cache.sv",
                "tb/s1_fetch/instruction_cache_tb.sv"
            )
        }
        "target_buffer_tb" {
            return @(
                "rtl/package/rv_dis_pkg.sv",
                "rtl/package/cache_pkg.sv",
                "rtl/s1_fetch/branch/target_buffer.sv",
                "tb/s1_fetch/target_buffer_tb.sv"
            )
        }
        "if_id_tb" {
            return @(
                "rtl/package/rv_dis_pkg.sv",
                "rtl/s2_decode/if_id.sv",
                "tb/s2_decode/if_id_tb.sv"
            )
        }
        "decoder_tb" {
            return @(
                "rtl/package/rv_dis_pkg.sv",
                "rtl/s2_decode/core/decoder.sv",
                "tb/s2_decode/decoder_tb.sv"
            )
        }
        "state_buffer_tb" {
            return @(
                "rtl/package/rv_dis_pkg.sv",
                "rtl/package/cache_pkg.sv",
                "rtl/s4_memory/branch/state_LUT.sv",
                "rtl/s2_decode/branch/state_buffer.sv",
                "tb/s2_decode/state_buffer_tb.sv"
            )
        }
        "register_file_tb" {
            return @(
                "rtl/package/rv_dis_pkg.sv",
                "rtl/s2_decode/core/decoder.sv",
                "rtl/s2_decode/core/register_file.sv",
                "tb/s2_decode/register_file_tb.sv"
            )
        }
        "dispatch_hazard_tb" {
            return @(
                "rtl/package/rv_dis_pkg.sv",
                "rtl/s2_decode/core/decoder.sv",
                "tb/s2_decode/dispatch_hazard_tb.sv"
            )
        }
        "even_lane_tb" {
            return @(
                "rtl/package/rv_dis_pkg.sv",
                "rtl/s2_decode/core/decoder.sv",
                "rtl/s3_execution/core/even_funct/scalar_alu.sv",
                "rtl/s3_execution/core/even_lane.sv",
                "tb/s3_execute/even_lane_tb.sv"
            )
        }
        "odd_lane_tb" {
            return @(
                "rtl/package/rv_dis_pkg.sv",
                "rtl/s3_execution/core/odd_funct/branch_unit.sv",
                "rtl/s3_execution/core/odd_funct/memory_access.sv",
                "rtl/s3_execution/core/odd_lane.sv",
                "tb/s3_execute/odd_lane_tb.sv"
            )
        }
        "id_ex_dispatch_tb" {
            return @(
                "rtl/package/rv_dis_pkg.sv",
                "rtl/s3_execution/dispatch_funct/scoreboard.sv",
                "rtl/s3_execution/id_ex_dispatch.sv",
                "tb/s3_execute/id_ex_dispatch_tb.sv"
            )
        }
        "forward_unit_tb" {
            return @(
                "rtl/package/rv_dis_pkg.sv",
                "rtl/s3_execution/core/forward_unit.sv",
                "tb/s3_execute/forward_unit_tb.sv"
            )
        }
        "ex_mem_tb" {
            return @(
                "rtl/package/rv_dis_pkg.sv",
                "rtl/s4_memory/ex_mem.sv",
                "tb/s4_memory/ex_mem_tb.sv"
            )
        }
        "memory_cache_tb" {
            return @(
                "rtl/package/rv_dis_pkg.sv",
                "rtl/package/cache_pkg.sv",
                "rtl/s4_memory/core/memory_cache.sv",
                "tb/s4_memory/memory_cache_tb.sv"
            )
        }
        "scoreboard_tb" {
            return @(
                "rtl/package/rv_dis_pkg.sv",
                "rtl/s3_execution/dispatch_funct/scoreboard.sv",
                "tb/s3_execute/scoreboard_tb.sv"
            )
        }
        "ex_mem_wb_tb" {
            return @(
                "rtl/package/rv_dis_pkg.sv",
                "rtl/s5_wback/ex_mem_wb.sv",
                "tb/s5_wback/ex_mem_wb_tb.sv"
            )
        }
        default {
            throw "Unsupported top: $TbTop"
        }
    }
}

function Invoke-OneTb(
  [string]$TbTop,
  [string]$RepoRoot,
  [string]$LatestDir,
  [bool]$DoSynth,
  [bool]$DoSim
) {
  $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
  $runOutDir = Join-Path $LatestDir $TbTop
  $buildDir = Get-YosysBuildDir $RepoRoot
  $wslRepo = ConvertTo-WslPath $RepoRoot
  $runBase = $TbTop
  $mode = if ($DoSynth) { "synth" } else { "elab" }

  $dutTop = Get-DutTopFromTb $TbTop
  $srcs = Get-RtlSourcesForTb $TbTop
  foreach ($src in $srcs) {
    $fullPath = Join-Path $RepoRoot $src
    if (-not (Test-Path $fullPath)) {
      throw "Missing source file for ${TbTop}: $src"
    }
  }

  New-Item -ItemType Directory -Force -Path $buildDir | Out-Null

  $ysPath = Join-Path $buildDir "$runBase.ys"
  $logPath = Join-Path $buildDir "$runBase.log"

  $lines = New-YosysScriptLines -WslRepo $wslRepo -Sources $srcs -TopModule $dutTop `
    -DoSynth $DoSynth -OutBase $runBase
  Write-Utf8NoBomLines -Path $ysPath -Lines $lines

  $exitCode = Invoke-WslYosys -WslRepo $wslRepo `
    -WslScriptPath (ConvertTo-WslPath $ysPath) `
    -WslLogPath (ConvertTo-WslPath $logPath)

  if (-not (Test-Path $logPath)) {
    throw "Yosys log not found after run: $logPath"
  }

  $yosysText = Get-Content -Raw $logPath
  $hasError = ($yosysText -match '(?m)^ERROR:')
  $result = if ($hasError) { "failed" } else { "passed" }

  $simResult = ""
  $simFailed = $false
  if ($DoSim) {
    Write-Host "=== VERILATOR $TbTop ==="
    $sim = Invoke-VerilatorSim -TbTop $TbTop -RepoRoot $RepoRoot -RunOutDir $runOutDir
    $simResult = $sim.Result
    $simFailed = $sim.Failed
    Write-Host "OK  sim.log:  $($sim.LogPath)"
  }

  $overallFailed = $hasError -or $simFailed
  $summaryLines = New-RunSummaryLines -Top $TbTop -Mode $mode `
    -Timestamp $timestamp -Result $result -SimResult $simResult

  Publish-YosysRunLogs -RunOutDir $runOutDir -BuildDir $buildDir -RunBase $runBase `
    -ScriptPath $ysPath -SummaryLines $summaryLines
  Publish-SynthArtifacts -RepoRoot $RepoRoot -RunOutDir $runOutDir -TopName $TbTop

  Write-Host "OK  tb:        $TbTop"
  Write-Host "OK  dut:       $dutTop ($mode)"
  Write-Host "OK  run.log:   $(Join-Path $runOutDir 'run.log')"
  Write-Host "OK  stat.txt:  $(Join-Path $runOutDir 'stat.txt')"
  Write-Host "OK  summary:   $(Join-Path $runOutDir 'summary.txt')"
  if ($DoSim) {
    Write-Host "    result:    $(if ($overallFailed) { 'failed' } else { 'passed' })"
    Write-Host "    yosys:     $result"
    Write-Host "    sim:       $simResult"
  } else {
    Write-Host "    result:    $result"
  }

  if ($hasError) {
    $errLines = Get-Content $logPath | Where-Object { $_ -match '^ERROR:' } | Select-Object -First 5
    if ($errLines) {
      Write-Host "    errors:"
      foreach ($line in $errLines) { Write-Host "      $line" }
    }
  }

  return [pscustomobject]@{
    Top = $TbTop
    Result = if ($overallFailed) { "failed" } else { "passed" }
    Archive = $runOutDir
    Failed = $overallFailed
  }
}

function Invoke-SynthRtl(
  [string]$RepoRoot,
  [string]$LatestDir,
  [string]$RtlTopName
) {
  $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
  $runBase = "rtl_$RtlTopName"
  $runOutDir = Join-Path $LatestDir $runBase
  $buildDir = Get-YosysBuildDir $RepoRoot
  $wslRepo = ConvertTo-WslPath $RepoRoot

  $srcs = Get-RtlSources $RepoRoot
  foreach ($src in $srcs) {
    $fullPath = Join-Path $RepoRoot ($src -replace '/', '\')
    if (-not (Test-Path $fullPath)) {
      throw "Missing RTL source: $src"
    }
  }

  New-Item -ItemType Directory -Force -Path $buildDir | Out-Null

  $ysPath = Join-Path $buildDir "$runBase.ys"
  $logPath = Join-Path $buildDir "$runBase.log"

  $lines = New-YosysScriptLines -WslRepo $wslRepo -Sources $srcs -TopModule $RtlTopName `
    -DoSynth $true -OutBase $runBase
  Write-Utf8NoBomLines -Path $ysPath -Lines $lines

  $exitCode = Invoke-WslYosys -WslRepo $wslRepo `
    -WslScriptPath (ConvertTo-WslPath $ysPath) `
    -WslLogPath (ConvertTo-WslPath $logPath)

  if (-not (Test-Path $logPath)) {
    throw "Yosys log not found after RTL synth: $logPath"
  }

  $yosysText = Get-Content -Raw $logPath
  $hasError = ($yosysText -match '(?m)^ERROR:')
  $result = if ($hasError) { "failed" } else { "passed" }

  $summaryLines = New-RunSummaryLines -Top $RtlTopName -Mode "synth-rtl" `
    -Timestamp $timestamp -Result $result

  Publish-YosysRunLogs -RunOutDir $runOutDir -BuildDir $buildDir -RunBase $runBase `
    -ScriptPath $ysPath -SummaryLines $summaryLines
  Publish-SynthArtifacts -RepoRoot $RepoRoot -RunOutDir $runOutDir `
    -TopName $runBase -PromoteToRoot $true

  Write-Host "OK  rtl top:   $RtlTopName (synth-rtl)"
  Write-Host "OK  run.log:   $(Join-Path $runOutDir 'run.log')"
  Write-Host "OK  stat.txt:  $(Join-Path $runOutDir 'stat.txt')"
  Write-Host "    result:    $result"

  return [pscustomobject]@{
    Top = $RtlTopName
    Result = $result
    Archive = $runOutDir
    Failed = $hasError
  }
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$yosysBuildDir = Get-YosysBuildDir $repoRoot

if ($Clean) {
  if ($Top -or $All -or $DeleteOddLogs -or $SynthRtl) {
    throw "Use -Clean alone, or run with -Top/-All/-SynthRtl."
  }

  Remove-YosysBuildDir -YosysBuildDir $yosysBuildDir
  Remove-LegacyLogTrees -RepoRoot $repoRoot
  Write-Host "OK  removed Yosys build artifacts under $repoRoot"
  exit 0
}

Assert-WslYosys
if ($Sim) {
  Assert-WslVerilator
}

if ($SynthRtl) {
  if ($All -or $Top) {
    throw "Use -SynthRtl alone (optional -RtlTop), not with -Top/-All."
  }

  Rotate-LogsToTemp -RepoRoot $repoRoot
  Remove-YosysBuildDir -YosysBuildDir $yosysBuildDir

  $latestDir = Get-LogsLatestDir $repoRoot
  Write-Host "=== YOSYS RTL SYNTH $RtlTop ==="
  $rtlResult = Invoke-SynthRtl -RepoRoot $repoRoot -LatestDir $latestDir -RtlTopName $RtlTop
  if ($rtlResult.Failed) { exit 1 }
  exit 0
}

if ($All -and $Top) {
  throw "Use either -All or -Top, not both."
}
if (-not $All -and -not $Top) {
  throw "Provide -Top <tb>, -All, -SynthRtl, or -Clean."
}

Rotate-LogsToTemp -RepoRoot $repoRoot
Remove-YosysBuildDir -YosysBuildDir $yosysBuildDir

if ($DeleteOddLogs) {
  $logsRoot = Get-LogsRoot $repoRoot
  Get-ChildItem -Path $logsRoot -Directory -Recurse -Filter "odd_lane_tb*" `
    -ErrorAction SilentlyContinue |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}

$topsToRun = if ($All) { $AllTops } else { @($Top) }
$results = @()
$doSynth = $Synth
$doSim = $Sim
$latestDir = Get-LogsLatestDir $repoRoot

foreach ($tb in $topsToRun) {
  Write-Host "=== YOSYS $tb ==="
  try {
    $results += Invoke-OneTb -TbTop $tb -RepoRoot $repoRoot `
      -LatestDir $latestDir -DoSynth $doSynth -DoSim $doSim
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

foreach ($r in $results) {
  if ($r.Failed) { exit 1 }
}
