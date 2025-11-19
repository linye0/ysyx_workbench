module ysyx_25040131_csr (
    input clk,
    input rst,

    // 读通道（EXU阶段使用）
    input [11:0] csr_addr,
    output reg [31:0] csr_rdata,
    output reg [31:0] mtvec_out,
    output reg [31:0] mepc_out,
    input idu_valid,       // IDU阶段有效（用于读操作的流水线握手）
    input mem_ready,       // MEM阶段可以接收数据
    output exu_csr_valid,  // 读操作输出有效

    // 写通道（WBU阶段使用）
    input csr_we,          // 写使能
    input [31:0] csr_wdata,
    // 流水线握手信号
    input prev_valid,      // 上游数据有效（MEM阶段有效）
    input next_ready,       // 下游可以接收数据（WBU阶段ready）
    output out_valid,       // 输出数据有效（CSR写操作完成）
    output out_ready,       // 可以接收上游数据（CSR写通道ready）

    // 异常/中断控制信号
    input exc_valid,       // 异常是否发生
    input [31:0] exc_pc,   // 异常发生时的pc
    input [31:0] exc_cause, // 异常原因
    input [31:0] exc_tval  // 异常附加信息 
);

// --- CSR 寄存器定义（仅实现需要的）---
reg [31:0] mstatus;  // 0x300
reg [31:0] mtvec;    // 0x305
reg [31:0] mepc;     // 0x341
reg [31:0] mcause;   // 0x342
reg [31:0] mtval;    // 0x343

// 复位初始值（根据 RISC-V 手册）
initial begin
    mstatus = 32'h00000000;  // MIE=0, MPIE=0, MPP=0 (PRV_U)
    mtvec   = 32'h00000000;  // Trap vector base address = 0
    mepc    = 32'h00000000;
    mcause  = 32'h00000000;
    mtval   = 32'h00000000;
end

// ------------------------------
// 写通道（WBU阶段）：状态机
// IDLE: 空闲状态
// WRITE: 执行写操作
// DONE: 写操作完成
typedef enum logic [1:0] {
    CSR_WB_IDLE = 2'b00,
    CSR_WB_WRITE = 2'b01,
    CSR_WB_DONE = 2'b10
} csr_wb_state_t;

csr_wb_state_t csr_wb_state;
reg [11:0] csr_addr_reg;
reg [31:0] csr_wdata_reg;
reg exc_valid_reg;
reg [31:0] exc_pc_reg;
reg [31:0] exc_cause_reg;
reg [31:0] exc_tval_reg;

always @(posedge clk) begin
    if (rst) begin
        mtvec   <= 32'h0;
        mepc    <= 32'h0;
        mcause  <= 32'h0;
        mtval   <= 32'h0;
        mstatus <= 32'h0;
        csr_wb_state <= CSR_WB_IDLE;
        csr_addr_reg <= 12'h0;
        csr_wdata_reg <= 32'h0;
        exc_valid_reg <= 1'b0;
        exc_pc_reg <= 32'h0;
        exc_cause_reg <= 32'h0;
        exc_tval_reg <= 32'h0;
    end else begin
        unique case (csr_wb_state)
            CSR_WB_IDLE: begin
                // 等待MEM阶段有效
                if (prev_valid && next_ready) begin
                    if (csr_we || exc_valid) begin
                        // 需要写操作，保存数据并进入WRITE状态
                        csr_addr_reg <= csr_addr;
                        csr_wdata_reg <= csr_wdata;
                        exc_valid_reg <= exc_valid;
                        exc_pc_reg <= exc_pc;
                        exc_cause_reg <= exc_cause;
                        exc_tval_reg <= exc_tval;
                        csr_wb_state <= CSR_WB_WRITE;
                    // end else begin
                        // 不需要写操作，直接进入DONE状态
                        // csr_wb_state <= CSR_WB_DONE;
                    end
                end
            end
            CSR_WB_WRITE: begin
                // 执行写操作
                if (csr_we) begin
                    case (csr_addr_reg)
                        12'h300: mstatus <= csr_wdata_reg;
                        12'h305: mtvec   <= csr_wdata_reg;
                        12'h341: mepc    <= csr_wdata_reg;
                        12'h342: mcause  <= csr_wdata_reg;
                        12'h343: mtval   <= csr_wdata_reg;
                        default: ; // 未实现 CSR 忽略
                    endcase
                end
                // 异常处理：当异常发生时，自动更新 CSR
                if (exc_valid_reg) begin
                    mepc    <= exc_pc_reg;
                    mcause  <= exc_cause_reg;
                    mtval   <= exc_tval_reg;
                end
                csr_wb_state <= CSR_WB_DONE;
            end
            CSR_WB_DONE: begin
                // 写操作完成，等待prev_valid变为0后再回到IDLE状态
                // 这样可以确保同一条指令的写操作只执行一次
                if (!prev_valid) begin
                    csr_wb_state <= CSR_WB_IDLE;
                end
            end
            default: begin
                csr_wb_state <= CSR_WB_IDLE;
            end
        endcase
    end
end

// ------------------------------
// 流水线握手信号
// 如果csr_we = 1'b0，那么out_valid = prev_valid
// 如果csr_we != 1'b0，那么out_valid = (csr_wb_state == CSR_WB_DONE)
assign out_valid = (csr_we == 1'b0) ? prev_valid && next_ready : (csr_wb_state == CSR_WB_DONE);
assign out_ready = (csr_wb_state == CSR_WB_IDLE);

// --- CSR 写操作（仅允许写合法 CSR）---
/*
always @(posedge clk) begin
    if (csr_we) begin
        case (csr_addr)
            12'h305: mtvec   <= csr_wdata;
            default: ; // 忽略非法 CSR 写（或可触发异常）
        endcase
    end
end
*/

// ------------------------------
// 读通道（EXU阶段）：组合逻辑
always @(*) begin
    mtvec_out = mtvec;
    mepc_out = mepc;
    case (csr_addr)
        12'h300: csr_rdata = mstatus;
        12'h305: csr_rdata = mtvec;
        12'h341: csr_rdata = mepc;
        12'h342: csr_rdata = mcause;
        12'h343: csr_rdata = mtval;
        default: csr_rdata = 32'h0; // 未实现 CSR 返回 0
    endcase
end

// ------------------------------
// 流水线握手：读操作是组合逻辑，立即有效
// 读操作是组合逻辑，只要idu_valid有效，读数据就立即可用
assign exu_csr_valid = idu_valid;

endmodule
