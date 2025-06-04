#pragma once
#include <cstdint>
#ifndef __NPC_VERILOG_H__
#define __NPC_VERILOG_H__

#include <common.h>
#include <cpu.h>

#include CONCAT_HEAD(TOP_NAME)
#include CONCAT_HEAD(CONCAT(TOP_NAME, ___024root))
#include CONCAT_HEAD(CONCAT(TOP_NAME, __Dpi))

#define VERILOG_PREFIX top->rootp->ysyxSoC__DOT__cpu__DOT__
#define VERILOG_RESET top->reset

static inline void verilog_connect(TOP_NAME *top, NPCState *npc)
{
  // for difftest
  npc->inst = (uint32_t *)&(top->rootp->inst);
  npc->gpr = (word_t *)&(top->rootp->ysyx_25040131_cpu__DOT__REG_FILE__DOT__regs);
  npc->cpc = (uint32_t *)&(top->rootp->pc);
  npc->pc = (uint32_t *)&(top->rootp->next_pc);
  npc->state = NPC_RUNNING;
}


#endif