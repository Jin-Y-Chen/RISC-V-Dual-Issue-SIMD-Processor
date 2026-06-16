# Remove Vivado simulator junk from the repo (root xvlog.log, xsim.dir, etc.).
# Use after accidentally running xvlog/xelab/xsim from the repo root.
#
# Example:
#   .\sim\scripts\clean_vivado_artifacts.ps1

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "vivado_artifacts.ps1")

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$buildDir = Join-Path $repoRoot "sim\build"

Remove-VivadoBuildDir -BuildDir $buildDir
Remove-VivadoRootArtifacts -RepoRoot $repoRoot

Write-Host "OK  removed Vivado artifacts under $repoRoot"
