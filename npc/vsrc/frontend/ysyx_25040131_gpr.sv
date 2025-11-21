module ysyx_25040131_gpr(
    input rst, clk,
    
    // 读通道（EXU阶段使用）
    input [4: 0] rs1,
    input [4: 0] rs2,
    output reg [31: 0] read_rs1_data,
    output reg [31: 0] read_rs2_data,
    input idu_valid,       // IDU阶段有效（用于读操作的流水线握手）
    input mem_ready,       // MEM阶段可以接收数据
    output exu_gpr_valid, // 读操作输出有效
    
    // 写通道（WBU阶段使用）
    input write_reg,       // 写使能
    input [4: 0] target_reg,
    input [31: 0] write_rd_data,
    // 流水线握手信号
    input prev_valid,      // 上游数据有效（MEM阶段有效）
    input next_ready,       // 下游可以接收数据（WBU阶段ready）
    output out_valid,       // 输出数据有效（GPR写操作完成）
    output out_ready        // 可以接收上游数据（GPR写通道ready）
);


reg [31: 0] regs[31: 0];

// ------------------------------
// 写通道（WBU阶段）：状态机
// IDLE: 空闲状态
// WRITE: 执行写操作
// DONE: 写操作完成
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
    end else begin
        unique case (gpr_wb_state)
            GPR_WB_IDLE: begin
                // 等待MEM阶段有效
                if (prev_valid && next_ready) begin
                    if (write_reg && target_reg != 5'h0) begin
                        // 需要写操作，保存数据并进入WRITE状态
                        target_reg_reg <= target_reg;
                        write_rd_data_reg <= write_rd_data;
                        gpr_wb_state <= GPR_WB_WRITE;
                    // end else begin
                        // 不需要写操作，直接进入DONE状态
                        // gpr_wb_state <= GPR_WB_DONE;
                    end else if (target_reg == 5'h0) begin
                        gpr_wb_state <= GPR_WB_DONE;
                    end
                end
            end
            GPR_WB_WRITE: begin
                // 执行写操作
                regs[target_reg_reg] <= write_rd_data_reg;
                gpr_wb_state <= GPR_WB_DONE;
            end
            GPR_WB_DONE: begin
                // 写操作完成，等待prev_valid变为0后再回到IDLE状态
                // 这样可以确保同一条指令的写操作只执行一次
                // if (!prev_valid) begin
                    gpr_wb_state <= GPR_WB_IDLE;
                // end
            end
            default: begin
                gpr_wb_state <= GPR_WB_IDLE;
            end
        endcase
    end
end

// ------------------------------
// 流水线握手信号
// 如果write_reg = 1'b0，那么out_valid = prev_valid
// 如果write_reg != 1'b0，那么out_valid = (gpr_wb_state == GPR_WB_DONE)
assign out_valid = (write_reg == 1'b0) ? prev_valid && next_ready : (gpr_wb_state == GPR_WB_DONE);
assign out_ready = (gpr_wb_state == GPR_WB_IDLE);

// ------------------------------
// 读通道（EXU阶段）：组合逻辑
always @(*) begin
    if(rs1 == 5'h0)begin
        read_rs1_data = 32'h0000_0000;
    end else begin
        read_rs1_data = regs[rs1];
    end
end

always @(*) begin
    if(rs2 == 5'h0)begin
        read_rs2_data = 32'h0000_0000;
    end else begin
        read_rs2_data = regs[rs2];
    end
end

// ------------------------------
// 流水线握手：读操作是组合逻辑，立即有效
// 读操作是组合逻辑，只要idu_valid有效，读数据就立即可用
assign exu_gpr_valid = idu_valid;

endmodule
