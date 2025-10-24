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
#include <isa.h>
#include <cpu/cpu.h>
#include <difftest-def.h>
#include <memory/paddr.h>
#include <sys/types.h>
#include <npc/npc_verilog.h>

__EXPORT word_t difftest_paddr_read(paddr_t addr, int len) {
  return paddr_read(addr, len);
}

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
  CPU_state *npc = (CPU_state *)dut;
  if (direction == DIFFTEST_TO_REF) {
    cpu.pc = npc->pc;
    for (int i = 0; i < 32; i++) {
      cpu.gpr[i] = npc->gpr[i];
    } 
  } else if (direction == DIFFTEST_TO_DUT) {
    npc->pc = cpu.pc;
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
