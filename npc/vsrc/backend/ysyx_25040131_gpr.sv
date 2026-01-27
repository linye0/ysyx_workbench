module ysyx_25040131_gpr(
    input rst, clk,
    
    // 读通道（EXU阶段使用）
    input [4: 0] rs1,
    input [4: 0] rs2,
    output reg [31: 0] read_rs1_data,
    output reg [31: 0] read_rs2_data,
    
    // 写通道（WBU阶段使用）
    input write_reg,       
    input [4: 0] target_reg,
    input [31: 0] write_rd_data,
    
    // 关键：识别 JALR 指令的信号（从顶层 Controller 接入）
    // 通常对应 pcImm_NEXTPC_rs1Imm == 2'b10

    // 流水线握手信号
    input prev_valid,      
    input next_ready,       
    output out_valid,       
    output out_ready        
);

    reg [31: 0] regs[31: 0];

    // 握手成功：当前级数据有效且后级允许流过
    wire wb_handshake = prev_valid && next_ready;
   // 写入使能：握手成功、指令要求写寄存器，且目标不是x0 
    wire rf_we = wb_handshake && write_reg && (target_reg != 5'h0);

    integer i;
    always @(posedge clk) begin
        if (rf_we) begin
            regs[target_reg] <= write_rd_data;
        end
    end

    // ------------------------------
    // 读通道：组合逻辑
    // ------------------------------
    always @(*) begin
        if (rs1 == 5'h0) begin
            read_rs1_data = 32'h0000_0000;
        end else begin
            read_rs1_data = regs[rs1];
        end
    end

    always @(*) begin
        if (rs2 == 5'h0) begin
            read_rs2_data = 32'h0000_0000;
        end else begin
            read_rs2_data = regs[rs2];
        end
    end

    // ------------------------------
    // 握手信号
    // ------------------------------
    assign out_valid = prev_valid;
    assign out_ready = next_ready;

endmodule