# Log directory layout for run_yosys.ps1 (Yosys via WSL).

function Get-LogsRoot([string]$RepoRoot) {
  return Join-Path $RepoRoot "synth\reports\runs"
}

function Get-LogsLatestDir([string]$RepoRoot) {
  return Join-Path (Get-LogsRoot $RepoRoot) "latest"
}

function Get-YosysBuildDir([string]$RepoRoot) {
  return Join-Path $RepoRoot "synth\build\yosys"
}

function Get-VerilatorBuildDir([string]$RepoRoot, [string]$TbTop) {
  return Join-Path $RepoRoot "sim\verilator\$TbTop"
}

function Get-SynthRoot([string]$RepoRoot) {
  return Join-Path $RepoRoot "synth"
}

function Publish-SynthArtifacts(
  [string]$RepoRoot,
  [string]$RunOutDir,
  [string]$TopName,
  [bool]$PromoteToRoot = $false
) {
  $synthLatest = Join-Path (Get-SynthRoot $RepoRoot) "latest\$TopName"
  New-Item -ItemType Directory -Force -Path $synthLatest | Out-Null

  foreach ($name in @("netlist.v", "design.json", "stat.txt", "run.ys")) {
    $src = Join-Path $RunOutDir $name
    if (Test-Path $src) {
      Copy-Item $src (Join-Path $synthLatest $name) -Force
    }
  }

  if (-not $PromoteToRoot) { return }

  $synthRoot = Get-SynthRoot $RepoRoot
  New-Item -ItemType Directory -Force -Path (Join-Path $synthRoot "reports") | Out-Null

  $netlist = Join-Path $RunOutDir "netlist.v"
  if (Test-Path $netlist) {
    Copy-Item $netlist (Join-Path $synthRoot "netlist.v") -Force
  }

  $json = Join-Path $RunOutDir "design.json"
  if (Test-Path $json) {
    Copy-Item $json (Join-Path $synthRoot "netlist.json") -Force
  }

  $stat = Join-Path $RunOutDir "stat.txt"
  if (Test-Path $stat) {
    Copy-Item $stat (Join-Path $synthRoot "reports\stat.txt") -Force
  }
}

function Rotate-LogsToTemp([string]$RepoRoot) {
  $logsRoot = Get-LogsRoot $RepoRoot
  $latestDir = Join-Path $logsRoot "latest"
  $tempDir = Join-Path $logsRoot "temp"

  New-Item -ItemType Directory -Force -Path $latestDir | Out-Null
  New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

  $latestItems = @(Get-ChildItem -Path $latestDir -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -ne ".gitkeep" })
  if ($latestItems.Count -eq 0) {
    Write-Host "Prepared logs: latest empty, temp unchanged."
    return
  }

  $archiveDir = Join-Path $tempDir (Get-Date -Format "yyyyMMdd_HHmmss")
  New-Item -ItemType Directory -Force -Path $archiveDir | Out-Null

  foreach ($item in $latestItems) {
    Move-Item -Path $item.FullName -Destination $archiveDir -Force
  }

  Write-Host "Prepared logs: moved latest -> temp/$(Split-Path $archiveDir -Leaf)."
}

function New-RunSummaryLines(
  [string]$Top,
  [string]$Mode,
  [string]$Timestamp,
  [string]$Result,
  [string]$SimResult = ""
) {
  $lines = @(
    "top:    $Top",
    "tool:   yosys",
    "mode:   $Mode",
    "time:   $Timestamp",
    "result: $Result"
  )
  if ($SimResult) {
    $lines += "sim:    $SimResult"
  }
  return $lines
}

function Write-RunSummary([string]$OutDir, [string[]]$SummaryLines) {
  New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
  $SummaryLines | Set-Content (Join-Path $OutDir "summary.txt")
}

function Extract-YosysStatLines([string[]]$LogLines) {
  $stat = New-Object System.Collections.Generic.List[string]
  $inStat = $false
  foreach ($line in $LogLines) {
    if ($line -match '^Printing (design )?statistics') {
      $inStat = $true
      continue
    }
    if ($inStat) {
      if ($line -match '^End of script' -and $stat.Count -gt 3) { break }
      $stat.Add($line)
    }
  }
  if ($stat.Count -eq 0) {
    return $LogLines | Where-Object { $_ -match 'Number of cells|Area for|Estimated|=== ' } |
      Select-Object -First 40
  }
  return $stat
}

function Publish-YosysRunLogs(
  [string]$RunOutDir,
  [string]$BuildDir,
  [string]$RunBase,
  [string]$ScriptPath,
  [string[]]$SummaryLines
) {
  New-Item -ItemType Directory -Force -Path $RunOutDir | Out-Null

  $buildLog = Join-Path $BuildDir "$RunBase.log"
  if (Test-Path $buildLog) {
    $logLines = Get-Content $buildLog
    $logLines | Set-Content (Join-Path $RunOutDir "run.log")
    (Extract-YosysStatLines $logLines) | Set-Content (Join-Path $RunOutDir "stat.txt")
  }

  if (Test-Path $ScriptPath) {
    Copy-Item $ScriptPath (Join-Path $RunOutDir "run.ys") -Force
  }

  Write-RunSummary -OutDir $RunOutDir -SummaryLines $SummaryLines

  $netlist = Join-Path $BuildDir "${RunBase}_out.v"
  if (Test-Path $netlist) {
    Copy-Item $netlist (Join-Path $RunOutDir "netlist.v") -Force
  }

  $json = Join-Path $BuildDir "${RunBase}_out.json"
  if (Test-Path $json) {
    Copy-Item $json (Join-Path $RunOutDir "design.json") -Force
  }
}

function Remove-LegacyLogTrees([string]$RepoRoot) {
  foreach ($legacy in @(
    "sim\logs\yosys",
    "sim\logs\current",
    "sim\logs",
    "sim\build",
    "sim\scripts"
  )) {
    $path = Join-Path $RepoRoot $legacy
    if (Test-Path $path) {
      Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
}
