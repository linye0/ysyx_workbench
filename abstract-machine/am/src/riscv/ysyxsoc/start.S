.section entry, "ax"
.globl _start
.type _start, @function

_start:
  mv s0, zero
  lui sp, %hi(_stack_pointer)
  addi sp, sp, %lo(_stack_pointer)
  call _trm_init
