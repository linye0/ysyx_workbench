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

#include <isa.h>
#include <cpu/difftest.h>
#include "../local-include/reg.h"
#include "isa/isa-def.h"

#define CHECK_CSR(name)                                                                \
  if (cpu.sr[name] != ref_r->sr[name])                                                 \
  {                                                                                    \
    printf(ANSI_FMT("Difftest: %12s: " FMT_WORD ", ref: " FMT_WORD "\n", ANSI_FG_RED), \
           #name, cpu.sr[name], ref_r->sr[name]);                                      \
    is_same = false;                                                                   \
  }

bool isa_difftest_checkregs(CPU_state *ref_r, vaddr_t pc) {
	bool is_same = true;
	int reg_num = ARRLEN(cpu.gpr);
	for (int i = 0; i < reg_num; i++) {
		if (ref_r->gpr[i] != cpu.gpr[i]) {
			printf("\ndifftest error: regs aren't consistent\nref.gpr[%d] = 0x%x, dut.gpr[%d] = 0x%x\n", i, ref_r->gpr[i], i, cpu.gpr[i]);
			printf("ref_regs:\n");
			for (int i = 0; i < reg_num; i++) {
				printf("%-16d0x%-16x%d\n", i, ref_r->gpr[i], ref_r->gpr[i]); // 为了输出美观
			}
			is_same = false;
		}
	}
	if (ref_r->pc != cpu.pc) {
		printf("pc not equal! ref->pc: 0x%x, cpu.pc: 0x%x\n", ref_r->pc, cpu.pc);
		is_same = false;
	}
	#ifdef CONFIG_NPC
	CHECK_CSR(CSR_MTVEC);
	CHECK_CSR(CSR_MCAUSE);
	CHECK_CSR(CSR_MEPC);
	// 有些MSTATUS的功能还没实现
	CHECK_CSR(CSR_MSTATUS);
	CHECK_CSR(CSR_MTVAL);
	#endif
	return is_same;
}

void isa_difftest_attach() {
}
