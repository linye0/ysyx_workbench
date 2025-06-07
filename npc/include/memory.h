#ifndef __NPC_MEMORY_H__
#define __NPC_MEMORY_H__
#include <common.h>

uint8_t *guest_to_host(paddr_t addr);

paddr_t host_to_guest(uint8_t *addr);

inline word_t host_read(void *addr, int len);

uint32_t local_pmem_read(uint32_t vaddr);

void vaddr_show(vaddr_t addr, int n);

void init_mem();

#endif /* __NPC_MEMORY_H__ */