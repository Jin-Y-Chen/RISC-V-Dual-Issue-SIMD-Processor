# Forwards to scripts/Makefile so `make sim` works from repo root.
TOP ?= pc_tb

.PHONY: synth sim all synth-rtl clean

synth sim all synth-rtl clean:
	$(MAKE) -C scripts $@ TOP=$(TOP)
