#include "include/npc.h"
#include <am.h>
#include <klib-macros.h>
#include <klib.h>
#include <riscv/ysyxsoc/include/npc.h>

extern char _heap_start;
extern char _heap_end;
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

// 定义一个宏，强制获取符号的绝对链接地址 (VMA/LMA)
#define GET_ABS_ADDR(sym) ({ \
  uintptr_t _addr; \
  asm volatile("lui %0, %%hi(" #sym "); addi %0, %0, %%lo(" #sym ")" : "=r"(_addr)); \
  _addr; \
})

static void copy_segment(uintptr_t vma_start, uintptr_t vma_end, uintptr_t lma_start) {
    uint32_t *dst = (uint32_t *)vma_start;
    uint32_t *src = (uint32_t *)lma_start;
    uint32_t count = (vma_end - vma_start + 3) / 4;
    
    // 只有在区间有效时才搬运
    if (vma_start < vma_end) {
        for (uint32_t i = 0; i < count; i++) {
            dst[i] = src[i];
        }
    }
}

void load_sections() {
    // 1. 分段搬运：使用绝对地址加载，避开 PC 相对寻址陷阱
    // 搬运 .text
    copy_segment(
        GET_ABS_ADDR(_text_vma_start), 
        GET_ABS_ADDR(_text_vma_end), 
        GET_ABS_ADDR(_text_lma_start)
    );
    // 搬运 .rodata
    copy_segment(
        GET_ABS_ADDR(_rodata_vma_start), 
        GET_ABS_ADDR(_rodata_vma_end), 
        GET_ABS_ADDR(_rodata_lma_start)
    );
    // 搬运 .data
    copy_segment(
        GET_ABS_ADDR(_data_vma_start), 
        GET_ABS_ADDR(_data_vma_end), 
        GET_ABS_ADDR(_data_lma_start)
    );

    // 2. 清零 BSS：同样使用绝对地址
    uint32_t *bss_ptr = (uint32_t *)GET_ABS_ADDR(_bss_vma_start);
    uint32_t *bss_end = (uint32_t *)GET_ABS_ADDR(_bss_vma_end);
    
    while (bss_ptr < bss_end) {
        *bss_ptr++ = 0;
    }
}

void _trm_init() {
    // 依然先初始化串口，方便调试
    init_uart();

    // 1. 将程序从 Flash 搬运到 PSRAM
    load_sections();

    // 2. 显示 SoC 信息
    brandShow();

    // 3. 强制获取 main 的绝对地址 (此时 main 的符号地址已经在 0x8000xxxx)
    int (*psram_main)(const char *);
    asm volatile(
        "lui %0, %%hi(main)\n\t"
        "addi %0, %0, %%lo(main)"
        : "=r"(psram_main)
    );

    // 4. 跳转到 PSRAM 执行 main
    int ret = psram_main(mainargs);

    halt(ret);
}