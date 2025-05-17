#include <common.h>
#include <macro.h>
#include <npc.h>
#include <readline/readline.h>

static char* rl_gets() {
  static char *line_read = NULL;

  if (line_read) {
    free(line_read);
    line_read = NULL;
  }

  line_read = readline("(npc) ");

  return line_read;
}



static int cmd_c(char* args) {
	npc.npc_exec(-1);
	return -1;
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

static int cmd_help(char*);

static struct {
	const char* name;
	const char* description;
	int (*handler) (char *);
} cmd_table [] = {
	{"help", "Display information about all supported commands", cmd_help},
	{"c", "Continue the exection of the program", cmd_c},
	{"q", "Exit NPC", cmd_q},
	{"si", "Single step execute", cmd_si}
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
