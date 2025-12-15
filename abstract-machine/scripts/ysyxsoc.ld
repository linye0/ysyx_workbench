ENTRY(_start)

PHDRS { text PT_LOAD; data PT_LOAD; }

SECTIONS {
  /* _pmem_start and _entry_offset are defined in LDFLAGS */
  . = _pmem_start + _entry_offset; /*0x20000000*/
  .text : {
    *(entry)
    *(.text*)
  } : text
  etext = .;
  _etext = .;
  .rodata : {
    *(.rodata*)
  }
  .data : {
    *(.data)
  } : data
  edata = .;
  _data = .;
  .bss : {
	_bss_start = .;
    *(.bss*)
    *(.sbss*)
    *(.scommon)
  }
  /* SRAM 布局：堆区在开始，栈区在末尾 */
  /* 堆空间是[0x0f000000-0x0f001000], 栈空间是[0xf001000, 0xf001fff] */
  . = _sram_start; /*0x0f000000*/
  _heap_start = ALIGN(0x400);
  
  /* 栈区在 SRAM 末尾，栈区大小 4KB */
  /* _sram_size 在 LDFLAGS 中定义 */
  _stack_top = _sram_start + _sram_size; /* 栈顶 = SRAM结束 */
  _stack_bottom = _stack_top - 0x1000;
  _stack_pointer = _stack_top; /* 栈向下增长，初始指向栈顶 */
  
  end = .;
  _end = .;
}