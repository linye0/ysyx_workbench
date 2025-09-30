module ysyx_25040131_next_pc(
    input [1: 0] pcImm_NEXTPC_rs1Imm,
    input condition_branch,
    input [31: 0] pc, offset, rs1Data,
    output reg [31: 0] next_pc
);

/*
always @(*) begin
    if(pcImm_NEXTPC_rs1Imm == 2'b01) next_pc = pc + offset;
    else if(pcImm_NEXTPC_rs1Imm == 2'b10) next_pc = rs1Data + offset;
    else if(condition_branch) next_pc = pc + offset;
    else if(pc == 32'h94) next_pc = 32'h94;
    else next_pc = pc + 4;
end
*/

always @(*) begin
    if(pcImm_NEXTPC_rs1Imm == 2'b01) begin
        next_pc = pc + offset;
    end
    else if(pcImm_NEXTPC_rs1Imm == 2'b10) begin
        next_pc = rs1Data + offset;
    end
    else if(condition_branch) begin
        next_pc = pc + offset;
    end
    else if(pc == 32'h94) begin
        next_pc = 32'h94;
    end
    else begin
        next_pc = pc + 4;
    end
end

endmodule
