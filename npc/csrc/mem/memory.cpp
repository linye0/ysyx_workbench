#include <stdint.h>
#include <common.h>
#include <utils.h>

void difftest_skip_ref();
void npc_abort();

static uint8_t pmem[MSIZE] = {};

uint8_t *guest_to_host(paddr_t addr)
{
    if (addr >= MBASE && addr <= MBASE + MSIZE)
    {
        return pmem + addr - MBASE;
    }
    // Assert(0, "Invalid guest address: " FMT_WORD, addr);
    return NULL;
}

paddr_t host_to_guest(uint8_t *addr)
{
    return addr + MBASE - pmem;
}

static inline word_t host_read(void *addr, int len)
{
    switch (len)
    {
    case 1:
        return *(uint8_t *)addr;
    case 2:
        return *(uint16_t *)addr;
    case 4:
        return *(uint32_t *)addr;
    case 8:
        return *(uint64_t *)addr;
    default:
        assert(0);
    }
}

uint32_t pmem_read(uint32_t vaddr) {
	return host_read(guest_to_host(vaddr),  4);
}