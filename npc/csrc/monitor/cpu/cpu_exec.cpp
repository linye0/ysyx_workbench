#include "verilated.h"
#include <common.h>
#include <cstdint>
#include <cstdio>
#include <difftest.h>
#include <readline/readline.h>
#include <readline/history.h>
#include <npc_verilog.h>
#include <memory.h>
#include <verilated_vcd_c.h>


#define MAX_INST_TO_PRINT 10
#define MAX_IRING_SIZE 16

extern NPCState npc;

extern VerilatedContext* contextp;
extern VerilatedVcdC* tfp;
extern TOP_NAME* top;
extern const uint32_t img[];

void trace_func_call(uint32_t pc, uint32_t next_pc, bool is_ret);
void trace_func_ret(uint32_t pc);
void itrace_display_history(int num);

struct DecodedInst {
    uint32_t opcode;
    uint32_t rd;
    uint32_t func3;
    uint32_t rs1;
    uint32_t rs2;
    uint32_t func7;
};

DecodedInst decode_inst(uint32_t inst) {
    DecodedInst d;
    d.opcode = inst & 0x7F;
    d.rd     = (inst >> 7)  & 0x1F;
    d.func3  = (inst >> 12) & 0x7;
    d.rs1    = (inst >> 15) & 0x1F;
    d.rs2    = (inst >> 20) & 0x1F;
    d.func7  = (inst >> 25) & 0x7F;
    return d;
}

void cpu_exec_one_cycle() {
    top->clk = (top->clk == 0) ? 1 : 0;
    top->eval();
    if (tfp) {
        tfp->dump(contextp->time());
    }
    contextp->timeInc(1);

    top->clk = (top->clk == 0) ? 1 : 0;
    top->eval();
    if (tfp) {
        tfp->dump(contextp->time());
    }
    contextp->timeInc(1);
}

void ftrace(paddr_t pc, paddr_t target) {
    DecodedInst deinst = decode_inst(*npc.inst);
	if (deinst.opcode == 0b1101111) {
		if (deinst.rd == 1) {
			trace_func_call(pc, target, false);
		}
	}
	if (deinst.func3 == 0b000 && deinst.opcode == 0b1100111) {
		if (top->inst == 0x00008067)	{
			trace_func_ret(target);
		} else if (deinst.rd == 1) {
			trace_func_call(pc, target, false);
		} else if (deinst.rd == 0 && top->imm_32 == 0) {
			trace_func_call(pc, target, true);
		}
	}
}

void cpu_exec(uint64_t n)
{
    int origin_n = n;
    switch (npc.state)
    {
    case NPC_END:
    case NPC_ABORT:
        printf("Program execution has ended. To  threstarte program, NPC and run again.\n");
        return;
    case NPC_QUIT:
        printf("Program execution has been quitted.\n");
        break;
    default:
        npc.state = NPC_RUNNING;
        break;
    }
    
    uint64_t cur_inst_cycle = 0;
    while (!contextp->gotFinish() && npc.state == NPC_RUNNING && n-- > 0) {
	    top->inst = local_pmem_read(top->pc);
        if (origin_n != -1) printf("pc: %0x, inst: %0x\n", top->pc, top->inst);
        uint32_t origin_pc = top->pc;
        cpu_exec_one_cycle();

        #ifdef CONFIG_ITRACE
        void disassemble(char* str, int size, uint64_t pc, uint8_t* code, int nbyte);
        char disasm_str[256];
        uint32_t inst = top->inst;
        disassemble(disasm_str, sizeof(disasm_str), top->pc, (uint8_t*)&inst, sizeof(inst));
        if (origin_n != -1) printf("command: %s\n", disasm_str);
        void print_all_regs();
        // printf("pc: %08x, command: %s\n", origin_pc, disasm_str);
        char log_buf[512];
        snprintf(log_buf, sizeof(log_buf), "pc: 0x%08x, inst: 0x%08x, %s", top->pc, top->inst, disasm_str);
        void itrace_record(const char* log, vaddr_t pc);
        itrace_record(log_buf, top->pc);
        #endif

        #ifdef CONFIG_FTRACE
        void ftrace(paddr_t pc, paddr_t target);
        ftrace(origin_pc, *npc.cpc);
        #endif

        if (npc.state == NPC_END) {
            break;    
        }

        #ifdef CONFIG_DIFFTEST
        difftest_step(*npc.cpc);
        #endif
        npc.last_inst = *(npc.inst);
        int wp_difftest(void);
        wp_difftest();
    }

    if (origin_n == -1) {
        #ifdef CONFIG_ITRACE
        itrace_display_history(10);
        #endif
    }

    switch (npc.state)
    {
        case NPC_RUNNING:
            npc.state = NPC_STOP;
            break;
        case NPC_END:
        case NPC_ABORT:
            Log("Program execution has ended or aborted.");
            if (npc.state == NPC_ABORT) {
                itrace_display_history(10);
            }
            break;
        case NPC_QUIT:
            Log("Program quit.");
        break;
        case NPC_STOP:
            break;
        default:
            assert(0);
        break;
    }
}