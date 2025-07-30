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

#include <isa.h>
#include <cpu/cpu.h>
#include <readline/readline.h>
#include <readline/history.h>
#include "sdb.h"

static int is_batch_mode = false;

void init_regex();
void init_wp_pool();

/* We use the `readline' library to provide more flexibility to read from stdin. */
static char* rl_gets() {
  static char *line_read = NULL;

  if (line_read) {
    free(line_read);
    line_read = NULL;
  }

  line_read = readline("(nemu) ");

  if (line_read && *line_read) {
    add_history(line_read);
  }

  return line_read;
}

static int cmd_c(char *args) {
  cpu_exec(-1);
  return 0;
}

static int cmd_q(char *args) {
  nemu_state.state = NEMU_QUIT;
  return -1;
}

static int cmd_si(char *args)
{
  int n;
  if (args==NULL){
    n=1;
  }
  else sscanf(args,"%d",&n);
  cpu_exec(n);
  return 0;
}
 
//打印程序状态
static int cmd_info(char *args){
  if (args==NULL){
    printf("\"r\"-Print register status  or  \"w\"-Print watchpoint information\n");
  }
  else if (strcmp(args, "r") == 0){
    isa_reg_display();
  } else if (strcmp(args, "w") == 0) {
	void wp_print();
	wp_print();
  }
 
  return 0;
}
 
//扫描内存
static int cmd_x(char *args){
  if (args == NULL) {
        printf("Wrong Command!\n");
        return 0;
    }                                                                           
	int N;
	char expression[100];
	word_t paddr_read(paddr_t addr, int len);
	sscanf(args,"%d%s",&N,expression);
	bool success;
	int startAddress = expr(expression, &success);
	if (!success) {
		printf("invalid expression!\n");
		return 0;
	}
	for (int i = 0;i < N;i ++){
      printf("%x\n", paddr_read(startAddress,4));
      //C语言会自动执行类型提升以匹配表达式的操作数的类型。所以，4 被转换为 uint32_t，
      startAddress += 4;
  
  }
   return 0;
}

static int cmd_w(char* args) {
	if (args == NULL) {
		printf("Need a expression to set watchpoint!\n");
		return 0;
	}
	bool success;
	int res = expr(args, &success);
	if (!success) {
		printf("not success\n");
		return 0;
	}
	void wp_set(char* args, int32_t res);
	wp_set(args, res);
	return 0;
}

static int cmd_b(char* args) {
	if (args == NULL) {
		printf("Need an address to set breakpoint!\n");
		return 0;
	}
	char pcstr[50];
	strcpy(pcstr, "$pc==");
	strcat(pcstr, args);
	printf("%s\n", pcstr);
	cmd_w(pcstr);
	return 0;
}

static int cmd_p(char* args) {
	if (args == NULL) {
		printf("Wrong Command: expr cannot be empty!\n");
		return 0;
	}
	bool success;
	int res = expr(args, &success);
	if (success)
		printf("%d\n", res);
	else 
		printf("not suceess\n");
	return 0;
}

static int cmd_d(char* args) {
	if (args == NULL) {
		return 0;
	}
	int n;
	sscanf(args, "%d", &n);
	void wp_remove(int no);
	wp_remove(n);
	return 0;
}

static int cmd_h(char *args) {
  if (args == NULL) {
    printf("Need a number to print history!\n");
    return 0;
  }
  int num = atoi(args);
  void itrace_display_history(int num);
  itrace_display_history(num);
  return 0;
}

static int cmd_test(char *args){
  int right_ans = 0;
  FILE *input_file = fopen("/home/lockedcore/ysyx/ics2024/nemu/tools/gen-expr/output", "r");
    if (input_file == NULL) {
        perror("Error opening input file");
        return 1;
    }
 
    char record[1024];
    unsigned real_val;
    char buf[1024];
 
    // 循环读取每一条记录
    for (int i = 0; i < 100; i++) {
        // 读取一行记录
        if (fgets(record, sizeof(record), input_file) == NULL) {
            perror("Error reading input file");
            break;
        }
 
        // 分割记录，获取数字和表达式
        char *token = strtok(record, " ");
        if (token == NULL) {
            printf("Invalid record format\n");
            continue;
        }
        real_val = atoi(token); // 将数字部分转换为整数
 
        // 处理表达式部分，可能跨越多行
        strcpy(buf, ""); // 清空buf
        while ((token = strtok(NULL, "\n")) != NULL) {
            strcat(buf, token);
            strcat(buf, " "); // 拼接换行后的部分，注意添加空格以分隔多行内容
        }
 
        // 输出结果
        printf("Real Value: %u, Expression: %s\n", real_val, buf);
        bool flag = false;
        unsigned res = expr(buf,&flag);
        if(res == real_val)right_ans ++;
 
    }
    printf("test 100 expressions,the accuracy is %d/100\n",right_ans);
    fclose(input_file);
    return 0;
}

static int cmd_help(char *args);

static struct {
  const char *name;
  const char *description;
  int (*handler) (char *);
} cmd_table [] = {
  { "help", "Display information about all supported commands", cmd_help },
  { "c", "Continue the execution of the program", cmd_c },
  { "q", "Exit NEMU", cmd_q },

  /* TODO: Add more commands */
  { "si", "Single step execute", cmd_si},
  { "info", "Print information", cmd_info},
  { "x", "Print memory", cmd_x},
  { "p", "Calculate expression", cmd_p},
  { "w", "Set watchpoint", cmd_w},
  { "d", "Delete watchpoint", cmd_d},
  { "test", "Test p command accuracy", cmd_test},
  { "b", "Set breakpoint", cmd_b},
  { "h", "Print history", cmd_h}
};

#define NR_CMD ARRLEN(cmd_table)


static int cmd_help(char *args) {
  /* extract the first argument */
  char *arg = strtok(NULL, " ");
  int i;

  if (arg == NULL) {
    /* no argument given */
    for (i = 0; i < NR_CMD; i ++) {
      printf("%s - %s\n", cmd_table[i].name, cmd_table[i].description);
    }
  }
  else {
    for (i = 0; i < NR_CMD; i ++) {
      if (strcmp(arg, cmd_table[i].name) == 0) {
        printf("%s - %s\n", cmd_table[i].name, cmd_table[i].description);
        return 0;
      }
    }
    printf("Unknown command '%s'\n", arg);
  }
  return 0;
}

void sdb_set_batch_mode() {
  is_batch_mode = true;
}

void sdb_mainloop() {
  if (is_batch_mode) {
    cmd_c(NULL);
    return;
  }

  for (char *str; (str = rl_gets()) != NULL; ) {
    char *str_end = str + strlen(str);

    /* extract the first token as the command */
    char *cmd = strtok(str, " ");
    if (cmd == NULL) { continue; }

    /* treat the remaining string as the arguments,
     * which may need further parsing
     */
    char *args = cmd + strlen(cmd) + 1;
    if (args >= str_end) {
      args = NULL;
    }

#ifdef CONFIG_DEVICE
    extern void sdl_clear_event_queue();
    sdl_clear_event_queue();
#endif

    int i;
    for (i = 0; i < NR_CMD; i ++) {
      if (strcmp(cmd, cmd_table[i].name) == 0) {
        if (cmd_table[i].handler(args) < 0) { return; }
        break;
      }
    }

    if (i == NR_CMD) { printf("Unknown command '%s'\n", cmd); }
  }
}

void init_sdb() {
  /* Compile the regular expressions. */
  init_regex();

  /* Initialize the watchpoint pool. */
  init_wp_pool();
}
