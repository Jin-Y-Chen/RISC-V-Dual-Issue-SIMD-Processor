# RV-DIS demo program — dual-issue friendly RV32I subset
# Assemble:  py tests/scripts/assembler.py tests/asm/demo_instructions.asm
# Outputs:   tests/bin/demo_instructions.{hex,mem,txt}  (flat; no subfolders)
#
# Even lane: OP / OP-IMM (add, addi, sub, ...)
# Odd lane:  load/store, branch, jump, lui, auipc
#
# Pairs that can issue together (same cycle, no RAW): one even + one odd.

.org 0x00001000

_start:
    # Setup: lui (odd) + addi (even) — different lanes
    lui   x10, 0x00001          # x10 = 0x00001000 (data base)
    addi  x5,  x0,  10          # x5  = 10
    addi  x6,  x0,  20          # x6  = 20

    # Dual-issue: add (even) + sw (odd)
    add   x7,  x5,  x6          # x7 = 30
    sw    x7,  0(x10)           # mem[0x1000] = 30

    # Dual-issue: addi (even) + lw (odd) — no RAW on x7 yet for lw
    addi  x5,  x0,  1           # x5 = 1
    lw    x8,  0(x10)           # x8 = 30

    # Countdown loop: addi (even) + bne (odd)
loop:
    addi  x5,  x5,  -1          # even
    bne   x5,  x0,  loop        # odd — branch if x5 != 0

    # Function call via jal / jalr
    jal   x1,  helper           # odd — link in ra
    addi  x9,  x0,  99          # even — delay slot not used (in-order); runs after return

done:
    beq   x0,  x0,  done        # spin forever (halt)

helper:
    addi  x2,  x0,  42          # even — return value in x2 (not ABI strict; demo only)
    jalr  x0,  0(x1)            # odd — return to caller (rd=x0 discards link write)
