#include <common.h>

void init_monitor(int, char* []);
void main_loop();
int is_exit_status_bad();

int main(int argc, char* argv[]) {
	init_monitor(argc, argv);

	main_loop();

	return is_exit_status_bad();
}
