#include "npc.h"
 
static void single_cycle() {
	dut.clk = 0; dut.eval();
	dut.clk = 1; dut.eval();
}

static void reset(int n) {
	dut.rst = 1;
	while (n-- > 0) single_cycle();
	dut.rst = 0;
}

void init_dut(int argc, char** argv) {
	printf("Ready to initialize the memory.\n");
	for (int i = 0; i < argc; i++) {
		if (i == 1) bin_path = argv[i];
	}
	endflag = 0;
	memory = init_mem(200);
	read_img(memory, bin_path);
	printf("Successfully initialize the memory.\n");
	for (int i = 0; i < 200; i++) {
		printf("memory[%d]: %x\n", i, memory[i]);
	}
}

int main(int argc, char **argv)
{
	init_dut(argc, argv);
	Verilated::traceEverOn(true);
	VerilatedContext* contextp = new VerilatedContext;
	VerilatedVcdC* m_trace = new VerilatedVcdC;
	dut.trace(m_trace, 5);
	m_trace->open("waveform.vcd");

	reset(10);
	int step = 0;
	while (get_flag() != 1) {
		dut.inst = pmem_read(memory, dut.pc);
		printf("dut.pc: %x, dut.inst: %x\n", dut.pc, dut.inst);
		single_cycle();
		m_trace->dump(contextp -> time());
		contextp->timeInc(1);
	}

	m_trace -> close();

    return 0;
}
