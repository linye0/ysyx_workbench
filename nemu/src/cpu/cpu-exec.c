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

#include <cpu/cpu.h>
#include <cpu/decode.h>
#include <cpu/difftest.h>
#include <utils.h>
#include <locale.h>
#include <isa.h>

#ifdef CONFIG_NPC
#include <npc/npc_verilog.h>
#endif

/* The assembly code of instructions executed is only output to the screen
 * when the number of instructions executed is less than this value.
 * This is useful when you use the `si' command.
 * You can modify this value as you want.
 */
#define MAX_INST_TO_PRINT 15

CPU_state cpu = {};
uint64_t g_nr_guest_inst = 0;
static uint64_t g_timer = 0; // unit: us
static bool g_print_step = false;
// 用于特判的bool

void device_update();

static void trace_and_difftest(Decode *_this, vaddr_t dnpc) {
  if (g_print_step) { IFDEF(CONFIG_ITRACE, puts(_this->logbuf)); }
  IFDEF(CONFIG_DIFFTEST, 
    IFDEF(CONFIG_NPC, 
      if (*(nemu_state.valid_signal) == 1) {
        // printf("difftest_step\n");
        // printf("_this->pc: 0x%x, dnpc: 0x%x\n", _this->pc, dnpc);
        difftest_step(_this->pc, dnpc);
      }
    )
  );
  int wp_difftest(void);
  if (wp_difftest() > 0) nemu_state.state = NEMU_STOP;
}

#ifdef CONFIG_NPC
void check_pc_bound() {
  bool in_bound = 
    (cpu.cpc >= CONFIG_SRAM_BASE && cpu.cpc < CONFIG_SRAM_BASE + CONFIG_SRAM_SIZE) || 
    (cpu.cpc >= CONFIG_PSRAM_BASE && cpu.cpc < CONFIG_PSRAM_BASE + CONFIG_PSRAM_SIZE) ||
    (cpu.cpc >= CONFIG_FLASH_BASE && cpu.cpc < CONFIG_FLASH_BASE + CONFIG_FLASH_SIZE) ||
    (cpu.cpc >= CONFIG_SDRAM_BASE && cpu.cpc < CONFIG_SDRAM_BASE + CONFIG_SDRAM_SIZE);
  if (!in_bound) {
    printf("pc out of bound: 0x%x\n", cpu.cpc);
    isa_reg_display();
    nemu_state.state = NEMU_ABORT;
  }
  return ;
}
#endif

