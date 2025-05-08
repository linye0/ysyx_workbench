module ysyx_25040131_pc(
	input clk,
	input rst,
	input [31:0] next_pc,
	output[31:0] pc
);

	Reg #(32, 32'h80000000) i0 (clk, rst, next_pc, pc, 1'b1);

	always @(posedge clk) begin
		$display("assign pc: %x to next_pc: %x\n", pc, next_pc);
	end

endmodule
