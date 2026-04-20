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

#include "isa/isa-def.h"
#include <isa.h>

word_t isa_raise_intr(word_t NO, vaddr_t epc) {
  #ifdef CONFIG_ETRACE
  printf("ETRACE | NO: %d at epc: " FMT_WORD " trap-handler base address: " FMT_WORD "\n",
         NO, epc, cpu.sr[CSR_MTVEC]);
  #endif

  word_t tval = 0;

  switch (NO) {
    case MCA_BREAK_POINT:
      tval = epc;
      break;
    case MCA_ENV_CAL_MMO:
    case MCA_ENV_CAL_SMO:
    case MCA_ENV_CAL_UMO:
      tval = 0;
      break;
    default:
      break;
  }

  cpu.sr[CSR_MTVAL] = tval;
  cpu.sr[CSR_MEPC] = epc;
  cpu.sr[CSR_MCAUSE] = NO;

  // 补全 NEMU 缺失的 mstatus 状态机更新
  word_t mstatus = cpu.sr[CSR_MSTATUS];
  word_t mie = (mstatus >> 3) & 0x1;       // 提取 MIE (第3位)
  
  mstatus = (mstatus & ~(1 << 7)) | (mie << 7); // MPIE = MIE
  mstatus = mstatus & ~(1 << 3);                // MIE = 0
  mstatus = mstatus | (3 << 11);                // MPP = 3 (Machine Mode)
  
  cpu.sr[CSR_MSTATUS] = mstatus;           // 写回

  return cpu.sr[CSR_MTVEC];
}

word_t isa_query_intr() {
  return INTR_EMPTY;
}
