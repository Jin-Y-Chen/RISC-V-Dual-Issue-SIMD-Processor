# RTL sim (Vivado XSIM) and synthesis (Yosys via WSL2 Ubuntu) for this repo.
#
# Vivado simulation (default):
#   .\sim\scripts\run_vivado_sim.ps1 -Top pc_tb
#   .\sim\scripts\run_vivado_sim.ps1 -All
#
# Yosys via WSL (install: sudo apt install yosys in Ubuntu):
#   .\sim\scripts\run_vivado_sim.ps1 -Tool Yosys -Top pc_tb
#   .\sim\scripts\run_vivado_sim.ps1 -Tool Yosys -Top pc_tb -ElabOnly
#   .\sim\scripts\run_vivado_sim.ps1 -Tool Yosys -SynthRtl
#   .\sim\scripts\run_vivado_sim.ps1 -Yosys -SynthRtl -RtlTop risc_dis_unit
#
# Clean tool artifacts:
#   .\sim\scripts\run_vivado_sim.ps1 -Clean
#
# Yosys runs in WSL at /mnt/c/Users/.../RISC-V-Dual-Issue-SIMD-Processor
# Vivado runs xvlog/xelab/xsim from sim/build; logs under sim/logs/current/<top>/

param(
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

    [ValidateSet("Vivado", "Yosys")]
    [string]$Tool = "Vivado",

    [switch]$Yosys,
    [switch]$ElabOnly,
    [switch]$SynthRtl,
    [string]$RtlTop = "risc_dis_unit",

    [string]$VivadoRoot = "C:\FPGA\2025.2\Vivado"
)

$ErrorActionPreference = "Stop"

if ($Yosys) {
  $Tool = "Yosys"
}

