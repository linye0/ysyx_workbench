#include <common.h>
#include <getopt.h>
#include <npc.h>
#include <sdb.h>
#include <utils.h>

static void welcome() {
	printf("Welcome to npc!\n");
}

static char* img_file = NULL;
static char* elf_file = NULL;

void parse_elf(const char* elf_file);

static int parse_args(int argc, char *argv[]) {
	const struct option table[] = {
		{"img", required_argument, NULL, 'i'},
		{"elf", required_argument, NULL, 'e'},
	};
	int o;
	while ((o = getopt_long(argc, argv, "i:e:", table, NULL)) != -1) {
		switch (o) {
			case 'i': img_file = optarg; break;
			case 'e': elf_file = optarg; break;	
			default:
					printf("read argument error\n");
					exit(0);
		}
	}
	return 0;
}

void init_monitor(int argc, char* argv[]) {
	parse_args(argc, argv);

	init_sdb();

	init_log("npc-log.log");

	parse_elf(elf_file);

	if(CONFIG_ITRACE) init_disasm();

	npc.init_npc(img_file);

	welcome();
}
