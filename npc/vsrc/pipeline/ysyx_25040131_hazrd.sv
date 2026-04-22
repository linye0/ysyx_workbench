module ysyx_25040131_hazard (
    // ID 阶段 (当前指令)
    input [4:0] id_rs1,
    input [4:0] id_rs2,

    // EX 阶段 (上一条指令)
    input [4:0] id_ex_out_rd,
    input       id_ex_out_mem_read, // 1 = Load 指令

    input [4:0] ex_mem_out_rd,
    input       ex_mem_out_mem_read, // 1 = Load 指令
    input       ex_mem_ready_out,

    output wire stall_if_id,
    output wire flush_id_ex
);

    // ========================================================================
    // 1. 定义冲突检测逻辑 (模仿 conflictWithStage)
    // ========================================================================
    // 逻辑：该阶段有效 && 写目标非0 && (写目标 == rs1 或 写目标 == rs2)
    
    wire conflict_id_ex  = (id_ex_out_rd  != 0) && ((id_ex_out_rd  == id_rs1) || (id_ex_out_rd  == id_rs2));
    wire conflict_id_mem = (!ex_mem_ready_out) && (ex_mem_out_rd != 0) && ((ex_mem_out_rd == id_rs1) || (ex_mem_out_rd == id_rs2));

    // 如果conflict_id_mem是1,说明此时id需要的数据还在mem当中呆着，但是如果此时ex_mem_ready_out == 1，
    // 说明此时mem实际上已经完成了读操作，已经在等待下一条指令的到来了，如果此时还是坚持flush，就会把mem需要的那条指令flush掉，这样就形成了死锁
    // mem当中的rd始终是id_rs1（因为没有新的指令，旧有的指令不会被顶掉），但是id需要的那条指令已经被flush掉了，这样就形成了死锁

    // ========================================================================
    // 2. 生成 Stall 信号
    // ========================================================================
    // 逻辑：发生了冲突 && 那个阶段是 Load 指令
    
    wire is_load_use = (conflict_id_ex  && id_ex_out_mem_read) || (conflict_id_mem  && ex_mem_out_mem_read);

    // 最终输出：只有当 ID 阶段也是有效指令时，才触发 Stall
    assign stall_if_id = is_load_use;
    assign flush_id_ex = is_load_use;

endmodule