$AllTops = @(
  "pc_tb",
  "instruction_cache_tb",
  "target_buffer_tb",
  "if_id_tb",
  "decoder_tb",
  "state_buffer_tb",
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

function Remove-YosysBuildArtifacts([string]$BuildDir) {
  if (-not (Test-Path $BuildDir)) { return }
  Get-ChildItem -Path $BuildDir -Filter "yosys_*" -ErrorAction SilentlyContinue |
    Remove-Item -Force -ErrorAction SilentlyContinue
  Get-ChildItem -Path $BuildDir -Filter "*_out.v" -ErrorAction SilentlyContinue |
    Remove-Item -Force -ErrorAction SilentlyContinue
  Get-ChildItem -Path $BuildDir -Filter "*_out.json" -ErrorAction SilentlyContinue |
    Remove-Item -Force -ErrorAction SilentlyContinue
}

function ConvertTo-WslPath([string]$WinPath) {
  $resolved = (Resolve-Path $WinPath).Path
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

function New-YosysScriptLines(
  [string]$WslRepo,
  [string[]]$Sources,
  [string]$TopModule,
  [bool]$DoSynth,
  [string]$OutBase
) {
  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add("# Auto-generated by run_vivado_sim.ps1")
  $lines.Add("read -sv -I $WslRepo/sim/tb")
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
  $lines.Add("write_verilog $WslRepo/sim/build/${OutBase}_out.v")
  $lines.Add("write_json $WslRepo/sim/build/${OutBase}_out.json")
  return $lines
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
                "sim/tb/s1_fetch/pc_tb.sv"
            )
        }
        "instruction_cache_tb" {
            return @(
                "rtl/package/rv_dis_pkg.sv",
                "rtl/package/cache_pkg.sv",
                "rtl/s1_fetch/core/instruction_cache.sv",
                "sim/tb/s1_fetch/instruction_cache_tb.sv"
            )
        }
        "target_buffer_tb" {
            return @(
                "rtl/package/rv_dis_pkg.sv",
                "rtl/package/cache_pkg.sv",
                "rtl/s1_fetch/branch/target_buffer.sv",
                "sim/tb/s1_fetch/target_buffer_tb.sv"
            )
        }
        "if_id_tb" {
            return @(
                "rtl/package/rv_dis_pkg.sv",
                "rtl/s2_decode/if_id.sv",
                "sim/tb/s2_decode/if_id_tb.sv"
            )
        }
        "decoder_tb" {
            return @(
                "rtl/package/rv_dis_pkg.sv",
                "rtl/s2_decode/core/decoder.sv",
                "sim/tb/s2_decode/decoder_tb.sv"
            )
        }
        "state_buffer_tb" {
            return @(
                "rtl/package/rv_dis_pkg.sv",
                "rtl/package/cache_pkg.sv",
                "rtl/s4_memory/branch/state_LUT.sv",
                "rtl/s2_decode/branch/state_buffer.sv",
                "sim/tb/s2_decode/state_buffer_tb.sv"
            )
        }
        "register_file_tb" {
            return @(
                "rtl/package/rv_dis_pkg.sv",
                "rtl/s2_decode/core/decoder.sv",
                "rtl/s2_decode/core/register_file.sv",
                "sim/tb/s2_decode/register_file_tb.sv"
            )
        }
        "dispatch_hazard_tb" {
            return @(
                "rtl/package/rv_dis_pkg.sv",
                "rtl/s2_decode/core/decoder.sv",
                "sim/tb/s2_decode/dispatch_hazard_tb.sv"
            )
        }
        "even_lane_tb" {
            return @(
                "rtl/package/rv_dis_pkg.sv",
                "rtl/s2_decode/core/decoder.sv",
                "rtl/s3_execution/core/even_funct/scalar_alu.sv",
                "rtl/s3_execution/core/even_lane.sv",
                "sim/tb/s3_execute/even_lane_tb.sv"
            )
        }
        "odd_lane_tb" {
            return @(
                "rtl/package/rv_dis_pkg.sv",
                "rtl/s3_execution/core/odd_funct/branch_unit.sv",
                "rtl/s3_execution/core/odd_funct/memory_access.sv",
                "rtl/s3_execution/core/odd_lane.sv",
                "sim/tb/s3_execute/odd_lane_tb.sv"
            )
        }
        "id_ex_dispatch_tb" {
            return @(
                "rtl/package/rv_dis_pkg.sv",
                "rtl/s3_execution/dispatch_funct/scoreboard.sv",
                "rtl/s3_execution/id_ex_dispatch.sv",
                "sim/tb/s3_execute/id_ex_dispatch_tb.sv"
            )
        }
        "forward_unit_tb" {
            return @(
                "rtl/package/rv_dis_pkg.sv",
                "rtl/s3_execution/core/forward_unit.sv",
                "sim/tb/s3_execute/forward_unit_tb.sv"
            )
        }
        "ex_mem_tb" {
            return @(
                "rtl/package/rv_dis_pkg.sv",
                "rtl/s4_memory/ex_mem.sv",
                "sim/tb/s4_memory/ex_mem_tb.sv"
            )
        }
        "memory_cache_tb" {
            return @(
                "rtl/package/rv_dis_pkg.sv",
                "rtl/package/cache_pkg.sv",
                "rtl/s4_memory/core/memory_cache.sv",
                "sim/tb/s4_memory/memory_cache_tb.sv"
            )
        }
        "scoreboard_tb" {
            return @(
                "rtl/package/rv_dis_pkg.sv",
                "rtl/s3_execution/dispatch_funct/scoreboard.sv",
                "sim/tb/s3_execute/scoreboard_tb.sv"
            )
        }
        "ex_mem_wb_tb" {
            return @(
                "rtl/package/rv_dis_pkg.sv",
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

function Invoke-OneTbYosys(
  [string]$TbTop,
  [string]$RepoRoot,
  [string]$CurrentDir,
  [bool]$DoSynth
) {
  $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
  $tbOutDir = Join-Path $CurrentDir $TbTop
  $buildDir = Join-Path $RepoRoot "sim\build"
  $wslRepo = ConvertTo-WslPath $RepoRoot

  $srcs = Get-TbSources $TbTop
  foreach ($src in $srcs) {
    $fullPath = Join-Path $RepoRoot $src
    if (-not (Test-Path $fullPath)) {
      throw "Missing source file for ${TbTop}: $src"
    }
  }

  New-Item -ItemType Directory -Force -Path $tbOutDir | Out-Null
  New-Item -ItemType Directory -Force -Path $buildDir | Out-Null

  $ysName = "yosys_$TbTop.ys"
  $logName = "yosys_$TbTop.log"
  $ysPath = Join-Path $buildDir $ysName
  $logPath = Join-Path $buildDir $logName

  $lines = New-YosysScriptLines -WslRepo $wslRepo -Sources $srcs -TopModule $TbTop `
    -DoSynth $DoSynth -OutBase $TbTop
  $lines | Set-Content -Path $ysPath -Encoding UTF8

  $exitCode = Invoke-WslYosys -WslRepo $wslRepo `
    -WslScriptPath (ConvertTo-WslPath $ysPath) `
    -WslLogPath (ConvertTo-WslPath $logPath)

  if (-not (Test-Path $logPath)) {
    throw "Yosys log not found after run: $logPath"
  }

  $yosysText = Get-Content -Raw $logPath
  $yosysLines = Get-Content $logPath
  $hasError = ($yosysText -match '(?m)^ERROR:') -or ($exitCode -ne 0)
  $result = if ($hasError) { "failed" } else { "passed" }

  $summaryLines = @(
    "top:    $TbTop",
    "tool:   yosys",
    "mode:   $(if ($DoSynth) { 'synth' } else { 'elab' })",
    "time:   $timestamp",
    "result: $result"
  )

  $yosysLines | Set-Content (Join-Path $tbOutDir "yosys.log")
  $summaryLines | Set-Content (Join-Path $tbOutDir "summary.txt")

  if (Test-Path (Join-Path $buildDir "${TbTop}_out.v")) {
    Copy-Item (Join-Path $buildDir "${TbTop}_out.v") (Join-Path $tbOutDir "netlist.v") -Force
  }

  Write-Host "OK  top:       $TbTop (yosys)"
  Write-Host "OK  yosys.log: $(Join-Path $tbOutDir 'yosys.log')"
  Write-Host "OK  summary:   $(Join-Path $tbOutDir 'summary.txt')"
  Write-Host "    result:    $result"

  if ($hasError) {
    $errLines = $yosysLines | Where-Object { $_ -match '^ERROR:' } | Select-Object -First 5
    if ($errLines) {
      Write-Host "    errors:"
      foreach ($line in $errLines) { Write-Host "      $line" }
    }
  }

  return [pscustomobject]@{
    Top = $TbTop
    Result = $result
    Archive = $tbOutDir
    Failed = $hasError
  }
}

function Invoke-SynthRtl(
  [string]$RepoRoot,
  [string]$CurrentDir,
  [string]$RtlTopName
) {
  $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
  $outName = "yosys_rtl_$RtlTopName"
  $tbOutDir = Join-Path $CurrentDir $outName
  $buildDir = Join-Path $RepoRoot "sim\build"
  $wslRepo = ConvertTo-WslPath $RepoRoot

  $srcs = Get-RtlSources $RepoRoot
  foreach ($src in $srcs) {
    $fullPath = Join-Path $RepoRoot ($src -replace '/', '\')
    if (-not (Test-Path $fullPath)) {
      throw "Missing RTL source: $src"
    }
  }

  New-Item -ItemType Directory -Force -Path $tbOutDir | Out-Null
  New-Item -ItemType Directory -Force -Path $buildDir | Out-Null

  $ysPath = Join-Path $buildDir "$outName.ys"
  $logPath = Join-Path $buildDir "$outName.log"

  $lines = New-YosysScriptLines -WslRepo $wslRepo -Sources $srcs -TopModule $RtlTopName `
    -DoSynth $true -OutBase $outName
  $lines | Set-Content -Path $ysPath -Encoding UTF8

  $exitCode = Invoke-WslYosys -WslRepo $wslRepo `
    -WslScriptPath (ConvertTo-WslPath $ysPath) `
    -WslLogPath (ConvertTo-WslPath $logPath)

  if (-not (Test-Path $logPath)) {
    throw "Yosys log not found after RTL synth: $logPath"
  }

  $yosysText = Get-Content -Raw $logPath
  $yosysLines = Get-Content $logPath
  $hasError = ($yosysText -match '(?m)^ERROR:') -or ($exitCode -ne 0)
  $result = if ($hasError) { "failed" } else { "passed" }

  $summaryLines = @(
    "top:    $RtlTopName",
    "tool:   yosys",
    "mode:   synth-rtl",
    "time:   $timestamp",
    "result: $result"
  )

  $yosysLines | Set-Content (Join-Path $tbOutDir "yosys.log")
  $summaryLines | Set-Content (Join-Path $tbOutDir "summary.txt")

  if (Test-Path (Join-Path $buildDir "${outName}_out.v")) {
    Copy-Item (Join-Path $buildDir "${outName}_out.v") (Join-Path $tbOutDir "netlist.v") -Force
  }

  Write-Host "OK  rtl top:   $RtlTopName (yosys synth)"
  Write-Host "OK  yosys.log: $(Join-Path $tbOutDir 'yosys.log')"
  Write-Host "    result:    $result"

  return [pscustomobject]@{
    Top = $RtlTopName
    Result = $result
    Archive = $tbOutDir
    Failed = $hasError
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
  if ($Top -or $All -or $DeleteOddLogs -or $SynthRtl) {
    throw "Use -Clean alone, or run with -Top/-All/-SynthRtl."
  }

  Remove-VivadoBuildDir -BuildDir $buildDir
  Remove-YosysBuildArtifacts -BuildDir $buildDir
  Remove-VivadoRootArtifacts -RepoRoot $repoRoot
  Write-Host "OK  removed Vivado/Yosys artifacts under $repoRoot"
  exit 0
}

$logsRoot = Join-Path $repoRoot "sim\logs"
$currentDir = Join-Path $logsRoot "current"

if ($SynthRtl) {
  if ($All -or $Top) {
    throw "Use -SynthRtl alone (optional -RtlTop), not with -Top/-All."
  }

  Assert-WslYosys
  Rotate-CurrentToTemp -LogsRoot $logsRoot
  Remove-YosysBuildArtifacts -BuildDir $buildDir

  Write-Host "=== YOSYS RTL SYNTH $RtlTop ==="
  $rtlResult = Invoke-SynthRtl -RepoRoot $repoRoot -CurrentDir $currentDir -RtlTopName $RtlTop
  if ($rtlResult.Failed) { exit 1 }
  exit 0
}

if ($All -and $Top) {
  throw "Use either -All or -Top, not both."
}
if (-not $All -and -not $Top) {
  throw "Provide -Top <tb>, -All, -SynthRtl, or -Clean."
}

Rotate-CurrentToTemp -LogsRoot $logsRoot

if ($DeleteOddLogs) {
  Get-ChildItem -Path $logsRoot -Directory -Filter "odd_lane_tb_*" -ErrorAction SilentlyContinue |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}

$topsToRun = if ($All) { $AllTops } else { @($Top) }
$results = @()

if ($Tool -eq "Yosys") {
  Assert-WslYosys
  Remove-YosysBuildArtifacts -BuildDir $buildDir
  $doSynth = -not $ElabOnly

  foreach ($tb in $topsToRun) {
    Write-Host "=== YOSYS $tb ==="
    try {
      $results += Invoke-OneTbYosys -TbTop $tb -RepoRoot $repoRoot `
        -CurrentDir $currentDir -DoSynth $doSynth
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
}
else {
  $settingsBat = Join-Path $VivadoRoot "settings64.bat"
  if (-not (Test-Path $settingsBat)) {
    throw "Vivado settings not found: $settingsBat"
  }

  Remove-VivadoRootArtifacts -RepoRoot $repoRoot

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
