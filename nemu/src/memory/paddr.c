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
static uint8_t flash[CONFIG_FLASH_SIZE] PG_ALIGN = {};
static uint8_t sram[CONFIG_SRAM_SIZE] PG_ALIGN = {};
static uint8_t psram[CONFIG_PSRAM_SIZE] PG_ALIGN = {};
static uint8_t sdram[CONFIG_SDRAM_SIZE] PG_ALIGN = {};

Mem_flag mem_flag = {.flag = 0, .addr = 0, .len = 0};

uint8_t* guest_to_host(paddr_t paddr) {
  if (in_pmem(paddr)) {
    return pmem + paddr - CONFIG_MBASE;
  }
  // difftest_skip_ref();
  if (in_mrom(paddr)) {
    return mrom + paddr - CONFIG_MROM_BASE;
  }
  if (in_flash(paddr)) {
    return flash + paddr - CONFIG_FLASH_BASE;
  }
  if (in_sram(paddr)) {
    #ifndef CONFIG_NPC
    return sram + paddr - CONFIG_SRAM_BASE;
    #endif
    #ifdef CONFIG_NPC
    return nemu_state.sram + paddr - CONFIG_SRAM_BASE;
    #endif
  }
  if (in_psram(paddr)) {
    return psram + paddr - CONFIG_PSRAM_BASE;
  }
  if (in_sdram(paddr)) {
    return sdram + paddr - CONFIG_SDRAM_BASE;
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
  panic("Memory check bound: address = " FMT_PADDR " is out of bound at pc = " FMT_WORD,
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
  #ifdef CONFIG_NPC
  #ifdef CONFIG_SYS_SOC
  if (likely(in_pmem(addr) || in_mrom(addr) || in_sram(addr) || in_flash(addr) || in_psram(addr) || in_sdram(addr))) return pmem_read(addr, len);
  #endif
  #ifdef CONFIG_SYS_NPC
  if (likely(in_pmem(addr))) return pmem_read(addr, len);
  #endif
  #else
  #ifdef CONFIG_TARGET_SHARE
  if (likely(in_pmem(addr) || in_mrom(addr) || in_sram(addr) || in_flash(addr) || in_psram(addr) || in_sdram(addr))) return pmem_read(addr, len);
  #else
  #ifdef YSYXSOC_ON_NEMU
  if (likely(in_pmem(addr) || in_mrom(addr) || in_flash(addr) || in_sram(addr) || in_psram(addr) || in_sdram(addr))) return pmem_read(addr, len);
  #else
  if (likely(in_pmem(addr))) return pmem_read(addr, len);
  #endif
  #endif
  #endif
  IFDEF(CONFIG_DEVICE, return mmio_read(addr, len));
  //IFDEF(CONFIG_YSYXSOC, return mmio_read(addr, len));
  out_of_bound(addr);
  return 0;
}

void paddr_write(paddr_t addr, int len, word_t data) {
  //printf("paddr_write: addr = 0x%x, len = %d, data = 0x%x, in_sdram: %d\n", addr, len, data, in_sdram(addr));
  #ifdef CONFIG_NPC
  #ifdef CONFIG_SYS_SOC
  if (likely(in_pmem(addr) || in_sram(addr) || in_psram(addr) || in_sdram(addr))) { pmem_write(addr, len, data); return; }
  #endif
  #ifdef CONFIG_SYS_NPC
  if (likely(in_pmem(addr))) return pmem_write(addr, len, data);
  #endif
  #else
  #ifdef CONFIG_TARGET_SHARE
  if (likely(in_pmem(addr) || in_sram(addr) || in_psram(addr) || in_sdram(addr))) { pmem_write(addr, len, data); return; }
  #else
  #ifdef YSYXSOC_ON_NEMU
  if (likely(in_pmem(addr) || in_sram(addr) || in_psram(addr) || in_sdram(addr))) { pmem_write(addr, len, data); return; }
  #else
  if (likely(in_pmem(addr))) { pmem_write(addr, len, data); return; }
  #endif
  #endif
  #endif
  IFDEF(CONFIG_DEVICE, mmio_write(addr, len, data); return);
  //IFDEF(CONFIG_YSYXSOC, mmio_write(addr, len, data); return);
  out_of_bound(addr);
}

#ifdef CONFIG_NPC
extern "C" void sdram_write(int32_t id, int32_t wAddr, char wMask, int16_t wData) {
  //printf("sdram_write: wAddr = 0x%x, wMask = %d, wData = 0x%x\n", wAddr, wMask, wData);
  void *const host_addr = guest_to_host(CONFIG_SDRAM_BASE + wAddr + (id * 2));
  uint16_t originData = (*(uint16_t *)host_addr);
  switch (wMask) {
    case 0b01: 
      (*(uint16_t *)host_addr) = (originData & 0xFF00) | (wData & 0x00FF);
      break;
    case 0b10:
      (*(uint16_t *)host_addr) = (originData & 0x00FF) | (wData & 0xFF00);
      break;
    case 0b11:
      (*(uint16_t *)host_addr) = wData;
    case 0b00:
      break;
    default:
      break;
  }
  return;
}

extern "C" int16_t sdram_read(int32_t id, int32_t rAddr, char rMask) {
  const uint16_t data = paddr_read(CONFIG_SDRAM_BASE +rAddr + (id*2), 2);
  //printf("sdram_read: rAddr = 0x%x, rMask = %d, data = 0x%x\n", rAddr, rMask, data);
  return data;
}

extern "C" void psram_read(int addr, int *data) {
  uint32_t offset = addr;
  *data = paddr_read(CONFIG_PSRAM_BASE + offset, 4);
	return;
}

extern "C" void psram_write(int addr, int wdata, char wstrb) {
  // wstrb表示要写入的半字节数量: 2 -> 1字节, 4 -> 2字节, 8 -> 4字节
  // 有效数据永远在高wstrb个半字节内
  uint32_t actual_data;
  
  switch (wstrb) {
    case 2:  // 写入1字节，有效数据在wdata[31:24]
      actual_data = (wdata >> 24) & 0xFF;
      *(uint8_t *)guest_to_host(CONFIG_PSRAM_BASE + addr) = (uint8_t)actual_data;
      break;
    case 4:  // 写入2字节，有效数据在wdata[31:16]
      actual_data = (wdata >> 16) & 0xFFFF;
      *(uint16_t *)guest_to_host(CONFIG_PSRAM_BASE + addr) = (uint16_t)actual_data;
      break;
    case 8:  // 写入4字节，有效数据在wdata[31:0]
      actual_data = wdata;
      *(uint32_t *)guest_to_host(CONFIG_PSRAM_BASE + addr) = (uint32_t)actual_data;
      break;
    default:
      break;
  }
  return;
}

extern "C" void flash_read(int32_t addr, int32_t *data) { 
  uint32_t offset = addr;
  *data = *((uint32_t *)(flash + offset));
  // printf("flash raddr: 0x%x, rdata: 0x%x, offest: 0x%x\n", addr, *data, offset);
}

extern "C" void mrom_read(int32_t addr, int32_t *data) {
    uint32_t offset = ((addr & 0xfffffffc) - CONFIG_MROM_BASE);
    *data = *((uint32_t *)(mrom + offset));
    //printf("mrom raddr: 0x%x, rdata: 0x%x, offest: 0x%x\n", addr, *data, offset);
    // Log("mrom raddr: 0x%x, rdata: 0x%x, offest: 0x%x", addr, *data, offset);
}
#endif