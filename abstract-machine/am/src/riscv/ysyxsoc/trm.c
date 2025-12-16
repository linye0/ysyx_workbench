#include "include/npc.h"
#include <am.h>
#include <klib-macros.h>
#include <klib.h>
#include <riscv/ysyxsoc/include/npc.h>

extern char _heap_start;
extern char _heap_end;
extern char _data;
extern char _edata;
extern char _etext;
extern char _rodata;
extern char _erodata;
int main(const char *args);

extern char _pmem_start;
#define PMEM_SIZE (128 * 1024 * 1024)
#define PMEM_END  ((uintptr_t)&_pmem_start + PMEM_SIZE)
# define npc_trap(code) asm volatile("mv a0, %0; ebreak" : :"r"(code))

Area heap = RANGE(&_heap_start, &_heap_end);
static const char mainargs[MAINARGS_MAX_LEN] = MAINARGS_PLACEHOLDER; // defined in CFLAGS

void putch(char ch) {
  *(volatile char *)(UART_BASE + UART_TX) = ch;
}

void halt(int code) {
  npc_trap(code);

  while (1);
}

void _trm_init() {
  // Bootloader: 将数据段从MROM复制到SRAM
  size_t data_size = (uintptr_t)&_edata - (uintptr_t)&_data;
  if (data_size > 0) {
    // 数据段在MROM中的地址 = MROM起始 + .text大小 + .rodata大小
    uintptr_t data_lma = 0x20000000 + ((uintptr_t)&_etext - 0x20000000) + ((uintptr_t)&_erodata - (uintptr_t)&_rodata);
    memcpy((void *)&_data, (void *)data_lma, data_size);
  }

  int ret = main(mainargs);
  halt(ret);
}
