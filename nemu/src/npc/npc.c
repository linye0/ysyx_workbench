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
#include <inttypes.h> // 必须包含，用于 PRIu64 宏
#include <time.h>      // 必须包含
#ifdef CONFIG_SYS_SOC
#ifdef CONFIG_NVBOARD
#include <nvboard.h>
#endif
#endif


#ifdef CONFIG_NPC
#ifdef CONFIG_SYS_SOC
#ifdef CONFIG_NVBOARD
void nvboard_bind_all_pins(TOP_NAME* top);
#endif
#endif

PerfMetrics perf = {};
uint32_t g_wb_cpc = 0;
uint32_t g_wb_npc = 0;
bool     g_wb_valid = false;


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

    #ifdef CONFIG_SYS_SOC
    #ifdef CONFIG_NVBOARD
    nvboard_bind_all_pins(top);
    nvboard_init();
    #endif
    #endif

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
    cpu.cpc = *(npc.cpc);
    cpu.pc = *(npc.pc);
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
    cpu.cpc_for_pipeline = g_wb_cpc;
    cpu.npc_for_pipeline = g_wb_npc;
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
  npc->difftest_signal = &(top->rootp->ysyx_25040131__DOT__difftest_signal);
  npc->inst = (uint32_t *)&(top->rootp->ysyx_25040131__DOT__out_inst);
  npc->gpr = (uint32_t *)&(top->rootp->ysyx_25040131__DOT__REG_FILE__DOT__regs);
  npc->cpc = (uint32_t *)&(top->rootp->ysyx_25040131__DOT__pc);
  npc->pc = (uint32_t *)&(top->rootp->ysyx_25040131__DOT__next_pc);
  npc->mtvec = (uint32_t*)&(top->rootp->ysyx_25040131__DOT__u_csr__DOT__mtvec);
  npc->mstatus = (uint32_t*)&(top->rootp->ysyx_25040131__DOT__u_csr__DOT__mstatus);
  npc->mepc = (uint32_t*)&(top->rootp->ysyx_25040131__DOT__u_csr__DOT__mepc);
  npc->mcause = (uint32_t*)&(top->rootp->ysyx_25040131__DOT__u_csr__DOT__mcause);
  npc->mtval = (uint32_t*)&(top->rootp->ysyx_25040131__DOT__u_csr__DOT__mtval);
  npc->mvendorid = (uint32_t*)&(top->rootp->ysyx_25040131__DOT__u_csr__DOT__mvendorid);
  npc->marchid = (uint32_t*)&(top->rootp->ysyx_25040131__DOT__u_csr__DOT__marchid);
  #else
  #ifdef CONFIG_SYS_SOC
  npc->difftest_signal = &(CONCAT_YSYXSOC_HEAD(difftest_signal));
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
    //printf("npc_difftest_skip_ref\n");
    difftest_skip_ref();
}

extern "C" void npc_difftest_mem_diff(int waddr, int wdata, int wstrb) {
    // TO DO
    
}

extern "C" void npc_difftest_commit_inst(int cpc, int npc, int valid) {
    g_wb_cpc = cpc;
    g_wb_npc = npc;
    g_wb_valid = (valid != 0);
    // printf("g_wb_cpc: 0x%x, g_wb_npc: 0x%x, g_wb_valid: %d\n", g_wb_cpc, g_wb_npc, g_wb_valid);
    return;
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
    /*
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
    */
    return paddr_read(raddr & ~0x3u, 4);
}

extern "C" void npc_write(int waddr, int wdata, int wmask) {
    // 1. 如果掩码为0，表示没有写入操作，直接返回
    if (wmask == 0) return;

    int len = 0;
    // 2. 根据 wmask 确定写入长度 (len)
    // 这里采用简单判断，适配 SB, SH, SW 指令
    switch (wmask) {
        case 0b0001: case 0b0010: case 0b0100: case 0b1000: 
            len = 1; break;
        case 0b0011: case 0b1100: 
            len = 2; break;
        case 0b1111: 
            len = 4; break;
        default:
            // 处理可能的非标准掩码（可选）
            // 如果是 ysyxSoC 的 AXI 可能会有更复杂的掩码，这里计算 1 的个数
            len = 0;
            for (int i = 0; i < 4; i++) {
                if ((wmask >> i) & 1) len++;
            }
            break;
    }

    // 3. 计算偏移并还原数据
    // Verilog 中：wdata = data << (addr[1:0] * 8)
    // C++ 中还原：data = wdata >> (addr[1:0] * 8)
    int offset = waddr & 0x3;
    uint32_t actual_data = ((uint32_t)wdata) >> (offset * 8);

    // 4. 调用仿真环境接口写入物理内存
    // waddr 是不对齐的原始地址（如 0x800008f1）
    paddr_write(waddr, len, actual_data);

    // 调试打印（可选）
    // printf("NPC Write: addr=0x%08x, len=%d, raw_data=0x%08x, aligned_wdata=0x%08x, wmask=0x%x\n", 
    //        waddr, len, actual_data, wdata, wmask);
    return ;
}

