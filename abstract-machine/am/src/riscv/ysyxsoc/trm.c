#include "include/npc.h"
#include <am.h>
#include <klib-macros.h>
#include <riscv/ysyxsoc/include/npc.h>

extern char _heap_start;
extern char _stack_top;
extern char _stack_bottom;
int main(const char *args);

extern char _pmem_start;
#define PMEM_SIZE (128 * 1024 * 1024)
#define PMEM_END  ((uintptr_t)&_pmem_start + PMEM_SIZE)
# define npc_trap(code) asm volatile("mv a0, %0; ebreak" : :"r"(code))  

Area heap = RANGE(&_heap_start, &_stack_bottom);
static const char mainargs[MAINARGS_MAX_LEN] = MAINARGS_PLACEHOLDER; // defined in CFLAGS

void putch(char ch) {
  *(volatile char *)(UART_BASE + UART_TX) = ch;
}

void halt(int code) {
  npc_trap(code);

  while (1);
}

void _trm_init() {
  int ret = main(mainargs);
  halt(ret);
}
