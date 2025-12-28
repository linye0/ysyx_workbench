ENTRY(_start)

PHDRS { text PT_LOAD; data PT_LOAD; }

MEMORY {
  flash : ORIGIN = 0x30000000, LENGTH = 1600M
  psram : ORIGIN = 0x80000000, LENGTH = 4M
  sram  : ORIGIN = 0x0f000000, LENGTH = 8K
  sdram : ORIGIN = 0xa0000000, LENGTH = 400M
}

SECTIONS {
  /* 代码段和只读数据依然放在 Flash 中 */
  . = ORIGIN(flash);

  .text :
  {
    *(entry)
    *(.text*)
    _etext = .;
  } > flash AT> flash : text
  etext = .;

  .rodata :
  {
    _rodata = .;
    *(.rodata*)
    *(.srodata*)
    _erodata = .;
  } > flash AT> flash

  /* --- 关键修改：数据段搬迁到 PSRAM --- */
  /* VMA 指向 psram，LMA (加载地址) 依然在 flash 中，启动时需要搬运 */
  .data :
  {
    _data = .;
    *(.data*)
    *(.sdata*)
    _edata = .;
  } > psram AT> flash : data

  /* BSS 段直接分配在 PSRAM */
  .bss (NOLOAD) :
  {
    _bstart = .;
    *(.bss*)
    *(.sbss*)
    *(.scommon)
    _bend = .;
  } > psram

  /* --- 堆栈调整 --- */
  /* 考虑到 microbench 的需求，我们将栈和堆都移入 4MB 的 PSRAM */
  
  . = ALIGN(0x10);
  _stack_top = .;
  . = . + 0x8000;      /* 将栈大小增加到 32KB，防止递归/大数据结构溢出 */
  _stack_pointer = .;
  
  _heap_start = ALIGN(0x10);
  /* 堆区可以使用 PSRAM 剩余的所有空间 */
  _heap_end = ORIGIN(psram) + LENGTH(psram);

  end = .;
  _end = .;
}