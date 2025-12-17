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

void init_uart(void)
{
  outb(UART16550_LCR, 0x80);
  outb(UART16550_DL2, 0);
  outb(UART16550_DL1, 1);
  outb(UART16550_LCR, 0x03);
}

void putch(char ch)
{
  while ((inb(UART16550_LSR) & (0x1 << 5)) == 0x0);
  outb(UART16550_TX, ch);
}

void halt(int code) {
  npc_trap(code);

  while (1);
}


void _trm_init() {
  // bootloader: 将数据段从mrom复制到sram
  size_t data_size = (uintptr_t)&_edata - (uintptr_t)&_data;
  if (data_size > 0) {
    // 数据段在mrom中的地址 = mrom起始 + .text大小 + .rodata大小
    uintptr_t data_lma = 0x20000000 + ((uintptr_t)&_etext - 0x20000000) + ((uintptr_t)&_erodata - (uintptr_t)&_rodata);
    memcpy((void *)&_data, (void *)data_lma, data_size);
  }

  init_uart();

  // call main
  int ret = main(mainargs);
  halt(ret);
}
