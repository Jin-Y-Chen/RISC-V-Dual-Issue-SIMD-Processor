# Normalize shell scripts to LF (run once after clone on Windows).
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$files = @(
  "scripts\run-sim", "scripts\run-synth", "scripts\run-all",
  "scripts\lib\common.sh", "scripts\sim\gen_waveform.sh"
)
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
foreach ($rel in $files) {
  $path = Join-Path $repoRoot $rel
  if (-not (Test-Path -LiteralPath $path)) {
    Write-Warning "Skip missing: $rel"
    continue
  }
  $text = [IO.File]::ReadAllText($path) -replace "`r`n", "`n" -replace "`r", "`n"
  [IO.File]::WriteAllText($path, $text, $utf8NoBom)
  Write-Host "LF: $rel"
}
