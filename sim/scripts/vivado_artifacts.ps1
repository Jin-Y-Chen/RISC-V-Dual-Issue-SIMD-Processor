# Shared cleanup for Vivado XSIM tool junk (xvlog/xelab/xsim logs, xsim.dir, etc.).
# Tools must run from sim/build via run_vivado_sim.ps1 — not from the repo root.

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
