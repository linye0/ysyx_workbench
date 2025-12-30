ENTRY(_start)

PHDRS { text PT_LOAD; data PT_LOAD; }

MEMORY {
  flash : ORIGIN = 0x30000000, LENGTH = 1600M
  psram : ORIGIN = 0x80000000, LENGTH = 4M
  sram  : ORIGIN = 0x0f000000, LENGTH = 8K
  sdram : ORIGIN = 0xa0000000, LENGTH = 400M
}

SECTIONS {
  . = ORIGIN(psram);

  /* --- 代码段 --- */
  .text : {
    _text_vma_start = .;
    *(entry)
    *(.text*)
    . = ALIGN(4);
    _text_vma_end = .;
  } > psram AT> flash : text   /* <--- 必须指向 : text */

  _text_lma_start = LOADADDR(.text);

  /* --- 只读数据段 --- */
  .rodata : {
    _rodata_vma_start = .;
    *(.rodata*)
    *(.srodata*)
    . = ALIGN(4);
    _rodata_vma_end = .;
  } > psram AT> flash : text   /* <--- 通常只读数据也放在 : text 容器 */

  _rodata_lma_start = LOADADDR(.rodata);

  /* --- 数据段 --- */
  .data : {
    _data_vma_start = .;
    *(.data*)
    *(.sdata*)
    . = ALIGN(4);
    _data_vma_end = .;
  } > psram AT> flash : data   /* <--- 指向 : data */

  _data_lma_start = LOADADDR(.data);

  /* --- BSS段 (不需要加载地址，不属于任何加载容器) --- */
  .bss (NOLOAD) : {
    . = ALIGN(4);
    _bss_vma_start = .;
    *(.bss*)
    *(.sbss*)
    *(.scommon)
    . = ALIGN(4);
    _bss_vma_end = .;
  } > psram                    /* <--- 注意：NOLOAD段不要加 : phdr */

  /* --- 关键修改：栈分配在极速的 SRAM 中 --- */
  /* 栈顶设在 SRAM 末尾，向下增长，独占 8KB SRAM 空间 */
  _stack_pointer = ORIGIN(sram) + LENGTH(sram);

  /* --- 修改：堆分配在 PSRAM 的剩余空间 --- */
  _heap_start = ALIGN(0x10);
  _heap_end = ORIGIN(psram) + LENGTH(psram);

  end = .;
  _end = .;
}