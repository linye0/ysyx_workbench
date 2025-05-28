#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <fstream>
#include <cstdint>
#include <array>
#include <npc.h>
#include <common.h>
#include <difftest.h>

NPC npc;

extern "C" void update_gpr_mirror(int index, int value) {
	if (index >= 0 && index < 32) {
		npc.set_mirror_reg(index, value);
	}
	return;
}

extern "C" void npc_trap() {
	npc.set_state(STATE_GOOD_TRAP);
	return;
}

uint32_t NPC::get_pc(void) {
	return dut.pc;
}

uint32_t NPC::get_reg(int idx) {
	return gpr_regs[idx];
}

void NPC::set_mirror_reg(int index, int value) {
	gpr_regs[index] = value;
	return;
}

uint32_t NPC::get_state() {
	return npc_state;
}

void NPC::set_state(int state) {
	npc_state = state;
	return;
}

void NPC::print_reg(int idx) {
	printf("x%02d = 0x%08x\n", idx, gpr_regs[idx]);
	return;
}

uint32_t* NPC::init_mem(size_t size) {
	memory = (uint32_t*)malloc(size * sizeof(uint32_t));
	return memory;
}

uint32_t NPC::guest_to_host(uint32_t addr) {return addr - 0x80000000;}
uint32_t NPC::pmem_read(uint32_t vaddr) {
	uint32_t paddr = guest_to_host(vaddr);
	return memory[paddr/4];
}

void NPC::single_cycle() {
	dut.clk = 0; dut.eval();
	dut.clk = 1; dut.eval();
}

void NPC::reset(int n) {
	dut.rst = 1;
	while (n-- > 0) single_cycle();
	dut.rst = 0;
}

uint32_t NPC::read_img(uint32_t* mem, const char* bin_path) {
    // 打开文件（二进制模式）
    std::ifstream file(bin_path, std::ios::binary | std::ios::ate);
    if (!file.is_open()) {
        throw std::runtime_error("Failed to open file: " + std::string(bin_path));
    }

    // 获取文件大小
    const auto file_size = file.tellg();
    file.seekg(0, std::ios::beg);

    // 计算元素数量
    const uint32_t num_elements = file_size / sizeof(uint32_t);

    // 读取文件内容到内存
    if (!file.read(reinterpret_cast<char*>(mem), file_size)) {
        throw std::runtime_error("Failed to read file content");
    }

    return num_elements;
}

void NPC::init_npc(char* img_path) {
	printf("Ready to initialize the memory.\n");
	npc_state = STATE_RUNNING;
	memory = init_mem(200);
	read_img(memory, img_path);
	printf("Successfully initialize the memory.\n");
	Verilated::traceEverOn(true);
	contextp = new VerilatedContext;
	m_trace = new VerilatedVcdC;
	dut.trace(m_trace, 5);
	m_trace->open("waveform.vcd");
	reset(10);
}

int NPC::exit_npc() {
	m_trace->close();
	return npc_state;
}


void NPC::npc_exec(int n) {
	if (get_state() == STATE_PAUSE) set_state(STATE_RUNNING);
	int step = 0;
	while (get_state() == STATE_RUNNING && (step++ < n || n == -1)) {
		dut.inst = pmem_read(dut.pc);
		Log("dut.pc = %x, dut.inst = %x\n", dut.pc, dut.inst);
		#ifdef CONFIG_ITRACE	
		void disassemble(char* str, int size, uint64_t pc, uint8_t* code, int nbyte);
		char disasm_str[256];
		uint32_t inst = dut.inst;
		disassemble(disasm_str, sizeof(disasm_str), dut.pc, (uint8_t*)&inst, sizeof(inst));
		Log("command: %s\n", disasm_str);
		#endif
		single_cycle();
		int diffnum = wp_difftest();
		if (diffnum != 0) {
			set_state(STATE_PAUSE);
			break;
		}
		m_trace->dump(contextp->time());
		contextp->timeInc(1);
	}
	if (get_state() == STATE_GOOD_TRAP) {
		Log("HIT GOOD TRAP!\n");
	} else if (get_state() == STATE_PAUSE) {
		Log("Program pauses.\n");
	} else if (get_state() != STATE_RUNNING) {
		Log("The program has ended, please restart the npc!\n");
	}
}

