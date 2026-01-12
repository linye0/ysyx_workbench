`ifndef YSYX_25040131_DPI_C_SVH
`define YSYX_25040131_DPI_C_SVH

`define YSYX_DPI_C_NPC_EXU_EBREAK npc_exu_ebreak();
`define YSYX_DPI_C_NPC_DIFFTEST_SKIP_REF npc_difftest_skip_ref();
`define YSYX_DPI_C_NPC_DIFFTEST_MEM_DIFF(waddr, wdata, wstrb) \
    npc_difftest_mem_diff(waddr, wdata, wstrb);
`define YSYX_DPI_C_NPC_READ(raddr, wmask) npc_read(raddr, wmask)
`define YSYX_DPI_C_NPC_WRITE(waddr, wdata, wmask) npc_write(waddr, wdata, wmask)

`define YSYX_DPI_C_IFU_FETCH_COUNT npc_ifu_fetch_count()
`define YSYX_DPI_C_LSU_READ_COUNT npc_lsu_read_count()
`define YSYX_DPI_C_LSU_WRITE_COUNT npc_lsu_write_count()
`define YSYX_DPI_C_IFU_INST(inst) npc_ifu_inst(inst)
`define YSYX_DPI_C_CYCLE_RECORD npc_cycle_record()

`define YSYX_ASSERT(cond, msg) `ASSERT(cond, msg)

`endif 