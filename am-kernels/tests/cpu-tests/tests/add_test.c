#include "trap.h"

int add(int a, int b) {
	int c = a + b;
	return c;
}

int test_data[] = {0, 1, 2};
int ans[] = {0, 0x1, 0x2, 0x1, 0x2, 0x3, 0x2, 0x3, 0x4};

#define NR_DATA LENGTH(test_data)

int main() {
	int i, j, ans_idx = 0;
	for(i = 0; i < NR_DATA; i ++) {
		for(j = 0; j < NR_DATA; j ++) {
			check(add(test_data[i], test_data[j]) == ans[ans_idx ++]);
		}
		check(j == NR_DATA);
	}

	check(i == NR_DATA);

	return 0;
}