extern "C" void npc_ifu_fetch_count() {
    perf.ifu_fetch_count++;
}

extern "C" void npc_lsu_read_count() {
    perf.lsu_read_count++;
}

extern "C" void npc_lsu_write_count() {
    perf.lsu_write_count++;
}

extern "C" void npc_ifu_inst(int inst) {
    uint32_t opcode = inst & 0x7F; // 提取 Opcode
    uint32_t funct3 = (inst >> 12) & 0x7;

    switch (opcode) {
        // 1. 访存指令 (Memory)
        case 0x03: // Load
        case 0x23: // Store
            perf.cur_inst_type = MEM_INST;
            break;

        // 2. 计算指令 (Calculation)
        case 0x33: // OP (R-type)
        case 0x13: // OP-IMM (I-type)
        case 0x37: // LUI
        case 0x17: // AUIPC
            perf.cur_inst_type = CAL_INST;
            break;

        // 3. 控制流指令 (Control Flow)
        case 0x63: // Branch (B-type)
        case 0x6F: // JAL (J-type)
        case 0x67: // JALR
            perf.cur_inst_type = CTRL_INST;
            break;

        // 4. 系统指令 (System)
        case 0x73: 
            perf.cur_inst_type = SYS_INST;
            break;

        // 5. 其他指令 (Others)
        default:
            perf.cur_inst_type = OTHER_INST;
            break;
    }

    perf.inst_count[perf.cur_inst_type]++;
}

extern "C" void npc_cycle_record() {
    if (perf.prev_cycle != 0)perf.inst_cycle[perf.cur_inst_type] += perf.total_cycle - perf.prev_cycle;
    perf.prev_cycle = perf.total_cycle;
}

extern "C" void npc_icache_hit() {
    perf.icache_hit_count++;
}

extern "C" void npc_icache_miss(int flag) {
    static uint64_t cur_cycle;
    if (flag == 0) {
        perf.icache_miss_count++;
        cur_cycle = perf.total_cycle;
        return;
    }
    if (flag == 1) {
        perf.icache_miss_cycle += perf.total_cycle - cur_cycle;
        return;
    }
}

// 修改后的百分比宏，确保使用 double 计算
#define PCT(count) ((perf.total_inst > 0) ? (double)(count) * 100.0 / (double)perf.total_inst : 0.0)
#define BLUE_START "\033[1;34m"
#define COLOR_END  "\033[0m"

