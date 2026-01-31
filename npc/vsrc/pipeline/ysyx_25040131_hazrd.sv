module ysyx_25040131_hazard (
    // ID 阶段 (当前指令)
    input [4:0] id_rs1,
    input [4:0] id_rs2,
    input       id_valid,    // 建议加上：如果 ID 是气泡，就不需要 Stall

    // EX 阶段 (上一条指令)
    input [4:0] ex_rd,
    input       ex_mem_read, // 1 = Load 指令
    input       ex_valid,

    // MEM 阶段 (上上一条指令，防 Cache Miss)
    input [4:0] mem_rd,
    input       mem_mem_read,
    input       mem_valid,

    output wire stall_if_id,
    output wire flush_id_ex
);

    // ========================================================================
    // 1. 定义冲突检测逻辑 (模仿 conflictWithStage)
    // ========================================================================
    // 逻辑：该阶段有效 && 写目标非0 && (写目标 == rs1 或 写目标 == rs2)
    
    wire conflict_ex  = ex_valid  && (ex_rd  != 0) && ((ex_rd  == id_rs1) || (ex_rd  == id_rs2));
    wire conflict_mem = mem_valid && (mem_rd != 0) && ((mem_rd == id_rs1) || (mem_rd == id_rs2));

    // ========================================================================
    // 2. 生成 Stall 信号
    // ========================================================================
    // 逻辑：发生了冲突 && 那个阶段是 Load 指令
    
    wire is_load_use = (conflict_ex  && ex_mem_read)
                       || (conflict_mem && mem_mem_read)
                       ;

    // 最终输出：只有当 ID 阶段也是有效指令时，才触发 Stall
    assign stall_if_id = id_valid && is_load_use;
    assign flush_id_ex = id_valid && is_load_use;

endmodule