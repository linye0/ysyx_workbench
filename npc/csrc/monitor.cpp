#include <common.h>
#include <getopt.h>
#include <npc.h>
#include <sdb.h>

static void welcome() {
	printf("Welcome to npc!\n");
}

static char* img_file = NULL;

static int parse_args(int argc, char *argv[]) {
	const struct option table[] = {
		{"img", required_argument, NULL, 'i'}
	};
	int o;
	while ((o = getopt_long(argc, argv, "i:", table, NULL)) != -1) {
		switch (o) {
			case 'i': img_file = optarg; return 0;
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

	npc.init_npc(img_file);

	welcome();
}
