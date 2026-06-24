# Windows: uses PowerShell driver in scripts/

TOP ?= pc_tb

.PHONY: synth sim all synth-rtl clean

synth:
	powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_yosys.ps1 -Top $(TOP)

sim:
	powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_yosys.ps1 -Top $(TOP) -Sim

all:
	powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_yosys.ps1 -All

synth-rtl:
	powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_yosys.ps1 -SynthRtl

clean:
	powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_yosys.ps1 -Clean