void print_performance_metrics() {
    // 1. 确定输出流
    FILE *out = stdout;
    int is_file = 0;

    // --- 1. 获取并格式化当前时间 ---
    time_t rawtime;
    struct tm *timeinfo;
    char time_buffer[64];

    time(&rawtime);                         // 获取原始时间戳
    timeinfo = localtime(&rawtime);         // 转换为本地时间结构体
    // 格式化为: 2024-05-20 14:30:05
    strftime(time_buffer, sizeof(time_buffer), "%Y-%m-%d %H:%M:%S", timeinfo);

    #define STRIFY(x) #x
    #define TOSTRING(x) STRIFY(x)
#ifdef CONFIG_RECORD_PERF
    // 自动拼接路径：NPC_HOME_PATH 是 Makefile 传进来的 "/home/.../npc"
    // 拼接后变为 "/home/.../npc/perf_record.log"
    const char *log_path = TOSTRING(NPC_HOME_PATH) "/perf_record.log";

    out = fopen(log_path, "a");
    if (out == NULL) {
        // 如果打开失败，打印错误原因并退回到标准输出
        perror("Failed to open perf_record.log at " TOSTRING(NPC_HOME_PATH));
        out = stdout;
    } else {
        is_file = 1;
    }
#endif

    // 如果输出到控制台，打印颜色；如果输出到文件，跳过颜色代码（防止日志出现乱码）
    if (!is_file) fprintf(out, "%s", BLUE_START);

    fprintf(out, "\n======================= Performance Analysis =======================\n");
    fprintf(out, "Record Time         : %s\n", time_buffer); // 在这里打印时间
    fprintf(out, "--------------------------------------------------------------------\n");
    
    // 2. 效率概览 - 将 printf 改为 fprintf(out, ...)
    fprintf(out, "%-20s: %-12" PRIu64 " | %-20s: %-12" PRIu64 "\n", 
           "Total Cycles", perf.total_cycle, 
           "Total Instructions", perf.total_inst);

    double ipc = (perf.total_cycle > 0) ? (double)perf.total_inst / perf.total_cycle : 0.0;
    double cpi = (perf.total_inst > 0) ? (double)perf.total_cycle / perf.total_inst : 0.0;

    fprintf(out, "%-20s: %-12.4f | %-20s: %-12.4f\n", 
           "IPC (Higher, better)", ipc, 
           "CPI (Lower, better)",  cpi);

    fprintf(out, "----------------------- Instruction Distribution -------------------\n");
    
    // 3. 局部定义的宏也需要改为 fprintf(out, ...)
    #define FPRINT_INST_LINE(stream, name, type) \
        fprintf(stream, "%-20s: %-12" PRIu64 " (%6.2f%%) , CPI: %-12.4f\n", \
               name, perf.inst_count[type], PCT(perf.inst_count[type]), \
               (perf.inst_count[type] > 0) ? (double)perf.inst_cycle[type] / perf.inst_count[type] : 0.0)

    FPRINT_INST_LINE(out, "Calculation",  CAL_INST);
    FPRINT_INST_LINE(out, "Memory",       MEM_INST);
    FPRINT_INST_LINE(out, "Control Flow", CTRL_INST);
    FPRINT_INST_LINE(out, "System",       SYS_INST);

    if (perf.inst_count[OTHER_INST] > 0) {
        FPRINT_INST_LINE(out, "Others", OTHER_INST);
    }

    fprintf(out, "----------------------- Bus Activity -------------------------------\n");
    
    fprintf(out, "%-20s: %-12" PRIu64 " | %-20s: %-12" PRIu64 "\n", 
           "IFU Fetch", perf.ifu_fetch_count, 
           "LSU Read",  perf.lsu_read_count);

    double mem_ratio = (perf.inst_count[MEM_INST] > 0) ? (double)perf.total_inst / perf.inst_count[MEM_INST] : 0.0;

    fprintf(out, "%-20s: %-12" PRIu64 " | %-20s: %-12.2f\n", 
           "LSU Write", perf.lsu_write_count, 
           "Inst/Mem Ratio", mem_ratio);

    fprintf(out, "----------------------- ICache Activity ----------------------------\n");

    fprintf(out, "%-20s: %-12" PRIu64 " | %-20s: %-12" PRIu64 "\n", 
           "ICache Hit", perf.icache_hit_count, 
           "ICache Miss", perf.icache_miss_count);

    double perf_miss_ratio = (double)perf.icache_miss_count / (perf.icache_hit_count + perf.icache_miss_count);
    double perf_miss_average_cycle = (double)perf.icache_miss_cycle / perf.icache_miss_count;

    fprintf(out, "%-20s: %-12" PRIu64 " | %-20s: %-12.2f\n",
            "ICache Miss Cycle", perf.icache_miss_cycle,
            "Miss Cycle Average", perf_miss_average_cycle);

    fprintf(out, "%-20s: %-12.2f | %-20s: %-12.2f\n", 
           "ICache Miss Ratio", perf_miss_ratio, 
           "AMAT", 1 + perf_miss_ratio * perf_miss_average_cycle);

    fprintf(out, "====================================================================\n");

    if (!is_file) fprintf(out, "%s", COLOR_END);

    // 4. 如果是文件，记得关闭并刷盘
#ifdef CONFIG_RECORD_PERF
    if (is_file) {
        fflush(out);
        fclose(out);
        // 打印提示，告诉用户文件存到哪了
        printf("Performance metrics fixed recorded to: %s\n", log_path);
    }
#endif
}
#endif