#include <stdint.h>
#include <common.h>

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

static inline word_t host_read(void *addr, int len = 4)
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

static inline void host_write(void *addr, word_t data, int len) {
    switch(len) {
        case 1:
            *(uint8_t *)addr = data;
            break;
        case 2:
            *(uint16_t *)addr = data;
            break;
        case 4:
            *(uint32_t *)addr = data;
            break;
        case 8:
            *(uint64_t *)addr = data;
            break;
        default:
            assert(0);
    }
}

uint32_t local_pmem_read(uint32_t vaddr) {
	return host_read(guest_to_host(vaddr),  4);
}

extern "C" int pmem_read(word_t raddr, char wmask) {
    //printf("pmem_read: addr = " FMT_WORD ", mask = %02x\n", raddr, wmask);
    uint8_t *host_addr = guest_to_host(raddr);
    host_addr = (uint8_t*)((size_t)host_addr & ~0x3);
    if (host_addr == NULL) {
        // Log(FMT_RED("Invalid read: addr = " FMT_WORD ", mask = %02x\n"), raddr, wmask);
        // printf(FMT_RED("Invalid read: addr = " FMT_WORD ", mask = %02x\n"), raddr, wmask);
        // npc_abort();
        return 0;
    }
    switch(wmask) {
        case 0xf:
            //printf("case 0xff\n");
            //printf("return value = %02x\n", host_read(host_addr, 4));
            printf("case 0xff\n");
            return host_read(host_addr, 4);
            break;
        case 0xc:
            printf("case 0xc\n");
            return host_read(host_addr + 2, 2);
            break;
        case 0x3:
            printf("case 0x3\n");
            printf("return value = %02x\n", host_read(host_addr, 2));
            return host_read(host_addr, 2);
            break;
        case 0x1:
            printf("case 0x1\n");
            return host_read(host_addr + 2, 1);
            break;
        default:
            Assert(0, "Invalid mask = %02x", wmask);
            break;
    }
    return 0;
}

extern "C" void pmem_write(word_t waddr, word_t wdata, char wmask) {
    // 总是往地址为`waddr & ~0x3u`的4字节按写掩码`wmask`写入`wdata`
    // `wmask`中每比特表示`wdata`中1个字节的掩码,
    // 如`wmask = 0x3`代表只写入最低2个字节, 内存中的其它字节保持不变
    // printf("pmem_write: addr = " FMT_WORD ", data = " FMT_WORD ", mask = %02x\n", waddr, wdata, wmask & 0xff);
    uint8_t *host_addr = guest_to_host(waddr);
    if (host_addr == NULL) {
        //Log(FMT_RED("Invalid write: addr = " FMT_WORD ", data = " FMT_WORD ", mask = %02x"),
        // waddr, wdata, wmask & 0xff);
        // npc_abort();
        return;
    }
    switch (wmask) {
        case 0x1:
            host_write(host_addr, wdata, 1);
            break;
        case 0x3:
            host_write(host_addr, wdata, 2);
            break;
        case 0xf:
            host_write(host_addr, wdata, 4);
            break;
        case 0xc:
            host_write(host_addr + 2, wdata, 2);
            break;
        /*
        case 0xff:
            host_write(host_addr, 8, wdata);
            break;
        */
        default:
            // Log(FMT_RED("Invalid write: addr = " FMT_WORD ", data = " FMT_WORD ", mask = %02x"),
                // waddr, wdata, wmask & 0xff);
            break;
    }
}
