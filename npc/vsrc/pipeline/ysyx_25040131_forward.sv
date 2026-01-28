module ysyx_25040131_forward(
    // ID/EX阶段的源寄存器索引
    input [4:0] id_ex_rs1_idx,
    input [4:0] id_ex_rs2_idx,

    // MEM阶段的信息
    input [4:0] ex_mem_rd_idx,
    input ex_mem_reg_write,
    input ex_mem_valid,

    // WB阶段的信息
    input [4:0] mem_wb_rd_idx,
    input mem_wb_reg_write,
    input mem_wb_valid,

    // 给ALU输入端的信号
    // 00：原装数据
    // 01: 使用WB阶段的数据
    // 10: 使用MEM阶段的数据
    // 11: 使用ID/EX阶段的数据
    output reg [1:0] forward_a_sel,
    output reg [1:0] forward_b_sel
);

always @(*) begin
    forward_a_sel = 2'b00;
    if (ex_mem_valid && ex_mem_reg_write && (ex_mem_rd_idx != 0) && (ex_mem_rd_idx == id_ex_rs1_idx)) begin
        forward_a_sel = 2'b10;
    end
    else if (mem_wb_valid && mem_wb_reg_write && (mem_wb_rd_idx != 0) && (mem_wb_rd_idx == id_ex_rs1_idx)) begin
        forward_a_sel = 2'b01;
    end

    forward_b_sel = 2'b00;
    if (ex_mem_valid && ex_mem_reg_write && (ex_mem_rd_idx != 0) && (ex_mem_rd_idx == id_ex_rs2_idx)) begin
        forward_b_sel = 2'b10;
    end
    else if (mem_wb_valid && mem_wb_reg_write && (mem_wb_rd_idx != 0) && (mem_wb_rd_idx == id_ex_rs2_idx)) begin
        forward_b_sel = 2'b01;
    end
end

endmodule