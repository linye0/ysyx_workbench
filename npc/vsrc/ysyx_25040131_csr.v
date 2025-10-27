module ysyx_25040131_csr (
    input clk,
    input rst,

    // 读写接口
    input csr_we,
    input [11:0] csr_addr,
    input [31:0] csr_wdata,
    output reg [31:0] csr_rdata,

    // 异常/中断控制信号
    input exc_valid, // 异常是否发生
    input [31:0] exc_pc, // 异常发生时的pc
    input [31:0] exc_cause, // 异常原因
    input [31:0] exc_tval, // 异常附加信息 

    output reg [31:0] mtvec_out,
    output reg [31:0] mepc_out
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

// --- 异常处理：当异常发生时，自动更新 CSR ---
always @(posedge clk or posedge rst) begin
    if (rst) begin
        mtvec   <= 32'h0;
        mepc    <= 32'h0;
        mcause  <= 32'h0;
        mtval   <= 32'h0;
    end else if (csr_we) begin
        case (csr_addr)
            12'h305: mtvec   <= csr_wdata;
            default: ;
        endcase
    end else if (exc_valid) begin
        mepc    <= exc_pc;
        mcause  <= exc_cause;
        mtval   <= exc_tval;
    end
end

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

// --- CSR 读操作（组合逻辑）---
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
endmodule
