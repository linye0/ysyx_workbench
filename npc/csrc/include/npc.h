#ifndef __NPC_H__ 
#define __NPC_H_

#include "verilated_vcd_c.h"
#include "Vysyx_25040131_cpu.h"
#include "stdio.h"
#include <stdlib.h>
#include <bits/stdc++.h>
#include <macro.h>

#define STATE_QUIT 2
#define STATE_RUNNING 1
#define STATE_GOOD_TRAP 0

extern "C" void npc_trap();
extern "C" void update_gpr_mirror(int index, int value);

void print_all_regs();

class NPC {
	public:		
		void init_npc(char* img_path);
		int exit_npc();
		uint32_t get_state();
		uint32_t *init_mem(size_t size);
		uint32_t guest_to_host(uint32_t addr);
		uint32_t pmem_read(uint32_t vaddr);
		uint32_t read_img(uint32_t*, const char*);
		void single_cycle();
		void reset(int n);
		void set_state(int state);
		void npc_exec(int n);
		void print_reg(int idx);
		uint32_t get_reg(int idx);
		uint32_t get_pc();
		void set_mirror_reg(int idx, int value);
	private:
		Vysyx_25040131_cpu dut;
		VerilatedContext* contextp;
		VerilatedVcdC* m_trace;
		uint32_t* memory;
		int npc_state;
		uint32_t gpr_regs[32] = {0};
};

extern NPC npc;

#endif

