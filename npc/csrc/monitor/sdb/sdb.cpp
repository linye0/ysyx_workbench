#include <common.h>
#include <macro.h>
#include <npc.h>
#include <isa.h>
#include <sdb.h>
#include <readline/readline.h>
#include <readline/history.h>

static char* rl_gets() {
  static char *line_read = NULL;

  if (line_read) {
    free(line_read);
    line_read = NULL;
  }

  line_read = readline("(npc) ");

  if (line_read && *line_read) {
	add_history(line_read);
  }

  return line_read;
}

static int cmd_info(char *args) {
	if (args == NULL) {
		printf("\"r\"-Print register status  or  \"w\"-Print watchpoint information\n");
	}
	else if (strcmp(args, "r") == 0) {
		print_all_regs();
	} else if (strcmp(args, "w") == 0) {
		info_watchpoint();
	}
	return 0;
}


static int cmd_x(char* args) {
  if (args == NULL) {
        printf("Wrong Command!\n");
        return 0;
    }                                                                           
	int N;
	char expression[100];
	sscanf(args,"%d%s",&N,expression);
	bool success;
	int startAddress = expr(expression, &success);
	if (!success) {
		printf("invalid expression!\n");
		return 0;
	}
	for (int i = 0;i < N;i ++){
      printf("%x\n", paddr_read(startAddress));
      //C语言会自动执行类型提升以匹配表达式的操作数的类型。所以，4 被转换为 uint32_t，
      startAddress += 4;
	}
	return 0;
}

static int cmd_d(char* args) {
	if (args == NULL) {
		return 0;
	}
	int n;
	sscanf(args, "%d", &n);
	wp_remove(n);
	return 0;
}

static int cmd_c(char* args) {
	npc.npc_exec(-1);
	return 0;
}

static int cmd_p(char* args) {
	if (args == NULL) {
		printf("Wrong command: expr cannot be empty!\n");
		return 0;
	}
	bool success;
	int res = expr(args, &success);
	if (success) 
		printf("%d\n", res);
	else
		printf("Not success\n");
	return 0;
}

static int cmd_si(char* args) {
	int n;
	if (args == NULL) {
		n = 1;
	} else sscanf(args, "%d", &n);
	npc.npc_exec(n);
	return 0;
}

static int cmd_q(char* args) {
	npc.set_state(STATE_QUIT);
	return -1;
}

static int cmd_w(char* args) {
	bool success;
	int ret = expr(args, &success);
	if (success) {
		printf("Successfully set the watchpoint!\n");
		wp_set(args, ret);
	} else
		printf("Not success: the expression is illegal!\n");
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

static int cmd_help(char*);

static struct {
	const char* name;
	const char* description;
	int (*handler) (char *);
} cmd_table [] = {
	{"help", "Display information about all supported commands", cmd_help},
	{"c", "Continue the exection of the program", cmd_c},
	{"q", "Exit NPC", cmd_q},
	{"x", "Print Memory", cmd_x},
	{"si", "Single step execute", cmd_si},
	{"info", "Print information", cmd_info},
	{"p", "Calculate expression", cmd_p},
	{"w", "set point", cmd_w},
    { "d", "Delete watchpoint", cmd_d},
	{ "b", "Set breakpoint", cmd_b}
};

#define NR_CMD ARRLEN(cmd_table)

static int cmd_help(char* args) {
	char* arg = strtok(NULL, " ");
	int i;

	if (arg == NULL) {
		for (int i = 0; i < NR_CMD; i++) {
			printf("%s - %s\n", cmd_table[i].name, cmd_table[i].description);
		}
	}
	else {
		for (int i = 0; i < NR_CMD; i++) {
			if (strcmp(arg, cmd_table[i].name) == 0) {
				printf("%s - %s\n", cmd_table[i].name, cmd_table[i].description);
				return 0;
			}
		}
		printf("Unknown commands '%s'\n", arg);
	}
	return 0;
}


void main_loop() {
	
	// 读入一个cmd，并且执行相关的操作，如果在操作之后检测到state不为running，则退出
	for (char* str; (str = rl_gets()) != NULL; ) {
		char *str_end = str + strlen(str);
		char *cmd = strtok(str, " ");
		if (cmd == NULL) {continue; }
		char *args = cmd + strlen(cmd) + 1;
		if (args >= str_end) {
			args = NULL;
		}

		int i;
		for (i = 0; i < NR_CMD; i++) {
			if (strcmp(cmd, cmd_table[i].name) == 0) {
				if (cmd_table[i].handler(args) < 0) {return;}
				break;
			}
		}
		
		if (i == NR_CMD) {printf("Unknown command '%s'\n", cmd); }
	}

}

void init_sdb() {
	init_regex();
	init_wp_pool();
	using_history();
}
