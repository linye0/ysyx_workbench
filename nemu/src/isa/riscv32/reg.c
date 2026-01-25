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
#include <common.h>
#include "local-include/reg.h"

const char *regs[] = {
  "$0", "ra", "sp", "gp", "tp", "t0", "t1", "t2",
  "s0", "s1", "a0", "a1", "a2", "a3", "a4", "a5",
  "a6", "a7", "s2", "s3", "s4", "s5", "s6", "s7",
  "s8", "s9", "s10", "s11", "t3", "t4", "t5", "t6"
};

void isa_reg_display() {
    bool success = false;
    #ifdef CONFIG_NPC
    printf("%-16s0x%-16x%d\n", "pc", cpu.cpc, cpu.cpc);
    #else
    printf("%-16s0x%-16x%d\n", "pc", cpu.pc, cpu.pc); // 为了输出美观
    #endif
    for (int i = 0; i < sizeof(regs) / sizeof(const char*); i++) {                                            
        word_t val = isa_reg_str2val(regs[i], &success);
        printf("%-16s0x%-16x%d\n", regs[i], val, val); // 为了输出美观
    }
}

word_t isa_reg_str2val(const char *s, bool *success) {
	if (strcmp(s, "pc") == 0) {
		*success = true;
        #ifdef CONFIG_NPC
		return cpu.cpc;
        #else
        return cpu.pc;
        #endif
	}
    if (strcmp(s, "mstatus") == 0)
    {
        *success = true;
        return cpu.sr[CSR_MSTATUS];
    }
    if (strcmp(s, "mepc") == 0)
    {
        *success = true;
        return cpu.sr[CSR_MEPC];
    }
    if (strcmp(s, "mtvec") == 0)
    {
        *success = true;
        return cpu.sr[CSR_MTVEC];
    }
    if (strcmp(s, "mcause") == 0)
    {
        *success = true;
        return cpu.sr[CSR_MCAUSE];
    }
   for (int i = 0; i < sizeof(regs) / sizeof(const char*); i++) {
        if (strcmp(s, regs[i]) == 0) {
            *success = true;
            /* 变量cpu定义于$NEMU_HOME/src/cpu/cpu-exec.c: CPU_state cpu = {};
               声明见文件$NEMU_HOME/include/isa.h: extern CPU_state cpu; */
            return cpu.gpr[i];  // 数组regs的声明顺序与riscv32的定义一致
        }
    }

    *success = false;
    return 0;
}
