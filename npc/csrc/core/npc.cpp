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
#include <utils.h>

/*

class {
	public:
		int opcode;
		int rs1;
		int rs2;
		int rd;
		int func3;
		int func7;
		void print() {
			printf("cur_inst:\nopcode:%0x,\nrs1:%0x,\nrs2:%0x,\nrd:%0x,\nfunc3:%0x,\nfunc7:%0x\n", opcode, rs1, rs2, rd, func3, func7);
		}
		void set(int opcode, int rs1, int rs2, int rd, int func3, int func7) {
			this->opcode = opcode;
			this->rs1 = rs1;
			this->rs2 = rs2;
			this->rd = rd;
			this->func3 = func3;
			this->func7 = func7;
		}
} deinst;

NPC npc;
NPCState npcstate;

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

extern "C" void npc_get_decoded_info(int opcode, int rs1, int rs2, int rd, int func3, int func7) {
	deinst.set(opcode, rs1, rs2, rd, func3, func7);
}

uint32_t NPC::get_pc(void) {
	return dut.pc;
}

uint32_t NPC::get_reg(int idx) {
	return state->gpr_regs[idx];
}

void NPC::set_mirror_reg(int index, int value) {
	state->gpr_regs[index] = value;
	return;
}

uint32_t NPC::get_state() {
	return state->npc_state;
}

void NPC::set_state(int state) {
	this->state->npc_state = state;
	return;
}

void NPC::print_reg(int idx) {
	printf("x%02d = 0x%08x\n", idx, state->gpr_regs[idx]);
	return;
}

uint32_t* NPC::init_mem(size_t size) {
	memory = (uint32_t*)malloc(size * sizeof(uint32_t));
	return memory;
}

uint32_t guest_to_host(uint32_t addr) {return addr - 0x80000000;}
uint32_t pmem_read(uint32_t vaddr) {
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
	this->state = &npcstate;
	set_state(STATE_RUNNING);
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
	return state->npc_state;
}

void NPC::ftrace() {
	if (deinst.opcode == 0b1101111) {
		if (deinst.rd == 1) {
			trace_func_call(dut.pc, dut.next_pc, false);
		}
	}
	if (deinst.func3 == 0b000 && deinst.opcode == 0b1100111) {
		if (dut.inst == 0x00008067)	{
			trace_func_ret(dut.pc);
		} else if (deinst.rd == 1) {
			trace_func_call(dut.pc, dut.next_pc, false);
		} else if (deinst.rd == 0 && dut.imm_32 == 0) {
			trace_func_call(dut.pc, dut.next_pc, true);
		}
	}
}

void NPC::exec_once() {
		single_cycle();
		#ifdef CONFIG_ITRACE	
		void disassemble(char* str, int size, uint64_t pc, uint8_t* code, int nbyte);
		char disasm_str[256];
		uint32_t inst = dut.inst;
		disassemble(disasm_str, sizeof(disasm_str), dut.pc, (uint8_t*)&inst, sizeof(inst));
		Log("command: %s\n", disasm_str);
		char log_buf[512];
		snprintf(log_buf, sizeof(log_buf), "pc: 0x%08x, inst: 0x%08x, %s", dut.pc, dut.inst, disasm_str);
		void itrace_record(const char* log, vaddr_t pc);
		itrace_record(log_buf, dut.pc);
		ftrace();
		#endif
}

void NPC::npc_exec(int n) {
	if (get_state() == STATE_PAUSE) set_state(STATE_RUNNING);
	int step = 0;
	while (get_state() == STATE_RUNNING && (step++ < n || n == -1)) {
		dut.inst = pmem_read(dut.pc);
		Log("dut.pc = %x, dut.inst = %x\n", dut.pc, dut.inst);
		exec_once();
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
		// encounter unexpected situation
		Log("The program has ended, please restart the npc!\n");
		void itrace_write_into_log(int num);
		itrace_write_into_log(10);
	}
}
*/


