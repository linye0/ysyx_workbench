/***************************************************************************************
* Copyright (c) 2014-2024 Zihao Yu, Nanjing University
*
* NEMU is licensed under Mulan PSL v2.
* You can use this software according to the terms and conditions of the Mulan PSL v2.
* You may obtain a copy of Mulan PSL v2 at:
*          http://license.coscl.org.cn/MulanPSL2
*
* THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
* EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
* MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
*
* See the Mulan PSL v2 for more details.
***************************************************************************************/

#include "common.h"
#include "isa.h"
#include "local-include/reg.h"
#include <cpu/cpu.h>
#include <cpu/difftest.h>
#include <cpu/ifetch.h>
#include <utils.h>
#include <cpu/decode.h>
#ifdef CONFIG_NPC
#include <npc/npc_verilog.h>
#ifdef CONFIG_SYS_SOC
#ifdef CONFIG_NVBOARD
#include <nvboard.h>
#endif
#endif
#endif

#define R(i) gpr(i)
#define CSR(i) sr(i)
#define Mr vaddr_read
#define Mw vaddr_write


enum {
  TYPE_I, TYPE_U, TYPE_S,
  TYPE_N, TYPE_J, TYPE_B,
  TYPE_I_I, TYPE_R// none
};

#define src1R() do { *src1 = R(rs1); } while (0)
#define src2R() do { *src2 = R(rs2); } while (0)
#define immI() do { *imm = SEXT(BITS(i, 31, 20), 12); } while(0)
#define immU() do { *imm = SEXT(BITS(i, 31, 12), 20) << 12; } while(0)
#define immS() do { *imm = (SEXT(BITS(i, 31, 25), 7) << 5) | BITS(i, 11, 7); } while(0)
#define immB() do { *imm = ((SEXT(BITS(i, 31, 31), 1) << 12) | BITS(i, 7, 7) << 11 | (BITS(i, 30, 25) << 5) | (BITS(i, 11, 8)) << 1 ) & ~1ull; } while(0)
#define immJ() do { *imm = (SEXT(BITS(i, 31, 31), 1) << 20 | BITS(i, 19, 12) << 12 | BITS(i, 20, 20) << 11 | BITS(i, 30, 21) << 1) & ~1ull;} while (0)

bool csr_valid(Decode *s, uint16_t csr)
{
  CSR_status csr_status = check_csr_exist(csr);
  switch (csr_status)
  {
  case CSR_EXIST:
    return true;
    break;
  case CSR_EXIST_DIFF_SKIP:
    difftest_skip_ref();
    return true;
    break;
  case CSR_NOT_EXIST:
    s->dnpc = isa_raise_intr(MCA_ILLEGAL_INS, s->pc);
    difftest_skip_ref();
    break;
  default:
    panic("Wrong csr_status");
    break;
  }
  return false;
}


static void decode_operand(Decode *s, int *rd, int* rs, word_t *src1, word_t *src2, word_t *imm, int type) {
  uint32_t i = s->isa.inst;
  int rs1 = BITS(i, 19, 15);
  int rs2 = BITS(i, 24, 20);
  *rd     = BITS(i, 11, 7);
  *rs     = rs1;
  switch (type) {
    case TYPE_I: src1R();          immI(); break;
    case TYPE_I_I: *src1 = rs1;    immI(); break;
    case TYPE_U:                   immU(); break;
    case TYPE_S: src1R(); src2R(); immS(); break;
	case TYPE_J: immJ(); break;
	case TYPE_B: src1R(); src2R(); immB(); break;
	case TYPE_R: src1R(); src2R(); break;
    case TYPE_N: break;
    default: panic("unsupported type = %d", type);
  }
}

