`include "ysyx_25040131_dpi_c.svh"

`ifdef CONFIG_USE_DPI_C

import "DPI-C" function void npc_exu_ebreak();

import "DPI-C" function void npc_difftest_skip_ref();
import "DPI-C" function void npc_difftest_mem_diff(
    input int waddr,
    input int wdata,
    input int wstrb
);

import "DPI-C" function int npc_read(
    input int raddr, 
    input int wmask
);

import "DPI-C" function void npc_write(
    input int waddr, 
    input int wdata, 
    input int wmask
);

import "DPI-C" function void npc_ifu_fetch_count(
);

import "DPI-C" function void npc_lsu_read_count(
);

import "DPI-C" function void npc_lsu_write_count(
);

import "DPI-C" function void npc_ifu_inst(
    input int inst
);

import "DPI-C" function void npc_cycle_record(
);

import "DPI-C" function void npc_icache_hit(
);

import "DPI-C" function void npc_icache_miss(
    input int flag
);

import "DPI-C" function void npc_difftest_commit_inst(
    input int cpc,
    input int npc,
    input int valid
);

import "DPI-C" function void npc_difftest_commit_store(
    input int addr,
    input int data,
    input int mask,
    input int valid
);

`endif