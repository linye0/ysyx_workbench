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
extern char _bstart;
extern char _bend;
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

void brandShow() {
  int i;
  int index;
  char buf[10];
  uint32_t number;
  uint32_t mvendorid;
  uint32_t marchid;
  asm volatile("csrr %0, mvendorid" : "=r"(mvendorid));
  asm volatile("csrr %0, marchid" : "=r"(marchid));
  for (i = 3; i >= 0; i--) {
    putch((char)(((mvendorid >> (i * 8)) & 0xff)));
  }
  number = marchid;
  index = 0;
  while (number > 0) {
    buf[index++] = (number % 10) + '0';
    number /= 10;
  }
  for(i = index - 1;i >= 0;i--){
    putch(buf[i]);
  }
  putch('\n');
}

/**
 * 搬运数据段并清零 BSS 段
 * 目的：将存储在 Flash (LMA) 中的数据加载到 PSRAM (VMA) 中运行
 */
void load_sections() {
    // 1. 搬运数据段 (.data)
    // 根据之前的链接脚本，.data 的 LMA 紧跟在 .rodata 之后
    // 所以 LMA = _erodata
    uintptr_t data_vma_start = (uintptr_t)&_data;
    uintptr_t data_vma_end   = (uintptr_t)&_edata;
    uintptr_t data_lma_start = (uintptr_t)&_erodata;
    
    size_t data_size = data_vma_end - data_vma_start;

    if (data_size > 0) {
        memcpy((void *)data_vma_start, (void *)data_lma_start, data_size);
    }

    // 2. 清零 BSS 段 (.bss)
    // BSS 段不占用 Flash 空间，只需在运行前将其所在的内存空间清零
    uintptr_t bss_start = (uintptr_t)&_bstart;
    uintptr_t bss_end   = (uintptr_t)&_bend;
    
    size_t bss_size = bss_end - bss_start;
    
    if (bss_size > 0) {
        memset((void *)bss_start, 0, bss_size);
    }
}

void _trm_init() {
  // bootloader: 将数据段从mrom复制到sram
  /*
  size_t data_size = (uintptr_t)&_edata - (uintptr_t)&_data;
  if (data_size > 0) {
    // 数据段在mrom中的地址 = mrom起始 + .text大小 + .rodata大小
    uintptr_t data_lma = 0x20000000 + ((uintptr_t)&_etext - 0x20000000) + ((uintptr_t)&_erodata - (uintptr_t)&_rodata);
    memcpy((void *)&_data, (void *)data_lma, data_size);
  }
  */

  // 执行内存搬运和清零
  load_sections();

  init_uart();

  brandShow();

  // call main
  int ret = main(mainargs);
  halt(ret);
}
