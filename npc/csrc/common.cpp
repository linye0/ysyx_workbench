#include <stdlib.h>
#include <stdint.h>
#include <string.h>

static const uint32_t img[] = {
	0b00000000010100000000000010010011,
	0b00000000000100000000000100010011
};

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
