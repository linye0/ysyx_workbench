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

#define CAL_INST 0
#define MEM_INST 1
#define CTRL_INST 2
#define SYS_INST 3
#define OTHER_INST 4


#include CONCAT_HEAD(TOP_NAME)
#include CONCAT_HEAD(CONCAT(TOP_NAME, ___024root))
#include CONCAT_HEAD(CONCAT(TOP_NAME, __Dpi))

#define VERILOG_PREFIX top->rootp->ysyxSoC__DOT__cpu__DOT__
#define VERILOG_RESET top->reset

typedef struct perfmetrics {
    int prev_cycle;
    int total_cycle;
    int total_inst;
    int ifu_fetch_count;
    int lsu_read_count;
    int lsu_write_count;
    int inst_count[5];
    int inst_cycle[5];
    int cur_inst_type;
} PerfMetrics;

extern PerfMetrics perf;

void print_performance_metrics();

void verilog_connect(TOP_NAME *top, NPCState *npc);

void init_verilog(int argc, char* argv[]);

void cpu_exec_once();

extern VerilatedContext* contextp;
extern VerilatedVcdC* tfp;
extern TOP_NAME* top;


#endif

#endif