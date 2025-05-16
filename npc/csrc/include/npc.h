#ifndef __NPC_H__ 
#define __NPC_H_

#include "verilated_vcd_c.h"
#include "Vysyx_25040131_cpu.h"
#include "stdio.h"
#include <stdlib.h>
#include <bits/stdc++.h>

static Vysyx_25040131_cpu dut;
extern "C" void npc_trap();
extern "C" uint32_t get_flag();
uint32_t *init_mem(size_t size);
uint32_t guest_to_host(uint32_t addr);
uint32_t pmem_read(uint32_t *memory, uint32_t vaddr);
uint32_t read_img(uint32_t*, const char*);

char* bin_path;
bool endflag;
uint32_t* memory;

#endif

