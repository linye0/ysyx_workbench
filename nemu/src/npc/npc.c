#include "common.h"
#include <npc/npc_verilog.h>
#include <isa.h>
#include <memory/host.h>
#include <memory/paddr.h>
#include <memory/vaddr.h>
#include <debug.h>
#include <utils.h>
#include <difftest-def.h>
#include <cpu/difftest.h>
#include <memory/paddr.h>


#ifdef CONFIG_NPC



void reset(TOP_NAME* top, int n) {
	top->reset = 1;
	for (int i = 0; i < n; i++) {
		void cpu_exec_once();
		cpu_exec_once();
	}
	top->reset = 0;
}

void init_verilog(int argc, char* argv[]) {
    Verilated::commandArgs(argc, argv);
	contextp = new VerilatedContext;
	contextp->commandArgs(argc, argv);
	top = new TOP_NAME{contextp};
	verilog_connect(top, &nemu_state);

    tfp = new VerilatedVcdC;
    contextp->traceEverOn(true);
    top->trace(tfp, 0);
    tfp->open("wave.vcd");


	reset(top, 32);  // 这个值如果设的太小的话，在接入SoC的时候，由于SoC里面的一个傻逼延迟器，会导致reset在复位之后又被短暂的设为1,导致出现bug

    update_cpu_state(nemu_state);
}

void cpu_exec_once() {
    // printf("before exec: cpu->gpr[2] = %d\n", nemu_state.gpr[2]);
    top->clock = (top->clock == 0) ? 1 : 0;
    top->eval();
    #ifdef CONFIG_GTKWAVE
    if (tfp) {
        tfp->dump(contextp->time());
        tfp->flush();
    }
    #endif
    // printf("cpu_exec_once: pc = 0x%x\n", top->pc);

    contextp->timeInc(1);
    top->clock = (top->clock == 0) ? 1 : 0;
    top->eval();
    #ifdef CONFIG_GTKWAVE
    if (tfp) {
        tfp->dump(contextp->time());
        tfp->flush();
    }
    #endif
    // printf("cpu_exec_once: pc = 0x%x\n", top->pc);

    contextp->timeInc(1);
    // printf("after exec: cpu->gpr[2] = %d\n", nemu_state.gpr[2]);
}

void update_cpu_state(NPCState npc) {
    // cpu.pc = *(npc.pc);
    // cpu.pc = top->pc;
    cpu.cpc = *(nemu_state.cpc);
    cpu.pc = *(nemu_state.pc);
    for (int i = 0; i < 32; i++) {
        cpu.gpr[i] = npc.gpr[i];
        // printf("cpu->gpr[%d]: %d\n", i, cpu.gpr[i]);
    }
    // TODO: fill in sr, priv and last_inst_priv.
    cpu.sr[CSR_MTVEC] = *(npc.mtvec);
    cpu.sr[CSR_MSTATUS] = *(npc.mstatus);
    cpu.sr[CSR_MEPC] = *(npc.mepc);
    cpu.sr[CSR_MCAUSE] = *(npc.mcause);
    cpu.sr[CSR_MTVAL] = *(npc.mtval);
    cpu.sr[CSR_MVENDORID] = *(npc.mvendorid);
    cpu.sr[CSR_MARCHID] = *(npc.marchid);
    return;
}

extern "C" void npc_exu_ebreak()
{
	contextp->gotFinish(true);
	// printf("EBREAK at pc = 0x%x\n", *(nemu_state.pc));
    nemu_state.halt_pc = *(nemu_state.pc) - 4;
	nemu_state.state = NEMU_END;
    nemu_state.halt_ret = (nemu_state.gpr)[10];
}

void verilog_connect(TOP_NAME *top, NPCState *npc)
{
  // for difftest
  npc->state = NEMU_RUNNING;
  #ifdef CONFIG_SYS_NPC
  npc->valid_signal = &(top->rootp->ysyx_25040131__DOT__difftest_signal);
  npc->inst = (uint32_t *)&(top->rootp->ysyx_25040131__DOT__out_inst);
  npc->gpr = (uint32_t *)&(top->rootp->ysyx_25040131__DOT__REG_FILE__DOT__regs);
  npc->cpc = (uint32_t *)&(top->rootp->ysyx_25040131__DOT__pc);
  npc->pc = (uint32_t *)&(top->rootp->ysyx_25040131__DOT__next_pc);
  npc->mtvec = (uint32_t*)&(top->rootp->ysyx_25040131__DOT__u_csr__DOT__mtvec);
  npc->mstatus = (uint32_t*)&(top->rootp->ysyx_25040131__DOT__u_csr__DOT__mstatus);
  npc->mepc = (uint32_t*)&(top->rootp->ysyx_25040131__DOT__u_csr__DOT__mepc);
  npc->mcause = (uint32_t*)&(top->rootp->ysyx_25040131__DOT__u_csr__DOT__mcause);
  npc->mtval = (uint32_t*)&(top->rootp->ysyx_25040131__DOT__u_csr__DOT__mtval);
  #else
  #ifdef CONFIG_SYS_SOC
  npc->valid_signal = &(CONCAT_YSYXSOC_HEAD(difftest_signal));
  npc->inst = (uint32_t *)&(CONCAT_YSYXSOC_HEAD(out_inst));
  npc->gpr = (uint32_t *)&(CONCAT_YSYXSOC_HEAD(REG_FILE__DOT__regs));
  npc->cpc = (uint32_t *)&(CONCAT_YSYXSOC_HEAD(pc));
  npc->pc = (uint32_t *)&(CONCAT_YSYXSOC_HEAD(next_pc));
  npc->mtvec = (uint32_t*)&(CONCAT_YSYXSOC_HEAD(u_csr__DOT__mtvec));
  npc->mstatus = (uint32_t*)&(CONCAT_YSYXSOC_HEAD(u_csr__DOT__mstatus));
  npc->mepc = (uint32_t*)&(CONCAT_YSYXSOC_HEAD(u_csr__DOT__mepc));
  npc->mcause = (uint32_t*)&(CONCAT_YSYXSOC_HEAD(u_csr__DOT__mcause));
  npc->mtval = (uint32_t*)&(CONCAT_YSYXSOC_HEAD(u_csr__DOT__mtval));
  npc->mvendorid = (uint32_t*)&(CONCAT_YSYXSOC_HEAD(u_csr__DOT__mvendorid));
  npc->marchid = (uint32_t*)&(CONCAT_YSYXSOC_HEAD(u_csr__DOT__marchid));
  npc->sram = (uint8_t*)&(CONCAT_YSYXSOC_ASIC_HEAD(axi4ram__DOT__mem_ext__DOT__Memory));
  #endif
  #endif

}

