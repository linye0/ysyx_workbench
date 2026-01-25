module ysyx_25040131_alu(
    input[4: 0] aluc,
    input [31: 0] a, b,

    output reg [31: 0] out, 
    output reg condition_branch,
    
    // 流水线握手信号
    input prev_valid,      // 上游数据有效
    input next_ready,       // 下游可以接收数据
    output out_valid,       // 输出数据有效
    output out_ready        // 可以接收上游数据
);

always @(*) begin
    condition_branch = 0;
    out = 32'b0;
    case (aluc)
        5'b00000: out = a + b;
        5'b00001: out = a - b;
        5'b00010: out = a & b;
        5'b00011: out = a | b;
        5'b00100: out = a ^ b;
        5'b00101: out = a << b[4:0]; // SLL逻辑左移，只取低5位
        5'b00110: out = ($signed(a) < ($signed(b))) ? 32'b1 : 32'b0;
        5'b00111: out = (a < b) ? 32'b1 : 32'b0;
        5'b01000: out = a >> b[4:0]; // SRL逻辑右移，只取低5位
        5'b01001: out = ($signed(a)) >>> b[4:0]; // SRA算术右移，只取低5位
        5'b01010: begin 
            out = a + b;
            out[0] = 1'b0;
        end
        5'b01011: condition_branch = (a == b) ? 1'b1 : 1'b0;
        5'b01100: condition_branch = (a != b) ? 1'b1 : 1'b0;
        5'b01101: condition_branch = ($signed(a) < $signed(b)) ? 1'b1 : 1'b0;
        5'b01110: condition_branch = ($signed(a) >= $signed(b)) ? 1'b1 : 1'b0;
        5'b01111: condition_branch = (a < b) ? 1'b1: 1'b0;
        5'b10000: condition_branch = (a >= b) ? 1'b1: 1'b0;
        default: out = 32'b0;
    endcase
end

// 流水线握手：ALU是组合逻辑，直接传递valid信号
assign out_valid = prev_valid;
assign out_ready = next_ready;

endmodule
