module ysyx_25040131_imm(
	input [31:0] inst,
	input [2:0] imm_type,
	output [31:0] imm_out
);
	
	wire [31:0] immI;
	MuxKey #(3, 3, 32) imm_mux(imm_out, imm_type, {
		3'b001, {{20{inst[31]}}, inst[31:20]},
		3'b010, {{12{inst[31]}}, inst[31:12]},
		3'b100, {{12{inst[31]}}, inst[31], inst[19:12], inst[20], inst[30:21]}
	});

endmodule
