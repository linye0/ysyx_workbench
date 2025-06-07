#include <common.h>
#include <isa.h>

extern NPCState npc;

const char *regs[] = {  // 实际定义（分配内存）
  "$0", "ra", "sp", "gp", "tp", "t0", "t1", "t2",
  "s0", "s1", "a0", "a1", "a2", "a3", "a4", "a5",
  "a6", "a7", "s2", "s3", "s4", "s5", "s6", "s7",
  "s8", "s9", "s10", "s11", "t3", "t4", "t5", "t6",
  "pc"
};

void print_all_regs() {
	isa_reg_display();
	return;
}

void isa_reg_display() {
	bool success = false;
	for (int i = 0; i < ARRLEN(regs); i++) {
		uint32_t val = isa_reg_str2val(regs[i], &success);
		printf("%-16s0x%-16x%d\n", regs[i], val, val);
	}
}

uint32_t isa_reg_str2val(const char *s, bool *success) {
	if (strcmp(s, "pc") == 0) {
		*success = true;
		return *npc.cpc;
	}
   for (int i = 0; i < sizeof(regs) / sizeof(const char*); i++) {
        if (strcmp(s, regs[i]) == 0) {
            *success = true;
            /* 变量cpu定义于$NEMU_HOME/src/cpu/cpu-exec.c: CPU_state cpu = {};
               声明见文件$NEMU_HOME/include/isa.h: extern CPU_state cpu; */
            return npc.gpr[i];  // 数组regs的声明顺序与riscv32的定义一致
        }
    }

    *success = false;
    return 0;
}

uint32_t paddr_read(int addr) {
  uint32_t local_pmem_read(uint32_t vaddr);
	return local_pmem_read(addr);
}
