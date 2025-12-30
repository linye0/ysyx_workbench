ENTRY(_start)

MEMORY {
  flash : ORIGIN = 0x30000000, LENGTH = 1600M
  psram : ORIGIN = 0x80000000, LENGTH = 4M
  sram  : ORIGIN = 0x0f000000, LENGTH = 8K
}

SECTIONS {
  . = ORIGIN(flash);

  /* --- FSBL 阶段 --- */
  .fsbl_text : {
    _fsbl_vma_start = .;
    KEEP(*(entry))
    *(.text.fsbl*)          
    . = ALIGN(4);
    _fsbl_vma_end = .;
  } > flash

  _flash_lma = ALIGN(., 0x1000); 

  /* --- SSBL 阶段 (SRAM) --- */
  _ssbl_lma_start = _flash_lma;
  .ssbl_text : AT(_ssbl_lma_start) {
    _ssbl_vma_start = .;
    *(.text.ssbl*)         
    . = ALIGN(4);
    _ssbl_vma_end = .;
  } > sram
  _flash_lma = ALIGN(_ssbl_lma_start + SIZEOF(.ssbl_text), 0x1000);

  /* --- App 代码段 (.text) --- */
  _text_lma_start = _flash_lma;
  .text : AT(_text_lma_start) {
    _text_vma_start = .;
    *(.text*)
    
    /* 核心修正：补全 utest 符号，使用更通用的段匹配 */
    . = ALIGN(4);
    __rt_utest_tc_tab_start = .;
    KEEP(*(UtestTcTab))
    KEEP(*(.rt_utest_tc_tab*)) /* 增加对小写段名的支持 */
    __rt_utest_tc_tab_end = .;
    
    . = ALIGN(4);
    _text_vma_end = .;
  } > psram
  _flash_lma = ALIGN(_text_lma_start + SIZEOF(.text), 0x1000);

  /* --- 只读数据段 (.rodata) --- */
  _rodata_lma_start = _flash_lma;
  .rodata : AT(_rodata_lma_start) {
    _rodata_vma_start = .;
    *(.rodata*)
    *(.srodata*)
    . = ALIGN(4);
    _rodata_vma_end = .;
  } > psram
  _flash_lma = ALIGN(_rodata_lma_start + SIZEOF(.rodata), 0x1000);

  /* --- 可变数据段 (.data) --- */
  _data_lma_start = _flash_lma;
  .data : AT(_data_lma_start) {
    _data_vma_start = .;
    __am_apps_data_start = .;
    *(.data*)
    *(.sdata*)
    *(.am_apps.data*)
    __am_apps_data_end = .;

    . = ALIGN(4);
    __fsymtab_start = .; KEEP(*(FSymTab)) __fsymtab_end = .;
    __vsymtab_start = .; KEEP(*(VSymTab)) __vsymtab_end = .;
    __rt_init_start = .; KEEP(*(SORT(.rti_fn*))) __rt_init_end = .;
    
    . = ALIGN(4);
    _data_vma_end = .;
  } > psram
  _flash_lma = ALIGN(_data_lma_start + SIZEOF(.data), 0x1000);

  /* --- 未初始化数据段 (.bss) --- */
  .bss (NOLOAD) : {
    . = ALIGN(8);
    _bss_vma_start = .;
    __am_apps_bss_start = .;
    *(.bss*)
    *(.sbss*)
    *(.am_apps.bss*)
    __am_apps_bss_end = .;
    . = ALIGN(4);
    _bss_vma_end = .;
  } > psram

  /* 符号定义 */
  _stack_pointer = ORIGIN(sram) + LENGTH(sram);
  _heap_start = ALIGN(_bss_vma_end, 0x10);
  _heap_end = ORIGIN(psram) + LENGTH(psram);
}