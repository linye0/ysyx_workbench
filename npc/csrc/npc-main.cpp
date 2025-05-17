#include <common.h>

int main(int argc, char* argv[]) {
	init_monitor(argc, argv);
	
	main_loop();

	return is_exit_status_bad();
}
