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
    uint64_t prev_cycle;      // 修改为 uint64_t
    uint64_t total_cycle;     // 修改为 uint64_t
    uint64_t total_inst;      // 修改为 uint64_t
    uint64_t ifu_fetch_count;
    uint64_t lsu_read_count;
    uint64_t lsu_write_count;
    uint64_t inst_count[5];
    uint64_t inst_cycle[5];
    uint64_t icache_hit_count;
    uint64_t icache_miss_count;
    uint64_t icache_miss_cycle;
    int cur_inst_type;        // 类型可以用 int
} PerfMetrics;

extern PerfMetrics perf;

void print_performance_metrics();

void verilog_connect(TOP_NAME *top, NPCState *npc);

void init_verilog(int argc, char* argv[]);

void cpu_exec_once();

extern VerilatedContext* contextp;
extern VerilatedVcdC* tfp;
extern TOP_NAME* top;

extern uint32_t g_wb_cpc;
extern uint32_t g_wb_npc;
extern bool     g_wb_valid;

extern uint32_t g_st_waddr;
extern uint32_t g_st_wdata;
extern uint32_t g_st_wstrb;
extern bool     g_st_valid;

#endif

#endif