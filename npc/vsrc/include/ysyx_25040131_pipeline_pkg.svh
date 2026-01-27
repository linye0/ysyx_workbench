`ifndef YSYX_25040131_PIPELINE_PKG_SVH
`define YSYX_25040131_PIPELINE_PKG_SVH

// EX阶段控制信号
typedef struct packed {
    logic [4:0] aluc;                // ALU操作码
    logic       aluOut_WB_memOut;    // 写回数据源选择
    logic       rs1Data_EX_PC;       // ALU A口选择
    logic [1:0] rs2Data_EX_imm32_4;  // ALU B口选择
    logic       csr_use_imm;         // CSR立即数选择
} ctrl_ex_t;

// MEM阶段控制信号
typedef struct packed {
    logic [1:0] write_mem;           // 写内存使能/宽度
    logic [2:0] read_mem;            // 读内存使能/宽度
} ctrl_mem_t;

// WB阶段控制信号
typedef struct packed {
    logic       write_reg;           // 写寄存器堆使能
    logic       csr_we;              // 写CSR使能
    logic       is_mret;             // mret指令
    logic       is_ecall;            // ecall指令
    logic       is_csr;
    logic [2:0] read_mem;
    logic [1:0] pcImm_NEXTPC_rs1Imm;
} ctrl_wb_t;

typedef struct packed {
    logic [31:0] pc;          // 当前指令PC (用于跳转计算、异常记录)
    logic [31:0] inst;        // 指令内容
    // 如果有取指异常，可以在这里加 exc_valid
} if_id_data_t;

typedef struct packed {
    logic [31:0] pc;          // 传递PC
    logic [31:0] rs1_data;    // 寄存器1数据
    logic [31:0] rs2_data;    // 寄存器2数据
    logic [31:0] imm;         // 扩展后的立即数
    
    logic [4:0]  rs1_idx;     // 源寄存器1索引 (用于Forwarding检测)
    logic [4:0]  rs2_idx;     // 源寄存器2索引 (用于Forwarding检测)
    logic [4:0]  rd_idx;      // 目标寄存器索引
    
    logic [11:0] csr_addr;    // CSR地址
    
    // 异常相关
    logic        exc_valid;   // 是否发生异常
    logic [31:0] exc_cause;
    logic [31:0] exc_tval;

    // 控制信号包
    ctrl_ex_t    ctrl_ex;     // EX阶段用的控制信号
    ctrl_mem_t   ctrl_mem;    // 传给MEM用的
    ctrl_wb_t    ctrl_wb;     // 传给WB用的
} id_ex_data_t;

typedef struct packed {
    logic [31:0] pc;
    logic [31:0] alu_result;  // ALU计算结果 (也可能是访存地址)
    logic [31:0] mem_wdata;   // 存入内存的数据 (通常是 rs2_data，可能经过前递修正)
    logic [4:0]  rd_idx;      // 目标寄存器索引
    
    // CSR 写数据 (在EX阶段计算得出，如 gpr_rs)
    logic [31:0] csr_wdata;
    logic [11:0] csr_addr;
    logic [31:0] csr_rdata;

    // 异常相关 (可能会在EX阶段新增异常，如分支对齐)
    logic        exc_valid;

    logic       condition_branch;
    logic [31:0] imm;
    logic [31:0] rs1_data;
    
    // 控制信号包 (EX的已经用完了，丢弃)
    ctrl_mem_t   ctrl_mem;    // 本阶段使用
    ctrl_wb_t    ctrl_wb;     // 传给WB用的
} ex_mem_data_t;

typedef struct packed {
    logic [31:0] pc;
    logic [31:0] alu_result;  // ALU结果 (用于非Load指令写回)
    logic [31:0] mem_rdata;   // 内存读出的数据
    logic [4:0]  rd_idx;      // 目标寄存器索引
    
    // CSR 读取结果 (CSR通常在EX读，但写回可能在WB)
    logic [31:0] csr_rdata;   
    logic [31:0] csr_wdata;   // 传递给WB写CSR
    logic [11:0] csr_addr;

    logic        condition_branch;
    logic [31:0] imm;
    logic [31:0] rs1_data;

    logic        exc_valid;
    logic [31:0] exc_cause;
    logic [31:0] exc_tval;
    logic        access_fault;

    // 控制信号包 (MEM的用完了，丢弃)
    ctrl_wb_t    ctrl_wb;     // 本阶段使用
} mem_wb_data_t;

`endif