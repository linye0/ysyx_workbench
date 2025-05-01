module ysyx_25040131_alu(
	input [31:0] a,
	input [31:0] b,
	input [2:0] alu_control,
	output [31:0] result,
	output of,
	output zf,
	output nf,
	output cf
);

	wire [31:0] raddsub;
	wire [31:0] r_and;
	wire [31:0] ror;
	wire [31:0] b2;

	assign b2 = b ^ {32{alu_control[0]}};
	assign {cf, raddsub} = a + b2 + {32{alu_control[0]}};
	assign of = (~(a[31]^b[31]))&(a[31]^raddsub[31]);
	assign r_and = a^b;
	assign ror = a|b;
	MuxKey #(4,3,32) alumux(result, alu_control, {
		3'b000, raddsub,
		3'b001, raddsub,
		3'b010, r_and,
		3'b011, ror
	});
	assign zf = ~(|result);
	assign nf = result[31];

endmodule