static int decode_exec(Decode *s) {
  //printf("decode exec at pc: 0x%x\n", s->pc);

  s->dnpc = s->snpc;

#define INSTPAT_INST(s) ((s)->isa.inst)
#define INSTPAT_MATCH(s, name, type, ... /* execute body */ ) { \
  int rd = 0, rs1 = 0;\
  word_t src1 = 0, src2 = 0, imm = 0; \
  decode_operand(s, &rd, &rs1, &src1, &src2, &imm, concat(TYPE_, type)); \
  __VA_ARGS__ ; \
}

  INSTPAT_START();
  INSTPAT("??????? ????? ????? ??? ????? 01101 11", lui    , U, R(rd) = imm);
  INSTPAT("??????? ????? ????? ??? ????? 00101 11", auipc  , U, R(rd) = s->pc + imm);
  INSTPAT("??????? ????? ????? ??? ????? 11011 11", jal    , J, 
		  s->dnpc = s->pc + imm; 
		  IFDEF(CONFIG_ITRACE, 
		  {
		       if (rd == 1)	{
				   void trace_func_call(paddr_t, paddr_t, bool);
			       trace_func_call(s->pc, s->dnpc, false);
			   }
		  });
		  R(rd) = s->snpc;
  );
  INSTPAT("??????? ????? ????? 000 ????? 11001 11", jalr   , I, 
		  s->dnpc = (src1 + imm) & ~1ull; 
		  IFDEF(CONFIG_ITRACE,
		  {
				if (s->isa.inst == 0x00008067)	{
					void trace_func_ret(paddr_t);
					trace_func_ret(s->pc);
				} else if (rd == 1) {
					void trace_func_call(paddr_t, paddr_t, bool);
					trace_func_call(s->pc, s->dnpc, false);
				} else if (rd == 0 && imm == 0) {
					void trace_func_call(paddr_t, paddr_t, bool); // jr rs1 -> jalr x0, 0(rs1), which may be other control flow e.g. 'goto', 'for'
					trace_func_call(s->pc, s->dnpc, true);
				}
		  });
		  R(rd) = s->snpc
  );
  INSTPAT("??????? ????? ????? 000 ????? 11000 11", beq    , B, s->dnpc = (src1 == src2)? s->pc + imm : s->dnpc);
  INSTPAT("??????? ????? ????? 001 ????? 11000 11", bne    , B, s->dnpc = (src1 != src2)? s->pc + imm : s->dnpc);
  INSTPAT("??????? ????? ????? 100 ????? 11000 11", blt    , B, s->dnpc = ((int32_t)src1 < (int32_t)src2)? s->pc + imm : s->dnpc);
  INSTPAT("??????? ????? ????? 101 ????? 11000 11", bge    , B, s->dnpc = ((int32_t)src1 >= (int32_t)src2)? s->pc + imm : s->dnpc);
  INSTPAT("??????? ????? ????? 110 ????? 11000 11", bltu   , B, s->dnpc = (src1 < src2)? s->pc + imm : s->dnpc);
  INSTPAT("??????? ????? ????? 111 ????? 11000 11", bgeu   , B, s->dnpc = (src1 >= src2)? s->pc + imm : s->dnpc);
  INSTPAT("??????? ????? ????? 000 ????? 00000 11", lb     , I, int8_t x = Mr(src1 + imm, 1); int32_t y = x; R(rd) = (uint32_t)y);
  INSTPAT("??????? ????? ????? 001 ????? 00000 11", lh     , I, int16_t x = Mr(src1 + imm, 2); int32_t y = x; R(rd) = (uint32_t)y);
  INSTPAT("??????? ????? ????? 010 ????? 00000 11", lw     , I, R(rd) = Mr(src1 + imm, 4));
  INSTPAT("??????? ????? ????? 100 ????? 00000 11", lbu    , I, R(rd) = Mr(src1 + imm, 1));
  INSTPAT("??????? ????? ????? 101 ????? 00000 11", lhu    , I, R(rd) = Mr(src1 + imm, 2));
  INSTPAT("??????? ????? ????? 000 ????? 01000 11", sb     , S, Mw(src1 + imm, 1, src2));
  INSTPAT("??????? ????? ????? 001 ????? 01000 11", sh     , S, Mw(src1 + imm, 2, src2));
  INSTPAT("??????? ????? ????? 010 ????? 01000 11", sw     , S, Mw(src1 + imm, 4, src2));
  INSTPAT("??????? ????? ????? 000 ????? 00100 11", addi   , I, R(rd) = src1 + imm);
  INSTPAT("??????? ????? ????? 010 ????? 00100 11", slti   , I, R(rd) = ((int32_t)src1 < (int32_t)imm) ? 1 : 0);
  INSTPAT("??????? ????? ????? 011 ????? 00100 11", sltiu  , I, R(rd) = (src1 < imm)? 1 : 0);
  // xori
  INSTPAT("??????? ????? ????? 100 ????? 00100 11", xori   , I, R(rd) = src1 ^ imm);
  // ori
  INSTPAT("??????? ????? ????? 110 ????? 00100 11", ori    , I, R(rd) = src1 | imm);
  // andi
  INSTPAT("??????? ????? ????? 111 ????? 00100 11", andi   , I, R(rd) = src1 & imm);
  // slli
  INSTPAT("0000000 ????? ????? 001 ????? 00100 11", slli   , I, R(rd) = src1 << BITS(imm, 4, 0));
  // srli
  INSTPAT("0000000 ????? ????? 101 ????? 00100 11", srli   , I, R(rd) = src1 >> BITS(imm, 4, 0));
  // srai
  INSTPAT("0100000 ????? ????? 101 ????? 00100 11", srai   , I, R(rd) = (int32_t)src1 >> BITS(imm, 4, 0));
  INSTPAT("0000000 ????? ????? 000 ????? 01100 11", add    , R, R(rd) = src1 + src2);
  INSTPAT("0100000 ????? ????? 000 ????? 01100 11", sub    , R, R(rd) = src1 - src2);
  // sll
  INSTPAT("0000000 ????? ????? 001 ????? 01100 11", sll    , R, R(rd) = src1 << BITS(src2, 4, 0));
  // slt
  INSTPAT("0000000 ????? ????? 010 ????? 01100 11", slt    , R, R(rd) = (int32_t)src1 < (int32_t)src2 ? 1 : 0);
  INSTPAT("0000000 ????? ????? 011 ????? 01100 11", sltu   , R, R(rd) = (src1 < src2)? 1 : 0);
  INSTPAT("0000000 ????? ????? 100 ????? 01100 11", xor    , R, R(rd) = src1 ^ src2);
  // srl
  INSTPAT("0000000 ????? ????? 101 ????? 01100 11", srl    , R, R(rd) = src1 >> BITS(src2, 4, 0));
  // sra
  INSTPAT("0100000 ????? ????? 101 ????? 01100 11", sra    , R, R(rd) = (int32_t)src1 >> BITS(src2, 4, 0));
  INSTPAT("0000000 ????? ????? 110 ????? 01100 11", or     , R, R(rd) = src1 | src2);
  // and
  INSTPAT("0000000 ????? ????? 111 ????? 01100 11", and    , R, R(rd) = src1 & src2);
  INSTPAT("0000001 ????? ????? 110 ????? 01100 11", rem, R, R(rd) = (sword_t)src1 % (sword_t)src2);
  INSTPAT("0000001 ????? ????? 111 ????? 01100 11", remu, R, R(rd) = (word_t)src1 % (word_t)src2);
  INSTPAT("0000001 ????? ????? 000 ????? 01100 11", mul    , R, R(rd) = src1 * src2);
  INSTPAT("0000001 ????? ????? 100 ????? 01100 11", div, R, R(rd) = ((sword_t)src2 == 0) ? ~0 : (sword_t)src1 / (sword_t)src2);
  INSTPAT("0000001 ????? ????? 101 ????? 01100 11", divu, R, R(rd) = ((word_t)src2 == 0) ? ~0 : (word_t)src1 / (word_t)src2);
  INSTPAT("0000001 ????? ????? 001 ????? 01100 11", mulh   , R, int64_t signed_src1 = (int32_t)src1; int64_t signed_src2 = (int32_t)src2; int64_t product = signed_src1 * signed_src2; R(rd) = product >> 32);
  INSTPAT("0000001 ????? ????? 010 ????? 01100 11", mulhsu, R, R(rd) = ((int64_t)(sword_t)src1 * (int64_t)(word_t)src2) >> 32);
  INSTPAT("0000001 ????? ????? 011 ????? 01100 11", mulhu, R, R(rd) = ((int64_t)(word_t)src1 * (int64_t)(word_t)src2) >> 32);
  // fence
  // fence.i
  // ecall
  INSTPAT("0000000 00000 00000 000 00000 11100 11", ecall, N,
            s->dnpc = isa_raise_intr(
                //((cpu.priv == PRV_U) ? MCA_ENV_CAL_UMO : ((cpu.priv == PRV_S) ? MCA_ENV_CAL_SMO : MCA_ENV_CAL_MMO)),
                MCA_ENV_CAL_MMO,
                s->pc));
  // ebreak
  // #if defined(CONFIG_DEBUG)
    INSTPAT("0000000 00001 00000 000 00000 11100 11", ebreak, N, NEMUTRAP(s->pc, R(10))); // R(10) is $a0
  // #else
    // INSTPAT("0000000 00001 00000 000 00000 11100 11", ebreak, N, { s->dnpc = isa_raise_intr(MCA_BREAK_POINT, s->pc); });
  // #endif
  // mret
  INSTPAT("0011000 00010 00000 000 00000 11100 11", mret, N, 
    s->dnpc = CSR(CSR_MEPC);
    word_t mstatus = CSR(CSR_MSTATUS);
    word_t mpie = (mstatus >> 7) & 1;          // 提取 MPIE
    mstatus = (mstatus & ~(1 << 3)) | (mpie << 3); // MIE = MPIE
    mstatus |= (1 << 7);                       // MPIE = 1
    // mstatus |= (3 << 11);                   // 保持 MPP 为 M 模式 (可选)
    CSR(CSR_MSTATUS) = mstatus;
          );
  // csrrw
  // csrrs
  // csrrc
  // csrrwi
  // cssrrsi
  // csrrci
  INSTPAT("??????? ????? ????? 001 ????? 11100 11", csrrw, I, { if (csr_valid(s, imm)) {R(rd) = CSR(imm); CSR(imm) = src1; } });
  INSTPAT("??????? ????? ????? 010 ????? 11100 11", csrrs, I, { if (csr_valid(s, imm)) {R(rd) = CSR(imm); if (rs1 != 0) { CSR(imm) = CSR(imm) | src1;}; } });
  INSTPAT("??????? ????? ????? 011 ????? 11100 11", csrrc, I, { if (csr_valid(s, imm)) {R(rd) = CSR(imm); if (rs1 != 0) { CSR(imm) = CSR(imm) & ~src1;}; } });
  INSTPAT("??????? ????? ????? 101 ????? 11100 11", csrrwi, I_I, { if (csr_valid(s, imm)) { R(rd) = CSR(imm); CSR(imm) = src1;} });
  INSTPAT("??????? ????? ????? 110 ????? 11100 11", csrrsi, I_I, { if (csr_valid(s, imm)) { R(rd) = CSR(imm); if (rs1 != 0) { CSR(imm) = CSR(imm) | src1; };} });
  INSTPAT("??????? ????? ????? 111 ????? 11100 11", csrrci, I_I, { if (csr_valid(s, imm)) { R(rd) = CSR(imm); if (rs1 != 0) { CSR(imm) = CSR(imm) & ~src1; };} });
  INSTPAT("??????? ????? ????? ??? ????? ????? ??", inv    , N, INV(s->pc));
  INSTPAT_END();

  R(0) = 0; // reset $zero to 0

  // printf("isa_display:\n");
  // isa_reg_display();
  return 0;
}

