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

#include <common.h>

extern uint64_t g_nr_guest_inst;

#ifndef CONFIG_TARGET_AM
FILE *log_fp = NULL;
FILE *itrace_bin_fp = NULL;

typedef struct {
  vaddr_t start_pc;   // 这一段连续序列的起始地址
  uint32_t count;     // 这一段连续序列包含多少条指令
} itrace_node;

static itrace_node cur_node = {0, 0};
static vaddr_t last_pc = 0;

void init_log(const char *log_file) {
  log_fp = stdout;
  if (log_file != NULL) {
    FILE *fp = fopen(log_file, "w");
    Assert(fp, "Can not open '%s'", log_file);
    log_fp = fp;
  }
  Log("Log is written to %s", log_file ? log_file : "stdout");
}

void itrace_bin_record(vaddr_t pc) {
  if (itrace_bin_fp == NULL) return;

  // 如果这是第一条指令，或者不连续（跳转了），或者是 64 位 PC 翻转（罕见）
  if (cur_node.count == 0 || pc != last_pc + 4) {
    // 写入之前的记录
    if (cur_node.count > 0) {
      fwrite(&cur_node, sizeof(itrace_node), 1, itrace_bin_fp);
    }
    // 开启新的记录
    cur_node.start_pc = pc;
    cur_node.count = 1;
  } else {
    // 地址连续 (pc == last_pc + 4)，仅增加计数
    cur_node.count++;
  }
  last_pc = pc;
}

void init_itrace_bin(const char *path) {
  if (path == NULL) return;
  // 使用 popen 调用 bzip2，将输出重定向到以 .bz2 结尾的文件
  // "w" 表示我们要向这个管道写入数据
  char command[1024];
  sprintf(command, "bzip2 > %s.bz2", path);
  itrace_bin_fp = popen(command, "w"); 
  
  Assert(itrace_bin_fp, "Can not open bzip2 pipe for itrace");
}

void finalize_itrace_bin() {
  if (itrace_bin_fp) {
    if (cur_node.count > 0) {
      fwrite(&cur_node, sizeof(itrace_node), 1, itrace_bin_fp);
    }
    // 注意：popen 打开的流必须使用 pclose 关闭，而不是 fclose
    pclose(itrace_bin_fp);
    itrace_bin_fp = NULL;
  }
}

bool log_enable() {
  return MUXDEF(CONFIG_TRACE, (g_nr_guest_inst >= CONFIG_TRACE_START) &&
         (g_nr_guest_inst <= CONFIG_TRACE_END), false);
}
#endif
