module ysyx_25040131_imm(
	input [31:0] inst,
	input [2:0] imm_type,
	output [31:0] imm_out
);
	
	wire [31:0] immI;
	assign immI = {{20{inst[31]}}, inst[31:20]};
	assign imm_out = immI;

endmodule
