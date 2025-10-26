#pragma once
#ifndef __NPC_NPC_VERILOG_H__
#define __NPC_NPC_VERILOG_H__

#include <utils.h>
#include <stdint.h>
#include <common.h>


#ifdef CONFIG_NPC
// #ifdef CONFIG_DEVICE
// #endif
#include "verilated.h"
#include "verilated_vcd_c.h"

#include CONCAT_HEAD(TOP_NAME)
#include CONCAT_HEAD(CONCAT(TOP_NAME, ___024root))
#include CONCAT_HEAD(CONCAT(TOP_NAME, __Dpi))


#define VERILOG_PREFIX top->rootp->ysyxSoC__DOT__cpu__DOT__
#define VERILOG_RESET top->reset


void verilog_connect(TOP_NAME *top, NPCState *npc);

void init_verilog(int argc, char* argv[]);

void cpu_exec_once();

extern VerilatedContext* contextp;
extern VerilatedVcdC* tfp;
extern TOP_NAME* top;


#endif

#endif