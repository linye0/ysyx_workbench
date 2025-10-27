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
  /* TODO: Trigger an interrupt/exception with ``NO''.
   * Then return the address of the interrupt/exception vector.
   */

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

  word_t ret_pc = 0;

  cpu.sr[CSR_MTVAL] = tval;
  cpu.sr[CSR_MEPC] = epc;
  cpu.sr[CSR_MCAUSE] = NO;

  ret_pc = cpu.sr[CSR_MTVEC];

  return ret_pc;
}

word_t isa_query_intr() {
  return INTR_EMPTY;
}
