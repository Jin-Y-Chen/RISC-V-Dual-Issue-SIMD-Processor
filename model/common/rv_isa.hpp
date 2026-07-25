#pragma once

#include "types.hpp"

namespace rv_gm {

constexpr uint8_t kOpcOp     = 0x33;
constexpr uint8_t kOpcOpImm  = 0x13;
constexpr uint8_t kOpcLoad   = 0x03;
constexpr uint8_t kOpcStore  = 0x23;
constexpr uint8_t kOpcBranch = 0x63;
constexpr uint8_t kOpcJal    = 0x6F;
constexpr uint8_t kOpcJalr   = 0x67;
constexpr uint8_t kOpcAuipc  = 0x17;
constexpr uint8_t kOpcLui    = 0x37;

constexpr uint8_t kF3AddSub = 0x0;
constexpr uint8_t kF3Sll    = 0x1;
constexpr uint8_t kF3Slt    = 0x2;
constexpr uint8_t kF3Xor    = 0x4;
constexpr uint8_t kF3SrlSra = 0x5;
constexpr uint8_t kF3Or     = 0x6;
constexpr uint8_t kF3And    = 0x7;
constexpr uint8_t kF3Lw     = 0x2;
constexpr uint8_t kF3Sw     = 0x2;
constexpr uint8_t kF3Beq    = 0x0;
constexpr uint8_t kF3Bne    = 0x1;
constexpr uint8_t kF3Blt    = 0x4;
constexpr uint8_t kF3Bge    = 0x5;

inline uint8_t opc(instr_t i) { return static_cast<uint8_t>(i & 0x7Fu); }
inline uint8_t f3(instr_t i)  { return static_cast<uint8_t>((i >> 12) & 0x7u); }
inline uint8_t f7(instr_t i)  { return static_cast<uint8_t>((i >> 25) & 0x7Fu); }
inline uint8_t rd(instr_t i)  { return static_cast<uint8_t>((i >> 7) & 0x1Fu); }
inline uint8_t rs1(instr_t i) { return static_cast<uint8_t>((i >> 15) & 0x1Fu); }
inline uint8_t rs2(instr_t i) { return static_cast<uint8_t>((i >> 20) & 0x1Fu); }

}  // namespace rv_gm
