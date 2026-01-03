#include "trap.h"
#include <stdint.h>

extern char _heap_start;
extern char _heap_end;

int main() {
    volatile uint32_t *start = (uint32_t *)(uintptr_t)0xa0000000;
    volatile uint32_t *end = (uint32_t *)(uintptr_t)(0xa0000000+ 0x0002000);
    int len_mask = 0xFFFF;
    int i = 0;

    //volatile uint32_t *test = (uint32_t *)(uintptr_t)0xa2000000;
    //*test = 0x12345678;
    //check(*(uint32_t *)test == 0x12345678);
    //check(*(uint8_t *)test == 0x78);
    //check(*((uint16_t *)test + 1) == 0x1234);

    for (; start < end; start++) {
        volatile uintptr_t addr = (uintptr_t)start;
        *start = (uint32_t)(addr & len_mask);

        check(*start == (uint32_t)(addr & len_mask));
        printf("check: %d\n", i++);
    }

    return 0;
}
