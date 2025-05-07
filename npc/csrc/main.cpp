#include "verilated_vcd_c.h" //可选，如果要导出vcd则需要加上
#include "Vysyx_25040131_cpu.h"
#include "stdio.h"
#include <stdlib.h>
#include <bits/stdc++.h>
#include <nvboard.h>

static Vysyx_25040131_cpu dut;
extern "C" void npc_trap();
extern "C" uint32_t get_flag();
uint32_t *init_mem(size_t size);
uint32_t guest_to_host(uint32_t addr);
uint32_t pmem_read(uint32_t *memory, uint32_t vaddr);
uint32_t read_img(uint32_t*, const char*);
uint32_t endflag = 0;
char* bin_path;
 
static void single_cycle() {
	dut.clk = 0; dut.eval();
	dut.clk = 1; dut.eval();
}

static void reset(int n) {
	dut.rst = 1;
	while (n-- > 0) single_cycle();
	dut.rst = 0;
}

int main(int argc, char **argv)
{
	for (int i = 0; i < argc; i++) {
		if (i == 1) {
			bin_path = argv[i];
		}
	}
	uint32_t *memory;
	endflag = 0;
	
	memory = init_mem(100);
	read_img(memory, bin_path);
	for (int i = 0; i < 100; i++) {
		printf("memory[%d]: %x\n", i, memory[i]);
	}

	Verilated::traceEverOn(true);
	VerilatedContext* contextp = new VerilatedContext;
	VerilatedVcdC* m_trace = new VerilatedVcdC;
	dut.trace(m_trace, 5);
	m_trace->open("waveform.vcd");

	reset(10);
	while (get_flag() != 1) {
		dut.inst = pmem_read(memory, dut.pc);
		printf("dut.inst: %x\n", dut.inst);
		single_cycle();
		m_trace->dump(contextp -> time());
		contextp->timeInc(1);
		if (get_flag() == 1) {
			printf("main.cpp: stop.\n");
		}
	}

	m_trace -> close();

    return 0;
}
