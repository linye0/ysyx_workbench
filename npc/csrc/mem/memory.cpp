#include <cstdint>
#include <stdint.h>
#include <common.h>
#include <memory/host.h>

void difftest_skip_ref();
void npc_abort();

/*
static uint8_t pmem[MSIZE] = {};
static uint8_t sdram[SDRAM_SIZE] = {};
static uint8_t sram[SRAM_SIZE] = {};
static uint8_t mrom[MROM_SIZE] = {};
static uint8_t flash[FLASH_SIZE] = {};
#ifdef CONFIG_SOFT_MMIO
static uint32_t rtc_port_base[2] = {0x0, 0x0};
#endif
*/

uint8_t *guest_to_host(paddr_t addr)
{
    if (addr >= MBASE && addr <= MBASE + MSIZE)
    {
        return pmem + addr - MBASE;
    }
    if (addr >= MROM_BASE && addr < MROM_BASE + MROM_SIZE) 
    {
        return mrom + addr - MROM_BASE;
    }
    if (addr >= SRAM_BASE && addr < SRAM_BASE + SRAM_SIZE) {
        return sram + addr - SRAM_BASE;
    }
    if (addr >= FLASH_BASE && addr < FLASH_BASE + FLASH_SIZE) {
        return flash + addr - FLASH_BASE;
    }
    if (addr >= SDRAM_BASE && addr < SDRAM_BASE + SDRAM_SIZE) {
        return sdram + addr - SDRAM_BASE;
    }
    // Assert(0, "Invalid guest address: " FMT_WORD, addr);
    return NULL;
}

paddr_t host_to_guest(uint8_t *addr)
{
    return addr + MBASE - pmem;
}

extern "C" int pmem_read(word_t raddr, char wmask) {
    #ifdef CONFIG_SOFT_MMIO
        if (raddr == RTC_ADDR + 4) {
            uint64_t t = get_time();
            rtc_port_base[0] = (uint32_t)(t >> 32);
            difftest_skip_ref();
            return rtc_port_base[0];
        } else if (raddr == RTC_ADDR) {
            uint64_t t = get_time();
            rtc_port_base[1] = (uint32_t)(t);
            difftest_skip_ref();
            return rtc_port_base[1];
        }
    #endif
    // printf("pmem_read: addr = " FMT_WORD ", mask = %02x\n", raddr, wmask);
    uint8_t *host_addr = guest_to_host(raddr);
    host_addr = (uint8_t*)((size_t)host_addr);
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
            return host_read(host_addr, 4);
            break;
        case 0xc:
            if (host_read(host_addr, 2) & (1 << 15)) {
                return host_read(host_addr, 2) | 0xFFFF0000;
            } else {
                return host_read(host_addr, 2) & 0x0000FFFF;
            }
            break;
        case 0x3:
            return host_read(host_addr, 2);
            break;
        case 0x1:
            return host_read(host_addr, 1);
            break;
        default:
            Assert(0, "Invalid mask = %02x", wmask);
            break;
    }
    return 0;
}

extern "C" void pmem_write(word_t waddr, word_t wdata, char wmask) {
    #ifdef CONFIG_SOFT_MMIO
        if (waddr == SERIAL_PORT) {
            putchar(wdata);
            difftest_skip_ref();
            return;
        }
    #endif
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
            host_write(host_addr, wdata, 2);
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

// DPI-C function aliases for SystemVerilog
extern "C" int npc_read(word_t raddr, char wmask) {
    return pmem_read(raddr, wmask);
}

extern "C" void npc_write(word_t waddr, word_t wdata, char wmask) {
    pmem_write(waddr, wdata, wmask);
}
