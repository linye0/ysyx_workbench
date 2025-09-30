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
        $display("[$display][TIME %t] Branch SELECTED: pcImm. PC=%h + OFFSET=%h -> NEXT_PC=%h", $time, pc, offset, next_pc);
    end
    else if(pcImm_NEXTPC_rs1Imm == 2'b10) begin
        next_pc = rs1Data + offset;
        $display("[$display][TIME %t] Branch SELECTED: rs1Imm. RS1=%h + OFFSET=%h -> NEXT_PC=%h", $time, rs1Data, offset, next_pc);
    end
    else if(condition_branch) begin
        next_pc = pc + offset;
        $display("[$display][TIME %t] Branch SELECTED: Conditional Branch (condition_branch=1). PC=%h + OFFSET=%h -> NEXT_PC=%h", $time, pc, offset, next_pc);
    end
    else if(pc == 32'h94) begin
        next_pc = 32'h94;
        $display("[$display][TIME %t] Branch SELECTED: HALT at PC=%h.", $time, pc);
    end
    else begin
        next_pc = pc + 4;
        $display("[$display][TIME %t] Branch SELECTED: Default (PC+4). PC=%h -> NEXT_PC=%h", $time, pc, next_pc);
    end
end

endmodule
