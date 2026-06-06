# RV-DIS comprehensive demo — dual-issue RV32I subset + GPR behavior (project_outline §5)
# Assemble:  py tests/scripts/assembler.py tests/asm/demo_instructions.asm
# Outputs:   tests/bin/demo_instructions.{hex,mem,txt}
#
# Lane map (decode_pkg):
#   Even: OP / OP-IMM — add addi sub sll slt xor srl sra or and
#   Odd:  LOAD/STORE/BR/J — lw sw beq bne blt bge jal jalr lui auipc
#
# GPR file (rtl/s2_decode/register_file.sv, outline §5):
#   - 4 read ports (even rs1/rs2 + odd rs1/rs2); 2 write ports (even/odd WB same cycle)
#   - Same rd on both lanes one WB: younger insn wins (higher latched PC / wpc → odd slot)
#   - Same-cycle read of rd being written: bypass from WB (higher wpc if both write same rd)
#   - x0 reads as 0; writes to x0 ignored
#   - RAW I1←I0: dispatch may single-issue I0 only (pairs below avoid I1 using I0 rd unless noted)
#
# Listing convention: consecutive even|odd lines are one dual-issue pair (same cycle).

.org 0x00001000

_start:
    # -------------------------------------------------------------------------
    # 1) Memory base + scalars (lui/auipc odd | addi even)
    # -------------------------------------------------------------------------
    lui   x10, 0x0000a          # odd  — x10 = 0x00001000 (data region)
    addi  x5,  x1,  10          # even — x5  = 10
    auipc x13, 0                # odd  — x13 = PC of this insn (address math)
    addi  x6,  x2,  20          # even — x6  = 20

    # -------------------------------------------------------------------------
    # 2) Same-cycle multi-read of one GPR on several ports
    #    add x7,x5,x5 | sw x6,0(x5)  → even rs1=x5, even rs2=x5, odd rs1=x5
    # -------------------------------------------------------------------------
    add   x7,  x5,  x5          # even — x7 = 20
    sw    x7,  0(x10)           # odd  — rs1=x5 (base), rs2=x7 → mem[0x1000]=20

    add   x7,  x10, x10         # even — rs1=x10, rs2=x10
    lw    x9,  0(x10)           # odd  — rs1=x10 → x9 = 20

    xor   x12, x9,  x9          # even — rs1=x9, rs2=x9 → x12 = 0
    sw    x7,  4(x10)           # odd  — rs2=x7

    # -------------------------------------------------------------------------
    # 3) Back-to-back immediate-class writes to the SAME rd (dual-issue merge)
    #    Younger odd insn (PC+4) wins when both lanes write the same rd one cycle.
    # -------------------------------------------------------------------------
    addi  x11, x0,  0xAA        # even — would write 0xAA
    lui   x11, 0x00002          # odd  — wins → x11 = 0x00002000

    addi  x11, x0,  0x55        # even — would write 0x55
    auipc x11, 0                # odd  — wins → x11 = PC of this auipc

    addi  x11, x0,  17          # even — would write 17
    lw    x11, 0(x10)           # odd  — wins → x11 = mem[0x1000] = 20

    addi  x11, x0,  99          # even — would write 99
    lui   x11, 0x00001          # odd  — wins → x11 = 0x00001000

    # -------------------------------------------------------------------------
    # 4) Same-cycle read + write (RF WB bypass / merge)
    #    RAW I1←I0 pairs are labeled — dispatch may single-issue I0 only.
    # -------------------------------------------------------------------------
    addi  x14, x0,  4           # even — x14 = 4 (byte offset)     [RAW: odd uses x14]
    lw    x15, 0(x14)           # odd  — rs1=x14

    addi  x16, x0,  1           # even — would write 1 to x16
    lui   x16, 0x00001          # odd  — wins → x16 = 0x1000 (merge + bypass target)

    # -------------------------------------------------------------------------
    # 5) x0: read-as-zero and write-ignore
    # -------------------------------------------------------------------------
    add   x0,  x5,  x6          # even — rd=x0 write ignored
    sw    x6,  8(x10)           # odd  — mem[0x1008] = 20

    add   x7,  x0,  x5          # even — rs1=x0 → 0; x7 = 10
    lw    x8,  8(x10)           # odd  — x8 = 20

    # -------------------------------------------------------------------------
    # 6) Full even-lane R-type showcase (each paired with odd lw/sw)
    # -------------------------------------------------------------------------
    add   x7,  x5,  x6          # add  → 30
    sw    x7,  12(x10)
    sub   x7,  x6,  x5          # sub  → 10
    lw    x8,  12(x10)          # x8 = 30
    sll   x7,  x5,  x6          # sll  (shamt = x6[4:0])
    sw    x7,  16(x10)
    slt   x7,  x5,  x6          # slt  → 1 (10 < 20)
    lw    x9,  16(x10)
    xor   x7,  x5,  x6          # xor
    sw    x7,  20(x10)
    srl   x7,  x6,  x5          # srl  (shamt = 10)
    lw    x8,  20(x10)
    sra   x7,  x6,  x5          # sra
    sw    x7,  24(x10)
    or    x7,  x5,  x6          # or
    lw    x9,  24(x10)
    and   x7,  x5,  x6          # and  → 0
    sw    x7,  28(x10)

    # -------------------------------------------------------------------------
    # 7) Branches (odd) + even addi — BEQ BNE BLT BGE
    # -------------------------------------------------------------------------
    addi  x5,  x0,  3           # even — countdown
    beq   x5,  x0,  branch_done # odd  — not taken

branch_loop:
    addi  x5,  x5,  -1          # even
    bne   x5,  x0,  branch_loop # odd  — loop while x5 != 0

    addi  x5,  x0,  10          # even — upper bound for blt
    lw    x8,  0(x10)           # odd  — filler (no rd conflict)

    addi  x6,  x0,  5           # even — lower value
    blt   x6,  x5,  blt_taken   # odd  — 5 < 10, taken

    addi  x7,  x0,  0           # even — fall-through (skipped)
    beq   x0,  x0,  branch_done # odd

blt_taken:
    addi  x7,  x0,  1           # even — marker x7 = 1

    addi  x5,  x0,  5           # even — lower bound for bge
    lw    x9,  4(x10)           # odd  — filler

    addi  x6,  x0,  10          # even — upper value
    bge   x6,  x5,  bge_taken   # odd  — 10 >= 5, taken

    addi  x8,  x0,  0           # even — fall-through (skipped)
    beq   x0,  x0,  branch_done # odd

bge_taken:
    addi  x8,  x0,  2           # even — marker x8 = 2

branch_done:
    addi  x5,  x0,  0           # even — clear for tail demo

    # -------------------------------------------------------------------------
    # 8) JAL / JALR (odd) + even addi
    # -------------------------------------------------------------------------
    jal   x1,  helper           # odd  — link in x1 (ra)
    addi  x9,  x0,  99          # even — runs after return

    # -------------------------------------------------------------------------
    # 9) Tail: dual-issue ALU + mem (store then reload)
    # -------------------------------------------------------------------------
    addi  x6,  x0,  20          # even — restore x6
    sw    x6,  0(x10)           # odd  — mem[0x1000] = 20
    add   x7,  x5,  x6          # even — x7 = 20
    lw    x8,  0(x10)           # odd  — x8 = 20

done:
    beq   x0,  x0,  done        # odd  — halt

helper:
    addi  x2,  x0,  42          # even — demo return value
    jalr  x0,  0(x1)            # odd  — return (rd=x0, no link write)