void npc_abort() {
	contextp->gotFinish(true);
	nemu_state.state = NEMU_ABORT;
}

extern "C" void npc_illegal_inst() {
	contextp->gotFinish(true);
	printf("Illegal instruction at pc = " FMT_WORD_NO_PREFIX "", *(nemu_state.pc));
	npc_abort();
}

extern "C" void npc_difftest_skip_ref() {
    difftest_skip_ref();
}

extern "C" void npc_difftest_mem_diff(int waddr, int wdata, int wstrb) {
    // TO DO
    
}

extern "C" int npc_read(int raddr, int wmask) {
    /*
    #ifdef CONFIG_HAS_TIMER
        if (raddr == RTC_ADDR + 4) {
            uint64_t t = get_time();
            rtc_port_base[0] = (uint32_t)(t >> 32);
            difftest_skip_ref();
            return rtc_port_base[0];
        } else if (raddr == RTC_ADDR) {
            uint64_t t = get_time();
            rtc_port_base[1] = (uint32_t)(t);
            difftest_skip_ref();
            return rtc_port_base[1];
        }
    #endif
    #ifdef CONFIG_DEBUG
    printf("pmem_read: addr = " FMT_WORD ", mask = %02x\n", raddr, wmask);
    #endif
    uint8_t *host_addr = guest_to_host(raddr);
    host_addr = (uint8_t*)((size_t)host_addr);
    if (host_addr == NULL) {
        // Log(FMT_RED("Invalid read: addr = " FMT_WORD ", mask = %02x\n"), raddr, wmask);
        // printf(FMT_RED("Invalid read: addr = " FMT_WORD ", mask = %02x\n"), raddr, wmask);
        // npc_abort();
        return 0;
    }
    */
    switch(wmask) {
        case 15:
            //printf("case 0xff\n");
            //printf("return value = %02x\n", host_read(host_addr, 4));
            return paddr_read(raddr, 4);
            break;
        case 12:
            if (paddr_read(raddr, 2) & (1 << 15)) {
                return paddr_read(raddr, 2) | 0xFFFF0000;
            } else {
                return paddr_read(raddr, 2) & 0x0000FFFF;
            }
            break;
        case 3:
            return paddr_read(raddr, 2);
            break;
        case 1:
            return paddr_read(raddr, 1);
            break;
        default:
            // Assert(0, "Invalid mask = %02x", wmask);
            break;
    }
    return 0;
}

extern "C" void npc_write(int waddr, int wdata, int wmask) {
    /*
    #ifdef CONFIG_SOFT_MMIO
        if (waddr == SERIAL_PORT) {
            putchar(wdata);
            difftest_skip_ref();
            return;
        }
    #endif
    */
    // printf("pmem_write: addr = %d, data = %d, mask = %d\n", waddr, wdata, wmask);
    // 总是往地址为`waddr & ~0x3u`的4字节按写掩码`wmask`写入`wdata`
    // `wmask`中每比特表示`wdata`中1个字节的掩码,
    // 如`wmask = 0x3`代表只写入最低2个字节, 内存中的其它字节保持不变
    // printf("pmem_write: addr = " FMT_WORD ", data = " FMT_WORD ", mask = %02x\n", waddr, wdata, wmask & 0xff);
    /*
    uint8_t *host_addr = guest_to_host(waddr);
    if (host_addr == NULL) {
        //Log(FMT_RED("Invalid write: addr = " FMT_WORD ", data = " FMT_WORD ", mask = %02x"),
        // waddr, wdata, wmask & 0xff);
        // npc_abort();
        return;
    }
    */
    switch (wmask) {
        case 1:
            paddr_write(waddr, 1, wdata);
            break;
        case 3:
            paddr_write(waddr & ~0x1u, 2, wdata);
            break;
        case 15:
            paddr_write(waddr, 4, wdata);
            break;
        case 12:
            paddr_write(waddr, 2, wdata);
            break;
        /*
        case 0xff:
            host_write(host_addr, 8, wdata);
            break;
        */
        /*
        case 0xff:
            host_write(host_addr, 8, wdata);
            break;
        */
        default:
            // Log(FMT_RED("Invalid write: addr = " FMT_WORD ", data = " FMT_WORD ", mask = %02x"),
                // waddr, wdata, wmask & 0xff);
            break;
    }
}



#endif