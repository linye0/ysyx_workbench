module ysyx_25040131_cpu(
	input [31:0] inst,
	input clk,
	input rst,
	output [31:0] pc
);

	wire [6:0] op;
	wire [2:0] f3;
	wire [7:0] f7;
	wire [4:0] rs1;
	wire [4:0] rs2;
	wire [4:0] rd;
	wire [24:0] imm;
	wire [31:0] rd1;
	wire [31:0] rd2;
	wire [31:0] alu_result;
	wire [31:0] alu_input1;
	wire [31:0] alu_input2;
	wire [2:0] alu_control;
	wire [2:0] imm_type;
	wire reg_write;
	wire rd2;
	wire of;
	wire zf;
	wire nf;
	wire cf;

	ysyx_25040131_pc pc_counter(
		.clk(clk),
		.rst(rst),
		.pc(pc)
	);

	ysyx_25040131_gpr gpr(
		.clk(clk),
		.we3(reg_write),
		.rs1(inst[19:15]),
		.rs2(inst[24:20]),
		.rd(inst[11:7]),
		.wd3(alu_result),
		.rd1(alu_input1),
		.rd2(rd2)
	);

	ysyx_25040131_idu idu(
		.opcode(inst[6:0]),
		.f3(inst[14:12]),
		.f7(inst[31:25]),
		.alu_control(alu_control),
		.imm_type(imm_type),
		.reg_write(reg_write)
	);

	ysyx_25040131_imm imm_decoder(
		.inst(inst),
		.imm_type(imm_type),
		.imm_out(alu_input2)
	);

	ysyx_25040131_alu alu(
		.a(alu_input1),
		.b(alu_input2),
		.alu_control(alu_control),
		.result(alu_result),
		.of(of),
		.zf(zf),
		.nf(nf),
		.cf(cf)
	);

endmodule
