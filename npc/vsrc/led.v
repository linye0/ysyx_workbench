module led(
	input clk,
	input[15:0] sw,
	output[15:0] ledr
);
	assign ledr = sw;
endmodule
