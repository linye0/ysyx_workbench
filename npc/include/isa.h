#ifndef __ISA_H__
#define __ISA_H__

#include <stdint.h>
extern const char *regs[];  // 声明（不分配内存） 

void isa_reg_display();
uint32_t isa_reg_str2val(const char *s, bool *success);
uint32_t paddr_read(int addr);
void print_all_regs();

#endif
