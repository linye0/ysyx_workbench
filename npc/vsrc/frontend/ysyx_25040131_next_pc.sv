module ysyx_25040131_next_pc(
    // 输入只保留异常相关的
    input is_mret, 
    input exc_valid, 
    input access_fault,
    input [31: 0] mepc, 
    input [31: 0] mtvec,
    
    // 删除了 pc, offset, rs1Data, pcImm... 等分支相关信号
    // 甚至 pc 都不一定需要，除非某种异常跳转依赖当前 PC
    
    output reg [31: 0] trap_target_pc, // 改个名，叫异常目标地址
    output reg trap_taken              // 新增：告诉外部“我要跳转”
);

always @(*) begin
    trap_taken = 1'b0;
    trap_target_pc = 32'b0;

    // Access Fault 优先级最高
    if (access_fault) begin
        trap_target_pc = 32'h0; // 或其他处理
        trap_taken = 1'b1;
    end
    else if (is_mret) begin
        trap_target_pc = mepc;
        trap_taken = 1'b1;
    end
    else if (exc_valid) begin
        trap_target_pc = mtvec;
        trap_taken = 1'b1;
    end
    // 删除了 Branch/JAL/JALR/PC+4 的逻辑
end

endmodule