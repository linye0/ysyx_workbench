`include "ysyx_25040131_dpi_c.svh"

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