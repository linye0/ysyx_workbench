module ysyx_25040131_imm(
    input [31: 0] instr,
    input [2: 0] extOP,

    output reg [31: 0] imm_32,
    
    // 流水线握手信号
    input prev_valid,      // 上游数据有效
    input next_ready,       // 下游可以接收数据
    output out_valid,       // 输出数据有效
    output out_ready        // 可以接收上游数据
);

always @(*) begin
    case (extOP)
        3'b000:begin
            imm_32 = {{20{instr[31]}}, instr[31:20]};
        end
        3'b001:begin
            imm_32 = {instr[31:12], 12'b0};
        end
        3'b010:begin
            imm_32 = {{20{instr[31]}}, instr[31:25], instr[11:7]};
        end
        3'b011:begin
            imm_32 = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
        end
        3'b100:begin
            imm_32 = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
        end
        3'b101:begin
            imm_32 = {{20{instr[31]}}, instr[31:20]};
            imm_32[10] = 0;
        end
        3'b111:begin
            imm_32 = 32'b0;
        end 
        default:begin
            
        end 
    endcase
end

// 流水线握手：IMM是组合逻辑，直接传递valid信号
assign out_valid = prev_valid && next_ready;
assign out_ready = next_ready;

endmodule;
