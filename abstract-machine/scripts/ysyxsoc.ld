ENTRY(_start)

PHDRS { text PT_LOAD; data PT_LOAD; }

MEMORY {
  /* mrom : ORIGIN = 0x20000000, LENGTH = 4k */
  flash : ORIGIN = 0x30000000, LENGTH = 262144
  sram : ORIGIN = 0x0f000000, LENGTH = 8K
}

SECTIONS {
  /* _pmem_start and _entry_offset are defined in LDFLAGS */
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

  .data :
  {
    _data = .;
    *(.data*)
    *(.sdata*)
    _edata = .;
  } > sram AT> flash : data

  .bss (NOLOAD) :
  {
      _bstart = .;
    *(.bss*)
    *(.sbss*)
    *(.scommon)
    _bend = .;
  } > sram AT> sram

  _stack_top = ALIGN(0x10);
  . = _stack_top + 0x800;
  _stack_pointer = .;
  end = .;
  _end = .;
  _heap_start = ALIGN(0x10);
  _heap_end = _heap_start + 0x400;
}