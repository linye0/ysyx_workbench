#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>

extern uint32_t endflag;

static const uint32_t img[] = {
	0b00000000010100000000000010010011,
	0b00000000000100000000000100010011,
	0b00000000001000000000000100010011,
	0b00000000010100001000000100010011,
	0b00000000000100000000000001110011
};

extern "C" void npc_trap() {
	printf("hit ebreak!\n");
	endflag = 1;
	return;
}

extern "C" uint32_t get_flag() {
	return endflag;
}

uint32_t *init_mem(size_t size) {
	uint32_t *memory = (uint32_t*)malloc(size * sizeof(uint32_t));
	memcpy(memory, img, sizeof(img));
	if (memory == NULL) {exit(0);}
	return memory;
}

uint32_t guest_to_host(uint32_t addr) {return addr - 0x80000000;}
uint32_t pmem_read(uint32_t* memory, uint32_t vaddr) {
	uint32_t paddr = guest_to_host(vaddr);
	return memory[paddr/4];
}
