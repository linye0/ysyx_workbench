module ysyx_25040131_comparator_7bit (
    input [6:0] a,      // 输入 A (7 位)
    input [6:0] b,      // 输入 B (7 位)
    output reg equal    // 相等输出信号 (1 = 相等, 0 = 不等)
);

// 组合逻辑：当 a 和 b 相等时输出 1，否则输出 0
always @(*) begin
    if (a == b)
        equal = 1'b1;   // 相等时输出高电平
    else
        equal = 1'b0;   // 不等时输出低电平
end

endmodule

