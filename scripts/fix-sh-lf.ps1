$root = "C:\Users\Jin\Documents\Github\RISC-V-Dual-Issue-SIMD-Processor"
$files = @(
  "run-sim", "run-synth", "run-all",
  "scripts\run_sim.sh", "scripts\run_synth.sh", "scripts\run_all.sh", "scripts\common.sh"
)
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
foreach ($rel in $files) {
  $path = Join-Path $root $rel
  $text = [IO.File]::ReadAllText($path) -replace "`r`n", "`n" -replace "`r", "`n"
  [IO.File]::WriteAllText($path, $text, $utf8NoBom)
  Write-Host "LF: $rel"
}
