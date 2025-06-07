#include "isa.h"
#include <common.h>
#include <cpu.h>
#include <memory.h>
#include <dlfcn.h>
#include <difftest.h>

extern NPCState npc;
extern const char* regs[];

uint8_t pmem_ref[MSIZE] = {};

void (*ref_difftest_memcpy)(paddr_t addr, void *buf, size_t n, bool direction) = NULL;
void (*ref_difftest_regcpy)(void *dut, bool direction) = NULL;
void (*ref_difftest_exec)(uint64_t n) = NULL;
void (*ref_difftest_raise_intr)(uint64_t NO) = NULL;
void (*ref_difftest_init)(int port) = NULL;

void init_difftest(char* ref_so_file, long img_size, int port) { 
#ifdef CONFIG_DIFFTEST
    assert(ref_so_file != NULL);

    printf("init_difftest...\n");
    void* handle;
    handle = dlopen(ref_so_file, RTLD_LAZY);
    assert(handle != NULL);

    ref_difftest_memcpy = (void(*)(paddr_t, void*, size_t, bool))dlsym(handle, "difftest_memcpy");
    assert(ref_difftest_memcpy != NULL);
    ref_difftest_regcpy = (void(*)(void*, bool))dlsym(handle, "difftest_regcpy");
    assert(ref_difftest_regcpy != NULL);
    ref_difftest_exec = (void(*)(uint64_t))dlsym(handle, "difftest_exec");
    assert(ref_difftest_exec != NULL);
    ref_difftest_raise_intr = (void(*)(uint64_t))dlsym(handle, "difftest_raise_intr");
    assert(ref_difftest_raise_intr != NULL);
    ref_difftest_init = (void(*)(int))dlsym(handle, "difftest_init");
    assert(ref_difftest_init != NULL);

    ref_difftest_init(port);
    ref_difftest_memcpy(MBASE, guest_to_host(MBASE), img_size, DIFFTEST_TO_REF);
    ref_difftest_regcpy(&npc, DIFFTEST_TO_REF);
#endif
}

static void checkregs(NPCState *ref, vaddr_t pc) {
    bool is_same = true;
    if ((vaddr_t)(*(ref->cpc)) != pc) {
        printf(FMT_RED("[ERROR]") " pc is different! ref = " FMT_GREEN(FMT_WORD_NO_PREFIX) ", dut = " FMT_RED(FMT_WORD_NO_PREFIX) "\n",
           (vaddr_t)(*(ref->cpc)), pc);
        is_same = false;
    }
    for (int i = 0; i < GPR_SIZE; i++) {
        if (npc.gpr[i] != ref->gpr[i]) {
            printf(FMT_RED("[ERROR]") " gpr[%d](%s) is different! ref = " FMT_GREEN(FMT_WORD_NO_PREFIX) ", dut = " FMT_RED(FMT_WORD_NO_PREFIX) "\n",
                i, regs[i], ref->gpr[i], npc.gpr[i]);
            is_same = false;
        }
    }
    if (!is_same) {
        #ifdef CONFIG_ITRACE
        void itrace_display_history(int num);
        itrace_display_history(10);
        #endif
        printf("regs information:\n");
        print_all_regs();
        Assert(false, "difftest failed!\n");
    }
}


void difftest_step(vaddr_t pc) {
    NPCState ref_r;

    ref_difftest_exec(1);
    ref_difftest_regcpy(&ref_r, DIFFTEST_TO_DUT);
    checkregs(&ref_r, *npc.cpc);
}
