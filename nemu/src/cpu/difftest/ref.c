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
#include <cpu/cpu.h>
#include <difftest-def.h>
#include <memory/paddr.h>

typedef struct
{
  int state;
  word_t *gpr;
  //word_t *ret;
  word_t *pc;

  // csr
  /*
  word_t *sstatus;
  word_t *sie____;
  word_t *stvec__;

  word_t *scounte;

  word_t *sscratch;
  word_t *sepc___;
  word_t *scause_;
  word_t *stval__;
  word_t *sip____;
  word_t *satp___;

  word_t *mstatus;
  word_t *misa___;
  word_t *medeleg;
  word_t *mideleg;
  word_t *mie____;
  word_t *mtvec__;

  word_t *mstatush;

  word_t *mscratch;
  word_t *mepc___;
  word_t *mcause_;
  word_t *mtval__;
  word_t *mip____;

  word_t *mcycle_;
  word_t *time___;
  word_t *timeh__;
  */

  // for mem diff
  /*
  word_t vwaddr;
  word_t pwaddr;
  word_t wdata;
  word_t wstrb;
  word_t len;
  */

  // for itrace
  uint32_t *inst;
  word_t *cpc;
  uint32_t last_inst;

  // for soc
  // uint8_t *soc_sram;
} NPCState;

__EXPORT void difftest_memcpy(paddr_t addr, void *buf, size_t n, bool direction) {
  if (direction == DIFFTEST_TO_REF) {
    if (in_pmem(addr)) {
      memcpy(guest_to_host(addr), buf, n);
      return;
    }
    Assert(0, "DIFFTEST_TO_REF: addr = " FMT_PADDR " is not in pmem", addr);
  } else {
    if (in_pmem(addr)) {
      memcpy(buf, guest_to_host(addr), n);
      return;
    }
    Assert(0, "DIFFTEST_TO_DUT: addr = " FMT_PADDR " is not in pmem", addr);
  }
}

__EXPORT void difftest_regcpy(void *dut, bool direction) {
  NPCState *npc = (NPCState *)dut;
  if (direction == DIFFTEST_TO_REF) {
    cpu.pc = *npc->cpc;
    for (int i = 0; i < 32; i++) {
      cpu.gpr[i] = npc->gpr[i];
    } 
  } else if (direction == DIFFTEST_TO_DUT) {
    npc->cpc = &cpu.pc;
    for (int i = 0; i < 32; i++) {
      npc->gpr[i] = cpu.gpr[i];
    }
  }
}

__EXPORT void difftest_exec(uint64_t n) {
  cpu_exec(n);
}

__EXPORT void difftest_raise_intr(word_t NO) {
  assert(0);
}

__EXPORT void difftest_init(int port) {
  void init_mem();
  init_mem();
  /* Perform ISA dependent initialization. */
  init_isa();
}