static void exec_once(Decode *s, vaddr_t pc) {
  s->pc = pc;
  s->snpc = pc;
  isa_exec_once(s);
  #ifdef CONFIG_NPC
  check_pc_bound();
  #endif
  #ifndef CONFIG_NPC
  cpu.pc = s->dnpc;
  #endif
#ifdef CONFIG_ITRACE
#ifdef CONFIG_NPC
if (*(nemu_state.valid_signal) == 1) {
#endif
  char *p = s->logbuf;
  #ifndef CONFIG_NPC
  p += snprintf(p, sizeof(s->logbuf), FMT_WORD ":", s->pc);
  #endif
  #ifdef CONFIG_NPC
  p += snprintf(p, sizeof(s->logbuf), FMT_WORD ":", *(nemu_state.cpc));
  #endif
  int ilen = s->snpc - s->pc;
  int i;
  uint8_t *inst = (uint8_t *)&s->isa.inst;
#ifdef CONFIG_ISA_x86

  for (i = 0; i < ilen; i ++) {
#else
  for (i = ilen - 1; i >= 0; i --) {
#endif
    p += snprintf(p, 4, " %02x", inst[i]);
  }

  int ilen_max = MUXDEF(CONFIG_ISA_x86, 8, 4);
  int space_len = ilen_max - ilen;
  if (space_len < 0) space_len = 0;
  space_len = space_len * 3 + 1;
  memset(p, ' ', space_len);
  p += space_len;
  // printf("s->isa.inst: 0x%x\n", s->isa.inst);
  void disassemble(char *str, int size, uint64_t pc, uint8_t *code, int nbyte);
  disassemble(p, s->logbuf + sizeof(s->logbuf) - p,
      MUXDEF(CONFIG_ISA_x86, s->snpc, s->pc), (uint8_t *)&s->isa.inst, ilen);
  void itrace_record(const char *log, vaddr_t pc);
  itrace_record(s->logbuf, s->pc);
  #ifdef CONFIG_NPC
  }
  #endif
#endif
}

static void execute(uint64_t n) {
  Decode s;
  #ifdef CONFIG_NPC
  // PC 卡死检测：记录上一次的 PC 值和时间
  static vaddr_t last_pc = 0;
  static uint64_t last_pc_time = 0;
  static uint64_t same_pc_count = 0;
  const uint64_t PC_STUCK_THRESHOLD = 10000000; // 10秒 (微秒)
  #endif
  
  for (;n > 0; n --) {
    #ifdef CONFIG_NPC
    vaddr_t current_pc = *(nemu_state.pc);
    
    // 检查 PC 是否变化
    if (current_pc == last_pc) {
      same_pc_count++;
      // 每隔一定次数检查一次时间（避免频繁调用 get_time）
      if (same_pc_count % 100000 == 0) {
        printf("same_pc_count check.\n");
        uint64_t current_time = get_time();
        uint64_t time_elapsed = current_time - last_pc_time;
        if (time_elapsed > PC_STUCK_THRESHOLD) {
          printf("\n" ANSI_FMT("ERROR: PC stuck at 0x%08x for more than 10 seconds!", ANSI_FG_RED) "\n", current_pc);
          printf("Time elapsed: %lu us (%.2f seconds)\n", time_elapsed, time_elapsed / 1000000.0);
          printf("Instruction count at same PC: %lu\n", same_pc_count);
          isa_reg_display();
          Assert(0, "PC stuck detected - possible infinite loop or hardware hang");
        }
      }
    } else {
      // PC 发生了变化，重置计数器和时间
      last_pc = current_pc;
      last_pc_time = get_time();
      same_pc_count = 0;
    }
    
    exec_once(&s, current_pc);
    #else
    exec_once(&s, cpu.pc);
    #endif
    g_nr_guest_inst ++;
    trace_and_difftest(&s, cpu.pc);

    if (nemu_state.state != NEMU_RUNNING) break;
    IFDEF(CONFIG_DEVICE, device_update());
  }
}

static void statistic() {
  IFNDEF(CONFIG_TARGET_AM, setlocale(LC_NUMERIC, ""));
#define NUMBERIC_FMT MUXDEF(CONFIG_TARGET_AM, "%", "%'") PRIu64
  Log("host time spent = " NUMBERIC_FMT " us", g_timer);
  Log("total guest instructions = " NUMBERIC_FMT, g_nr_guest_inst);
  if (g_timer > 0) Log("simulation frequency = " NUMBERIC_FMT " inst/s", g_nr_guest_inst * 1000000 / g_timer);
  else Log("Finish running in less than 1 us and can not calculate the simulation frequency");
}

void assert_fail_msg() {
  isa_reg_display();
  statistic();
  #ifdef CONFIG_NPC
  if (tfp) {
    tfp->flush();
  }
  #endif
}

/* Simulate how the CPU works. */
void cpu_exec(uint64_t n) {
  g_print_step = (n < MAX_INST_TO_PRINT);
  switch (nemu_state.state) {
    case NEMU_END: case NEMU_ABORT: case NEMU_QUIT:
      printf("Program execution has ended. To restart the program, exit NEMU and run again.\n");
      return;
    default: nemu_state.state = NEMU_RUNNING;
  }

  uint64_t timer_start = get_time();

  execute(n);

  uint64_t timer_end = get_time();
  g_timer += timer_end - timer_start;

  switch (nemu_state.state) {
    case NEMU_RUNNING: nemu_state.state = NEMU_STOP; break;

    case NEMU_END: case NEMU_ABORT:
	  #ifdef CONFIG_ITRACE_COND
	  if (nemu_state.state == NEMU_ABORT || nemu_state.halt_ret != 0) {
		  printf("Program exits because of ABORT or ERROR.\n");
		  void itrace_display_history(int num);
		  itrace_display_history(40);
	  }
      #endif 
      #ifndef CONFIG_NPC
      Log("nemu: %s at pc = " FMT_WORD,
          (nemu_state.state == NEMU_ABORT ? ANSI_FMT("ABORT", ANSI_FG_RED) :
           (nemu_state.halt_ret == 0 ? ANSI_FMT("HIT GOOD TRAP", ANSI_FG_GREEN) :
            ANSI_FMT("HIT BAD TRAP", ANSI_FG_RED))),
          nemu_state.halt_pc);
      #else
      if (tfp) {
        tfp->close();
      }
      Log("npc: %s at pc = " FMT_WORD,
          (nemu_state.state == NEMU_ABORT ? ANSI_FMT("ABORT", ANSI_FG_RED) :
           (nemu_state.halt_ret == 0 ? ANSI_FMT("HIT GOOD TRAP", ANSI_FG_GREEN) :
            ANSI_FMT("HIT BAD TRAP", ANSI_FG_RED))),
          nemu_state.halt_pc);
      #endif
      // fall through
    case NEMU_QUIT:
      #ifdef CONFIG_NPC
      if (tfp) {
        tfp->close();
      }
      #endif
      statistic();
  }
}
