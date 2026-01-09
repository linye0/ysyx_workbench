#include "include/npc.h"
#include <am.h>
#include <klib-macros.h>
#include <klib.h>
#include <riscv/ysyxsoc/include/npc.h>

/* --- 外部符号声明 (由 Linker Script 提供) --- */
// 堆栈与堆内存
extern char _heap_start;
extern char _heap_end;
// SSBL 段 (Flash -> SRAM)
extern char _ssbl_vma_start, _ssbl_vma_end, _ssbl_lma_start;
// App 段 (Flash -> PSRAM)
extern char _text_vma_start, _text_vma_end, _text_lma_start;
extern char _rodata_vma_start, _rodata_vma_end, _rodata_lma_start;
extern char _data_vma_start, _data_vma_end, _data_lma_start;
extern char _bss_vma_start, _bss_vma_end;

int main(const char *args);

#define PMEM_SIZE (128 * 1024 * 1024)
#define PMEM_END  ((uintptr_t)&_pmem_start + PMEM_SIZE)
# define npc_trap(code) asm volatile("mv a0, %0; ebreak" : :"r"(code))

Area heap = RANGE(&_heap_start, &_heap_end);
static const char mainargs[MAINARGS_MAX_LEN] = MAINARGS_PLACEHOLDER; // defined in CFLAGS

#define GET_ABS_ADDR(sym) ({ \
  uintptr_t _addr; \
  asm volatile("lui %0, %%hi(" #sym "); addi %0, %0, %%lo(" #sym ")" : "=r"(_addr)); \
  _addr; \
})

/* ============================================================================
 * 第一部分：FSBL 专用函数（留在 Flash 中）
 * ============================================================================ */

__attribute__((section(".text.fsbl")))
static void copy_segment_fsbl(uintptr_t vma_start, uintptr_t vma_end, uintptr_t lma_start) {
  // 增加防御性检查，防止长度溢出导致的死循环
  if (vma_start >= vma_end) return;
  uint32_t *dst = (uint32_t *)vma_start;
  uint32_t *src = (uint32_t *)lma_start;
  uint32_t count = (vma_end - vma_start) / 4;
  for (uint32_t i = 0; i < count; i++) {
    dst[i] = src[i];
  }
}

/* ============================================================================
 * 第二部分：SSBL 专用函数（会被搬运到 SRAM 运行）
 * ============================================================================ */

__attribute__((section(".text.ssbl")))
static void copy_segment_ssbl(uintptr_t vma_start, uintptr_t vma_end, uintptr_t lma_start) {
  if (vma_start >= vma_end) return;
  uint32_t *dst = (uint32_t *)vma_start;
  uint32_t *src = (uint32_t *)lma_start;
  uint32_t count = (vma_end - vma_start) / 4;
  for (uint32_t i = 0; i < count; i++) {
    dst[i] = src[i]; // 此时指令取指发生在 SRAM，读数据发生在 Flash
  }
}

__attribute__((section(".text.ssbl")))
void init_uart(uint16_t div) {
  outb(UART16550_LCR, 0x80); 
  outb(UART16550_DL2, (uint8_t)(div >> 8));    
  outb(UART16550_DL1, (uint8_t)div);    
  outb(UART16550_LCR, 0x03); 
}

__attribute__((section(".text.ssbl")))
void putch(char ch) {
  while ((inb(UART16550_LSR) & (0x1 << 5)) == 0x0);
  outb(UART16550_TX, ch);
}

__attribute__((section(".text.ssbl")))
void halt(int code) {
  npc_trap(code);
  while (1);
}

__attribute__((section(".text.ssbl")))
void brandShow() {
  uint32_t mvendorid, marchid;
  asm volatile("csrr %0, mvendorid" : "=r"(mvendorid));
  asm volatile("csrr %0, marchid" : "=r"(marchid));
  for (int i = 3; i >= 0; i--) { putch((char)((mvendorid >> (i * 8)) & 0xff)); }
  char buf[16]; int index = 0; uint32_t num = marchid;
  if (num == 0) buf[index++] = '0';
  while (num > 0) { buf[index++] = (num % 10) + '0'; num /= 10; }
  for (int i = index - 1; i >= 0; i--) { putch(buf[i]); }
  putch('\n');
}

/* --- 第二级引导 (SSBL): 运行在 SRAM --- */
__attribute__((section(".text.ssbl")))
void ssbl_main() {
  // 1. 搬运 Application 到 PSRAM
  // 核心：调用位于 SRAM 内部的搬运函数，不再跳回 Flash
  copy_segment_ssbl(GET_ABS_ADDR(_text_vma_start),   GET_ABS_ADDR(_text_vma_end),   GET_ABS_ADDR(_text_lma_start));
  copy_segment_ssbl(GET_ABS_ADDR(_rodata_vma_start), GET_ABS_ADDR(_rodata_vma_end), GET_ABS_ADDR(_rodata_lma_start));
  copy_segment_ssbl(GET_ABS_ADDR(_data_vma_start),   GET_ABS_ADDR(_data_vma_end),   GET_ABS_ADDR(_data_lma_start));

  // 2. BSS 清零
  uint32_t *bss_ptr = (uint32_t *)GET_ABS_ADDR(_bss_vma_start);
  uint32_t *bss_end = (uint32_t *)GET_ABS_ADDR(_bss_vma_end);
  while (bss_ptr < bss_end) { *bss_ptr++ = 0; }

  // 3. 硬件初始化与打印
  init_uart(1);
  brandShow();

  // 4. 跳转到应用
  int (*sdram_main)(const char *) = (void *)GET_ABS_ADDR(main);
  int ret = sdram_main(mainargs);
  halt(ret);
}

/* --- 第一级引导 (FSBL): 运行在 Flash --- */
__attribute__((section(".text.fsbl")))
void _trm_init() {
  // 核心：使用 Flash 内部的搬运函数将 SSBL 代码段整体搬到 SRAM
  copy_segment_fsbl(
    GET_ABS_ADDR(_ssbl_vma_start),
    GET_ABS_ADDR(_ssbl_vma_end),
    GET_ABS_ADDR(_ssbl_lma_start)
  );

  // 跳转到 SRAM 执行 ssbl_main
  void (*ssbl_entry)() = (void *)GET_ABS_ADDR(ssbl_main);
  ssbl_entry();

  while (1);
}