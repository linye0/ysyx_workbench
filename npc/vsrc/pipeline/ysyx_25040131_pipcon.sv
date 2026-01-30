module ysyx_25040131_pipcon #(
    parameter WIDTH = 32
)(
    input  wire             clk,
    input  wire             reset,
    input  wire             flush,     // 流水线冲刷信号 (例如分支预测失败时置1)

    // 上一级 (Previous Stage)
    input  wire [WIDTH-1:0] data_in,   // 来自上一级的数据包
    input  wire             valid_in,  // 上一级数据有效
    output wire             ready_out, // 本级准备好接收 (发给上一级)

    // 下一级 (Next Stage)
    output reg  [WIDTH-1:0] data_out,  // 发送给下一级的数据包
    output reg              valid_out, // 本级数据有效 (发给下一级)
    input  wire             ready_in   // 下一级准备好接收
);

    assign ready_out = ready_in || !valid_out;

    always @(posedge clk) begin
        if (reset || flush) begin
            valid_out <= 1'b0;
            data_out <= {WIDTH{1'b0}};
        end
        else if (ready_out) begin
            valid_out <= valid_in;
            if (valid_in) begin
                data_out <= data_in;
            end
        end
    end

endmodule