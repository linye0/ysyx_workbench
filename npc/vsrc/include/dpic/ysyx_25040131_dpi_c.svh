`ifndef YSYX_25040131_DPI_C_SVH
`define YSYX_25040131_DPI_C_SVH

`ifdef CONFIG_USE_DPI_C

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
`define YSYX_DPI_C_ICACHE_HIT npc_icache_hit()
`define YSYX_DPI_C_ICACHE_MISS(flag) npc_icache_miss(flag)
`define YSYX_DPI_C_DIFFTEST_COMMIT_INST(cpc, npc, valid) npc_difftest_commit_inst(cpc, npc, valid)
`define YSYX_DPI_C_DIFFTEST_COMMIT_STORE(addr, data, mask, valid) npc_difftest_commit_store(addr, data, mask, valid)

`define YSYX_ASSERT(cond, msg) `ASSERT(cond, msg)

`else

`define YSYX_DPI_C_NPC_EXU_EBREAK 
`define YSYX_DPI_C_NPC_DIFFTEST_SKIP_REF 
`define YSYX_DPI_C_NPC_DIFFTEST_MEM_DIFF(waddr, wdata, wstrb) 
`define YSYX_DPI_C_NPC_READ(raddr, wmask) 
`define YSYX_DPI_C_NPC_WRITE(waddr, wdata, wmask)

`define YSYX_DPI_C_IFU_FETCH_COUNT 
`define YSYX_DPI_C_LSU_READ_COUNT 
`define YSYX_DPI_C_LSU_WRITE_COUNT 
`define YSYX_DPI_C_IFU_INST(inst) 
`define YSYX_DPI_C_CYCLE_RECORD 
`define YSYX_DPI_C_ICACHE_HIT
`define YSYX_DPI_C_ICACHE_MISS(flag)
`define YSYX_DPI_C_DIFFTEST_COMMIT_INST(cpc, npc, valid) 
`define YSYX_DPI_C_DIFFTEST_COMMIT_STORE(addr, data, mask, valid)

`define YSYX_ASSERT(cond, msg) 

`endif

`endif 