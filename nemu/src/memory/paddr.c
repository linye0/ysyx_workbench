/***************************************************************************************
* Copyright (c) 2014-2024 Zihao Yu, Nanjing University
*
* NEMU is licensed under Mulan PSL v2.
* You can use this software according to the terms and conditions of the Mulan PSL v2.
* You may obtain a copy of Mulan PSL v2 at:
*          http://license.coscl.org.cn/MulanPSL2
*
* THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
* EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
* MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
*
* See the Mulan PSL v2 for more details.
***************************************************************************************/

#include "macro.h"
#include <memory/host.h>
#include <memory/paddr.h>
#include <device/mmio.h>
#include <isa.h>
#include <debug.h>
#include <utils.h>

#if   defined(CONFIG_PMEM_MALLOC)
static uint8_t *pmem = NULL;
#else // CONFIG_PMEM_GARRAY
static uint8_t pmem[CONFIG_MSIZE] PG_ALIGN = {};
#endif

static uint8_t mrom[CONFIG_MROM_SIZE] PG_ALIGN = {};
static uint8_t sram[CONFIG_SRAM_SIZE] PG_ALIGN = {};

Mem_flag mem_flag = {.flag = 0, .addr = 0, .len = 0};

uint8_t* guest_to_host(paddr_t paddr) {
  if (in_pmem(paddr)) {
    return pmem + paddr - CONFIG_MBASE;
  }
  // difftest_skip_ref();
  if (in_mrom(paddr)) {
    return mrom + paddr - CONFIG_MROM_BASE;
  }
  if (in_sram(paddr)) {
    #ifndef CONFIG_NPC
    return sram + paddr - CONFIG_SRAM_BASE;
    #endif
    #ifdef CONFIG_NPC
    return nemu_state.sram + paddr - CONFIG_SRAM_BASE;
    #endif
  }
  Assert(0, "ERROR in guest_to_host: paddr out of bound! pmem: 0x%x, paddr: 0x%x\n", pmem, paddr);
}
paddr_t host_to_guest(uint8_t *haddr) { return haddr - pmem + CONFIG_MBASE; }

static word_t pmem_read(paddr_t addr, int len) {
  #ifdef CONFIG_MTRACE
	void log_pread(paddr_t, int);
	log_pread(addr, len);
  #endif
  #ifdef CONFIG_TARGET_SHARE
  mem_flag.flag = 1;
  mem_flag.addr = addr;
  mem_flag.len = len;
  #endif
  word_t ret = host_read(guest_to_host(addr), len);
  return ret;
}

static void pmem_write(paddr_t addr, int len, word_t data) {
  #ifdef CONFIG_MTRACE
	void log_pwrite(paddr_t, int, word_t);
	log_pwrite(addr, len, data);
  #endif
  #ifdef CONFIG_TARGET_SHARE
  mem_flag.flag = 1;
  mem_flag.addr = addr;
  mem_flag.len = len;
  #endif
  host_write(guest_to_host(addr), len, data);
}

static void out_of_bound(paddr_t addr) {
  panic("address = " FMT_PADDR " is out of bound at pc = " FMT_WORD,
      addr, cpu.pc);
}

void init_mem() {
#if   defined(CONFIG_PMEM_MALLOC)
  pmem = malloc(CONFIG_MSIZE);
  assert(pmem);
#endif
  IFDEF(CONFIG_MEM_RANDOM, memset(pmem, rand(), CONFIG_MSIZE));
  Log("physical memory area [" FMT_PADDR ", " FMT_PADDR "]", PMEM_LEFT, PMEM_RIGHT);
}

word_t paddr_read(paddr_t addr, int len) {
  if (likely(in_pmem(addr) || in_mrom(addr) || in_sram(addr))) return pmem_read(addr, len);
  IFDEF(CONFIG_DEVICE, return mmio_read(addr, len));
  out_of_bound(addr);
  return 0;
}

void paddr_write(paddr_t addr, int len, word_t data) {
  if (likely(in_pmem(addr) || in_sram(addr))) { pmem_write(addr, len, data); return; }
  IFDEF(CONFIG_DEVICE, mmio_write(addr, len, data); return);
  out_of_bound(addr);
}

#ifdef CONFIG_NPC
extern "C" void flash_read(int32_t addr, int32_t *data) { assert(0); }

extern "C" void mrom_read(int32_t addr, int32_t *data) {
    uint32_t offset = ((addr & 0xfffffffc) - CONFIG_MROM_BASE);
    *data = *((uint32_t *)(mrom + offset));
    //printf("mrom raddr: 0x%x, rdata: 0x%x, offest: 0x%x\n", addr, *data, offset);
    // Log("mrom raddr: 0x%x, rdata: 0x%x, offest: 0x%x", addr, *data, offset);
}
#endif