#ifdef CONFIG_NPC
static int npc_exec(Decode *s) {
  // top->inst = s->isa.inst;
  // Change temporary. LY
  cpu_exec_once();
  update_cpu_state(nemu_state);
  #ifdef CONFIG_SYS_SOC
  #ifdef CONFIG_NVBOARD
  nvboard_update();
  #endif
  #endif
  s->isa.inst = *(nemu_state.inst);
  s->snpc = s->pc + 4;  // RISC-V instructions are always 4 bytes
  return 0;
}
#endif

int isa_exec_once(Decode *s) {

  #ifndef CONFIG_NPC
  s->isa.inst = inst_fetch(&s->snpc, 4);
  #endif

  #ifdef CONFIG_NPC
  if (*(nemu_state.difftest_signal) == 1) {
   // uint32_t inst = s->isa.inst;
    uint32_t inst = *(nemu_state.inst);
    // printf("0x%x\n", inst);
    IFDEF(CONFIG_ITRACE, {
      // --- JAL: opcode = 0x6f ---
      if ((inst & 0x7f) == 0x6f) {
        int rd = (inst >> 7) & 0x1f;
        if (rd == 1) {
          // Decode J-type immediate (same as NEMU's immJ)
          sword_t imm = (
            ((inst >> 31) & 1 ? 0xfffffffffffff000ULL : 0) |   // sign bit (bit 20)
            ((inst >> 21) & 0x3ff) << 1 |                      // bits 10:1
            ((inst >> 20) & 1) << 11 |                         // bit 11
            ((inst >> 12) & 0xff) << 12                        // bits 19:12
          );
          paddr_t target = s->pc + imm;
          void trace_func_call(paddr_t, paddr_t, bool);
          trace_func_call(s->pc, target, false);
        }
      }
      // --- JALR: opcode = 0x67, funct3 = 000 ---
      else if ((inst & 0x707f) == 0x67) {
        int rd  = (inst >> 7) & 0x1f;
        int rs1 = (inst >> 15) & 0x1f;
        sword_t imm = (sword_t)(int32_t)(inst >> 20); // sign-extended imm[11:0]

        // Compute actual jump target: (gpr[rs1] + imm) & ~1
        word_t src1_val = nemu_state.gpr[rs1]; // ✅ 从 nemu_state 读取寄存器值
        paddr_t target = (src1_val + imm) & ~1ULL;

        if (inst == 0x00008067) {
          // jalr x0, 0(x1) — conventional function return
          void trace_func_ret(paddr_t);
          trace_func_ret(s->pc);
        }
        else if (rd == 1) {
          // Function call: link register is x1 (ra)
          void trace_func_call(paddr_t, paddr_t, bool);
          trace_func_call(s->pc, target, false);
        }
        else if (rd == 0 && imm == 0) {
          // Indirect jump: jalr x0, 0(rs1) — e.g., goto, switch, tail call
          void trace_func_call(paddr_t, paddr_t, bool);
          trace_func_call(s->pc, target, true); // mark as indirect
        }
      }
    });
  }
  return npc_exec(s);
  #else
  return decode_exec(s);
  #endif
}
