module ysyx_25040131_gpr(
    input rst, clk,
    
    // 读通道（EXU阶段使用）
    input [4: 0] rs1,
    input [4: 0] rs2,
    output reg [31: 0] read_rs1_data,
    output reg [31: 0] read_rs2_data,
    input idu_valid,       
    input mem_ready,       
    output exu_gpr_valid, 
    
    // 写通道（WBU阶段使用）
    input write_reg,       
    input [4: 0] target_reg,
    input [31: 0] write_rd_data,
    
    // 关键：识别 JALR 指令的信号（从顶层 Controller 接入）
    // 通常对应 pcImm_NEXTPC_rs1Imm == 2'b10
    input is_jalr,

    // 流水线握手信号
    input prev_valid,      
    input next_ready,       
    output out_valid,       
    output out_ready        
);

    reg [31: 0] regs[31: 0];

    // ------------------------------
    // 影子寄存器：用于暂存 JALR 的原始基地址
    // ------------------------------
    reg [31: 0] rs1_old_value_reg;
    reg         is_jalr_active_reg; // 记录当前流水线中是否有正在处理的 JALR

    typedef enum logic [1:0] {
        GPR_WB_IDLE = 2'b00,
        GPR_WB_WRITE = 2'b01,
        GPR_WB_DONE = 2'b10
    } gpr_wb_state_t;

    gpr_wb_state_t gpr_wb_state;
    reg [4: 0] target_reg_reg;
    reg [31: 0] write_rd_data_reg;

    always @(posedge clk) begin
        if (rst) begin
            gpr_wb_state <= GPR_WB_IDLE;
            target_reg_reg <= 5'h0;
            write_rd_data_reg <= 32'h0;
            rs1_old_value_reg <= 32'h0;
            is_jalr_active_reg <= 1'b0;
        end else begin
            unique case (gpr_wb_state)
                GPR_WB_IDLE: begin
                    if (prev_valid && next_ready) begin
                        // 在进入写阶段前，如果发现是 JALR，锁存当前的 rs1 原始值
                        if (is_jalr) begin
                            rs1_old_value_reg <= (rs1 == 5'h0) ? 32'h0 : regs[rs1];
                            is_jalr_active_reg <= 1'b1;
                        end else begin
                            is_jalr_active_reg <= 1'b0;
                        end

                        if (write_reg && target_reg != 5'h0) begin
                            target_reg_reg <= target_reg;
                            write_rd_data_reg <= write_rd_data;
                            gpr_wb_state <= GPR_WB_WRITE;
                        end else if (target_reg == 5'h0) begin
                            gpr_wb_state <= GPR_WB_DONE;
                        end
                    end
                end
                GPR_WB_WRITE: begin
                    regs[target_reg_reg] <= write_rd_data_reg;
                    gpr_wb_state <= GPR_WB_DONE;
                end
                GPR_WB_DONE: begin
                    // 状态完成后清除 JALR 标记
                    is_jalr_active_reg <= 1'b0;
                    gpr_wb_state <= GPR_WB_IDLE;
                end
                default: gpr_wb_state <= GPR_WB_IDLE;
            endcase
        end
    end

    // ------------------------------
    // 读通道：组合逻辑
    // ------------------------------
    always @(*) begin
        if (rs1 == 5'h0) begin
            read_rs1_data = 32'h0000_0000;
        end else if (is_jalr_active_reg && (rs1 == target_reg_reg)) begin
            // 核心逻辑：如果是正在执行写回的 JALR 指令且读写地址重合，
            // 强制输出锁存的“旧”基地址，而不是寄存器堆中可能已被改写的“新”PC+4
            read_rs1_data = rs1_old_value_reg;
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
    assign out_valid = (write_reg == 1'b0) ? prev_valid && next_ready : (gpr_wb_state == GPR_WB_DONE);
    assign out_ready = (gpr_wb_state == GPR_WB_IDLE);
    assign exu_gpr_valid = idu_valid;

endmodule