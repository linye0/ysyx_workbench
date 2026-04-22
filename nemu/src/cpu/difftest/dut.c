/***************************************************************************************
* Copyright (c) 2014-2024 Zihao Yu, Nanjing University
*
* NEMU is licensed under Mulan PSL v2.
* You can use this software according to the terms and conditions of the Mulan PSL v2.
* You may obtain a copy of Mulan PSL v2 at:
*          http://license.coscl.org.cn/MulanPSL2
*
* THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
* EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
* MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
*
* See the Mulan PSL v2 for more details.
***************************************************************************************/

#include "common.h"
#include <dlfcn.h>

#include <isa.h>
#include <cpu/cpu.h>
#include <memory/paddr.h>
#include <utils.h>
#include <difftest-def.h>
#include <cpu/difftest.h>

void (*ref_difftest_memcpy)(paddr_t addr, void *buf, size_t n, bool direction) = NULL;
#ifdef CONFIG_NPC
void (*ref_difftest_regcpy)(void *dut, int direction) = NULL;
#else
void (*ref_difftest_regcpy)(void *dut, bool direction) = NULL;
#endif
void (*ref_difftest_exec)(uint64_t n) = NULL;
void (*ref_difftest_raise_intr)(uint64_t NO) = NULL;
void (*ref_difftest_reg_display)(void) = NULL;
void (*ref_difftest_mem_display)(int N, int startAddress) = NULL;
#ifdef CONFIG_NPC
word_t (*ref_difftest_paddr_read)(paddr_t addr, int len) = NULL;
Mem_flag (*ref_difftest_mem_flag_to_dut)(void) = NULL;
#endif

#ifdef CONFIG_DIFFTEST

static bool is_skip_ref = false;
static int skip_dut_nr_inst = 0;

// this is used to let ref skip instructions which
// can not produce consistent behavior with NEMU
void difftest_skip_ref() {
  //printf("difftest_skip_ref\n");
  is_skip_ref = true;
  // If such an instruction is one of the instruction packing in QEMU
  // (see below), we end the process of catching up with QEMU's pc to
  // keep the consistent behavior in our best.
  // Note that this is still not perfect: if the packed instructions
  // already write some memory, and the incoming instruction in NEMU
  // will load that memory, we will encounter false negative. But such
  // situation is infrequent.
  skip_dut_nr_inst = 0;
}

// this is used to deal with instruction packing in QEMU.
// Sometimes letting QEMU step once will execute multiple instructions.
// We should skip checking until NEMU's pc catches up with QEMU's pc.
// The semantic is
//   Let REF run `nr_ref` instructions first.
//   We expect that DUT will catch up with REF within `nr_dut` instructions.
void difftest_skip_dut(int nr_ref, int nr_dut) {
  skip_dut_nr_inst += nr_dut;

  while (nr_ref -- > 0) {
    ref_difftest_exec(1);
  }
}


void init_difftest(char *ref_so_file, long img_size, int port) {
  assert(ref_so_file != NULL);

  void *handle;
  handle = dlopen(ref_so_file, RTLD_LAZY);
  // printf("%s\n", ref_so_file);
  assert(handle);

  ref_difftest_memcpy = dlsym(handle, "difftest_memcpy");
  assert(ref_difftest_memcpy);

  ref_difftest_regcpy = dlsym(handle, "difftest_regcpy");
  assert(ref_difftest_regcpy);

  ref_difftest_exec = dlsym(handle, "difftest_exec");
  assert(ref_difftest_exec);

  ref_difftest_raise_intr = dlsym(handle, "difftest_raise_intr");
  assert(ref_difftest_raise_intr);

  #ifdef CONFIG_NPC
  ref_difftest_reg_display = dlsym(handle, "difftest_reg_display");
  assert(ref_difftest_reg_display);

  ref_difftest_mem_display = dlsym(handle, "difftest_mem_display");
  assert(ref_difftest_mem_display);
  #endif

  #ifdef CONFIG_NPC
  ref_difftest_paddr_read = dlsym(handle, "difftest_paddr_read");
  assert(ref_difftest_raise_intr);

  ref_difftest_mem_flag_to_dut = dlsym(handle, "difftest_mem_flag_to_dut");
  assert(ref_difftest_mem_flag_to_dut);
  #endif

  void (*ref_difftest_init)(int) = dlsym(handle, "difftest_init");
  assert(ref_difftest_init);

  Log("Differential testing: %s", ANSI_FMT("ON", ANSI_FG_GREEN));
  Log("The result of every instruction will be compared with %s. "
      "This will help you a lot for debugging, but also significantly reduce the performance. "
      "If it is not necessary, you can turn it off in menuconfig.", ref_so_file);

  ref_difftest_init(port);
  ref_difftest_memcpy(CONFIG_MBASE, guest_to_host(CONFIG_MBASE), img_size, DIFFTEST_TO_REF);
  #ifdef CONFIG_NPC
  #ifdef CONFIG_SYS_SOC
  ref_difftest_memcpy(CONFIG_MROM_BASE, guest_to_host(CONFIG_MROM_BASE), CONFIG_MROM_SIZE, DIFFTEST_TO_REF);
  ref_difftest_memcpy(CONFIG_FLASH_BASE, guest_to_host(CONFIG_FLASH_BASE), CONFIG_FLASH_SIZE, DIFFTEST_TO_REF);
  ref_difftest_memcpy(CONFIG_SRAM_BASE, guest_to_host(CONFIG_SRAM_BASE), CONFIG_SRAM_SIZE, DIFFTEST_TO_REF);
  #endif
  #endif
  ref_difftest_regcpy(&cpu, DIFFTEST_TO_REF);
}

