module ysyx_25040131_csr (
    input clk,
    input rst,

    // 读通道（EXU阶段使用）
    input [11:0] csr_addr,
    output logic [31:0] csr_rdata,
    output logic [31:0] mtvec_out,
    output logic [31:0] mepc_out,
    input idu_valid,       // IDU阶段有效（用于读操作的流水线握手）
    input mem_ready,       // MEM阶段可以接收数据
    output exu_csr_valid,  // 读操作输出有效

    // 写通道（WBU阶段使用）
    input [11:0] csr_waddr,       // 【新增】WBU阶段的写地址
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
    input [31:0] exc_tval, // 异常附加信息 
    input is_ecall,
    input is_mret
);

// --- CSR 寄存器定义（仅实现需要的）---
reg [31:0] mstatus;  // 0x300
reg [31:0] mtvec;    // 0x305
reg [31:0] mepc;     // 0x341
reg [31:0] mcause;   // 0x342
reg [31:0] mtval;    // 0x343
reg [31:0] mscratch; // 【新增】

// --- 只读 CSR 寄存器（Machine Information Registers）---
wire [31:0] mvendorid/*verilator public_flat*/;  // 0xF11 - Vendor ID (只读)
wire [31:0] marchid/*verilator public_flat*/;    // 0xF12 - Architecture ID (只读)

// 设置 mvendorid 为 ysyx 的 ASCII 码
assign mvendorid = 32'h79737978;  // 'y'=0x79, 's'=0x73, 'y'=0x79, 'x'=0x78

// 设置 marchid 为学号数字部分的十进制表示
assign marchid = 32'd25040131;  // 学号 ysyx_25040131 的数字部分

wire wb_handshake = prev_valid && next_ready;


always_ff @(posedge clk) begin
    if (rst) begin
        mstatus <= 32'h1800; // 默认 MPP=11 (Machine Mode)
        mtvec   <= 32'h0;
        mepc    <= 32'h0;
        mcause  <= 32'h0;
        mtval   <= 32'h0;
    end else if (wb_handshake) begin
        // 1. 异常处理优先级最高 (Trap Entry)
        if (exc_valid || is_ecall) begin
            mepc   <= exc_pc;
            mtval  <= exc_tval;
            mcause <= is_ecall ? 32'd11 : exc_cause;
            
            // 更新 mstatus
            mstatus[7] <= mstatus[3]; // MPIE = MIE
            mstatus[3] <= 1'b0;       // MIE = 0 (关中断)
            mstatus[12:11] <= 2'b11;  // MPP = 11 (M模式)
        end 
        // 2. mret 恢复逻辑 (Trap Exit)
        else if (is_mret) begin
            mstatus[3] <= mstatus[7]; // MIE = MPIE
            mstatus[7] <= 1'b1;       // MPIE = 1
        end
        // 3. 普通 CSR 指令写入
        else if (csr_we) begin
            case (csr_waddr)
                12'h300: mstatus <= csr_wdata;
                12'h305: mtvec   <= csr_wdata;
                12'h341: mepc    <= csr_wdata;
                12'h340: mscratch <= csr_wdata; // 【新增】
                12'h342: mcause  <= csr_wdata;
                12'h343: mtval   <= csr_wdata;
                default: ; 
            endcase
        end
    end
end

always_comb begin
    // 默认输出
    mtvec_out = mtvec;
    mepc_out  = mepc;
    
    case (csr_addr)
        12'h300: csr_rdata = mstatus;
        12'h305: csr_rdata = mtvec;
        12'h341: csr_rdata = mepc;
        12'h342: csr_rdata = mcause;
        12'h340: csr_rdata = mscratch; // 【新增】
        12'h343: csr_rdata = mtval;
        12'hF11: csr_rdata = mvendorid;
        12'hF12: csr_rdata = marchid;
        default: csr_rdata = 32'h0;
    endcase
end


    // CSR 模块作为 WBU 级的逻辑，不产生反压
    assign out_ready = next_ready;
    // 只要指令到了，结果就有效
    assign out_valid = prev_valid;

    // 读操作在 ID/EX 级完成，idu_valid 有效即代表读出数据有效
    assign exu_csr_valid = idu_valid;

endmodule
