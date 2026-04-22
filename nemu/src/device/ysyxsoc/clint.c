#include <device/map.h>
#include <utils.h>

// 根据你的 AM 定义：RTC_ADDR 0x02000048
// 标准 RISC-V CLINT 中，mtime 映射在 0xbff8，但 ysyxSoC 习惯将其简化映射
#define MTIME_OFFSET    0x0048  // 对应 0x02000048

static uint32_t *clint_port_base = NULL;

static void clint_io_handler(uint32_t offset, int len, bool is_write) {
  // 我们只关心读操作，因为 AM 需要获取当前时间
  if (!is_write) {
    // 无论是读 0x48 还是 0x4c (mtime 的低 32 位或高 32 位)
    // 都在这里统一更新宿主机时间
    if (offset == MTIME_OFFSET || offset == MTIME_OFFSET + 4) {
      uint64_t us = get_time(); // 获取宿主机自启动以来的微秒数
      clint_port_base[MTIME_OFFSET / 4]     = (uint32_t)us;          // 低32位
      clint_port_base[MTIME_OFFSET / 4 + 1] = (uint32_t)(us >> 32);  // 高32位
    }
  }
  // 写操作对于简单的计时功能通常可以忽略，除非你要实现 mtimecmp 触发中断
}

void init_clint() {
  // CLINT 模块通常占用一个 64KB 的页面
  clint_port_base = (uint32_t *)new_space(0x10000);

#ifdef CONFIG_HAS_PORT_IO
  // CLINT 一般只作为 MMIO 存在
  panic("CLINT only supports MMIO");
#else
  // 注册地址从 0x02000000 开始，长度 64KB 的空间
  add_mmio_map("clint", CONFIG_CLINT_MMIO, clint_port_base, 0x10000, clint_io_handler);
#endif

  Log("(ysyxSoc) CLINT initialized at MMIO 0x%08x", CONFIG_CLINT_MMIO);
}