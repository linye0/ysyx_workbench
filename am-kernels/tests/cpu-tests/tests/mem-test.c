#include <am.h>
#include <klib-macros.h>

// check 宏：如果条件为假，则调用 halt(1)
#define check(cond) \
  do { \
    if (!(cond)) { \
      halt(1); \
    } \
  } while (0)

// 内存屏障，防止编译器优化
#define memory_barrier() asm volatile("" ::: "memory")

// 测试 8 位访问：data = addr & 0xff
static void test_8bit(volatile uint8_t *start, volatile uint8_t *end) {
  volatile uint8_t *ptr;
  uintptr_t addr;
  
  // 写入阶段
  for (ptr = start, addr = (uintptr_t)start; ptr < end; ptr++, addr++) {
    *ptr = (uint8_t)(addr & 0xff);
    memory_barrier();
  }
  
  memory_barrier();
  
  // 读取并检查阶段
  for (ptr = start, addr = (uintptr_t)start; ptr < end; ptr++, addr++) {
    uint8_t expected = (uint8_t)(addr & 0xff);
    uint8_t actual = *ptr;
    check(actual == expected);
  }
  
  memory_barrier();
}


// 测试 16 位访问：data = addr & 0xffff
static void test_16bit(volatile uint16_t *start, volatile uint16_t *end) {
  volatile uint16_t *ptr;
  uintptr_t addr;
  
  // 写入阶段
  for (ptr = start, addr = (uintptr_t)start; ptr < end; ptr++, addr += 2) {
    *ptr = (uint16_t)(addr & 0xffff);
    memory_barrier();
  }
  
  memory_barrier();
  
  // 读取并检查阶段
  for (ptr = start, addr = (uintptr_t)start; ptr < end; ptr++, addr += 2) {
    uint16_t expected = (uint16_t)(addr & 0xffff);
    uint16_t actual = *ptr;
    check(actual == expected);
  }
  
  memory_barrier();
}

// 测试 32 位访问：data = addr & 0xffffffff
static void test_32bit(volatile uint32_t *start, volatile uint32_t *end) {
  volatile uint32_t *ptr;
  uintptr_t addr;
  
  // 写入阶段
  for (ptr = start, addr = (uintptr_t)start; ptr < end; ptr++, addr += 4) {
    *ptr = (uint32_t)(addr & 0xffffffff);
    memory_barrier();
  }
  
  memory_barrier();
  
  // 读取并检查阶段
  for (ptr = start, addr = (uintptr_t)start; ptr < end; ptr++, addr += 4) {
    uint32_t expected = (uint32_t)(addr & 0xffffffff);
    uint32_t actual = *ptr;
    check(actual == expected);
  }
  
  memory_barrier();
}

// 测试 64 位访问：data = addr & 0xffffffff（低32位），高32位为0
// 在 32 位系统上，使用两个 32 位字表示 64 位
static void test_64bit(volatile uint32_t *start, volatile uint32_t *end) {
  volatile uint32_t *ptr;
  uintptr_t addr;
  
  // 写入阶段
  for (ptr = start, addr = (uintptr_t)start; ptr + 1 < end; ptr += 2, addr += 8) {
    ptr[0] = (uint32_t)(addr & 0xffffffff);  // 低32位
    ptr[1] = 0;  // 高32位为0
    memory_barrier();
  }
  
  memory_barrier();
  
  // 读取并检查阶段
  for (ptr = start, addr = (uintptr_t)start; ptr + 1 < end; ptr += 2, addr += 8) {
    uint32_t expected_low = (uint32_t)(addr & 0xffffffff);
    uint32_t expected_high = 0;
    uint32_t actual_low = ptr[0];
    uint32_t actual_high = ptr[1];
    check(actual_low == expected_low);
    check(actual_high == expected_high);
  }
  
  memory_barrier();
}

int main(const char *args) {
  // 获取堆区范围（不使用全局变量，使用 extern 声明）
  extern Area heap;
  volatile uint8_t *heap_start_8;
  volatile uint8_t *heap_end_8;
  volatile uint16_t *heap_start_16;
  volatile uint16_t *heap_end_16;
  volatile uint32_t *heap_start_32;
  volatile uint32_t *heap_end_32;
  volatile uint32_t *heap_start_64;
  volatile uint32_t *heap_end_64;
  uintptr_t start_addr, end_addr;
  
  // 在函数内部计算地址（避免全局变量）
  start_addr = (uintptr_t)heap.start;
  end_addr = (uintptr_t)heap.end;
  
  // 检查堆区是否有效
  if (start_addr >= end_addr) {
    halt(1);
  }
  
  // 计算各种对齐的起始和结束地址
  heap_start_8 = (volatile uint8_t *)start_addr;
  heap_end_8 = (volatile uint8_t *)end_addr;
  
  heap_start_16 = (volatile uint16_t *)start_addr;
  heap_end_16 = (volatile uint16_t *)(end_addr & ~1);
  
  heap_start_32 = (volatile uint32_t *)((start_addr + 3) & ~3);
  heap_end_32 = (volatile uint32_t *)(end_addr & ~3);
  
  heap_start_64 = (volatile uint32_t *)((start_addr + 7) & ~7);
  heap_end_64 = (volatile uint32_t *)(end_addr & ~7);
  
  // 依次测试 8位、16位、32位、64位访问
  test_8bit(heap_start_8, heap_end_8);
  
  if (heap_start_16 < heap_end_16) {
    test_16bit(heap_start_16, heap_end_16);
  }
  
  if (heap_start_32 < heap_end_32) {
    test_32bit(heap_start_32, heap_end_32);
  }
  
  if (heap_start_64 + 1 < heap_end_64) {
    test_64bit(heap_start_64, heap_end_64);
  }
  
  // 所有测试通过
  return 0;
}