static void checkregs(CPU_state *ref, vaddr_t pc) {
  if (!isa_difftest_checkregs(ref, pc)) {
    printf("\nCan't pass checkregs!\n");
    nemu_state.state = NEMU_ABORT;
    nemu_state.halt_pc = pc;
    isa_reg_display();
  }
}

#ifdef CONFIG_NPC
static void checkmems(uint32_t addr, uint32_t wdata, uint32_t wstrb, vaddr_t pc) {
  // printf("dut data at address 0x%x: 0x%x\n", addr, paddr_read(addr, len));
  // printf("ref data at address 0x%x: 0x%x\n", addr, ref_difftest_paddr_read(addr, len));
  uint32_t addr_aligned = addr & ~0x03u;
  uint32_t ref_val = ref_difftest_paddr_read(addr_aligned, 4);
  uint32_t compare_mask = 0;
  for (int i = 0; i < 4; i++) {
    if ((wstrb >> i) & 1) {
      compare_mask |= (0xFFu << (i * 8));
    }
  }

  uint32_t dut_val_masked = wdata & compare_mask;
  uint32_t ref_val_masked = ref_val & compare_mask;
  if (dut_val_masked != ref_val_masked) {
    printf("\nCan't pass checkmems!\n");
    nemu_state.state = NEMU_ABORT;
    nemu_state.halt_pc = pc;
    printf("\n\033[1;31m[Difftest] Store Mismatch!\033[0m\n");
    printf("PC          : 0x%08x\n", pc);
    printf("Addr        : 0x%08x (Aligned: 0x%08x)\n", addr, addr_aligned);
    printf("Write Mask  : 0x%x (Hex)\n", wstrb);
    printf("Compare Mask: 0x%08x\n", compare_mask);
    printf("DUT Data    : 0x%08x (Masked: 0x%08x)\n", wdata, dut_val_masked);
    printf("REF Data    : 0x%08x (Masked: 0x%08x)\n", ref_val, ref_val_masked);
    isa_reg_display();
  }
  return;
}
#endif

void difftest_step(vaddr_t pc, vaddr_t npc) {
  // printf("difftest_step pc: 0x%x, npc: 0x%x\n", pc, npc);
  CPU_state ref_r;

  if (skip_dut_nr_inst > 0) {
    ref_difftest_regcpy(&ref_r, DIFFTEST_TO_DUT);
    if (ref_r.pc == npc) {
      skip_dut_nr_inst = 0;
      checkregs(&ref_r, npc);
      #ifdef CONFIG_NPC
      #ifdef CONFIG_DIFFTEST_MEM
      if (g_st_valid) {
        // printf("start checkmem at address 0x%x!\n", dut_flag.addr);
        checkmems(g_st_waddr, g_st_wdata, g_st_wstrb, g_wb_cpc);
      }
      #endif
      #endif
      return;
    }
    skip_dut_nr_inst --;
    if (skip_dut_nr_inst == 0)
      panic("can not catch up with ref.pc = " FMT_WORD " at pc = " FMT_WORD, ref_r.pc, pc);
    return;
  }


  if (is_skip_ref) {
    // to skip the checking of an instruction, just copy the reg state to reference design
    // printf("is_skip_ref, copy reg state to reference design, pc: 0x%x, npc: 0x%x\n", pc, npc);
    ref_difftest_regcpy(&cpu, DIFFTEST_TO_REF_SKIP_REF);
    is_skip_ref = false;
    return;
  }

  ref_difftest_exec(1);
  ref_difftest_regcpy(&ref_r, DIFFTEST_TO_DUT);

  checkregs(&ref_r, pc);
  #ifdef CONFIG_NPC
  #ifdef CONFIG_DIFFTEST_MEM
  if (g_st_valid) { 
    // if (dut_flag.addr >= CONFIG_SDRAM_BASE && dut_flag.addr < CONFIG_SDRAM_BASE + CONFIG_SDRAM_SIZE) printf("sdram memcheck at address 0x%x!\n", dut_flag.addr);
    checkmems(g_st_waddr, g_st_wdata, g_st_wstrb, g_wb_cpc);
  }
  #endif
  #endif
}
#else
void init_difftest(char *ref_so_file, long img_size, int port) { }
#endif
