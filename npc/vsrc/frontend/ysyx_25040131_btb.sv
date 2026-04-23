`include "ysyx_25040131_config.svh"
`include "ysyx_25040131_dpi_c.svh"

// Branch Target Buffer: 64-entry direct-mapped, 2-bit bimodal predictor
// Query in IF stage, update in EX stage
module ysyx_25040131_btb #(
    parameter ENTRIES = 64,
    parameter IDX_W   = 6   // log2(ENTRIES)
)(
    input  logic        clk,
    input  logic        rst,

    // IF-stage query (combinational)
    input  logic [31:0] if_pc,
    output logic        btb_hit,
    output logic [31:0] btb_target,

    // EX-stage update (registered)
    input  logic        ex_update_en,    // 1 when branch/jal/jalr resolves
    input  logic [31:0] ex_pc,           // PC of the branch instruction
    input  logic [31:0] ex_target,       // resolved target
    input  logic        ex_taken,        // whether branch was actually taken

    // misprediction notification (from top-level, for DPI-C counter)
    input  logic        ex_mispredict_en // pulse when misprediction detected
);

    localparam TAG_W = 32 - IDX_W - 2;  // 24 bits

    logic [TAG_W-1:0] tag_arr   [ENTRIES];
    logic [31:0]      tgt_arr   [ENTRIES];
    logic             valid_arr [ENTRIES];
    logic [1:0]       cnt_arr   [ENTRIES]; // 2-bit saturating counter

    wire [IDX_W-1:0] if_idx = if_pc[IDX_W+1:2];
    wire [TAG_W-1:0] if_tag = if_pc[31:IDX_W+2];

    // Combinational read: hit only when valid, tag matches, AND counter predicts taken (cnt >= 2'b10)
    wire if_tag_match = valid_arr[if_idx] && (tag_arr[if_idx] == if_tag);
    assign btb_hit    = if_tag_match && cnt_arr[if_idx][1];
    assign btb_target = tgt_arr[if_idx];

    // Sequential write (EX stage)
    wire [IDX_W-1:0] ex_idx = ex_pc[IDX_W+1:2];
    wire [TAG_W-1:0] ex_tag = ex_pc[31:IDX_W+2];
    wire             ex_tag_match = valid_arr[ex_idx] && (tag_arr[ex_idx] == ex_tag);

    integer i;
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < ENTRIES; i = i + 1) begin
                valid_arr[i] <= 1'b0;
                cnt_arr[i]   <= 2'b01; // init: weakly not-taken
            end
        end else begin
            if (ex_update_en) begin
                if (ex_tag_match) begin
                    // Same branch: only update counter and target
                    cnt_arr[ex_idx] <= ex_taken ? (cnt_arr[ex_idx] == 2'b11 ? 2'b11 : cnt_arr[ex_idx] + 1)
                                                : (cnt_arr[ex_idx] == 2'b00 ? 2'b00 : cnt_arr[ex_idx] - 1);
                    if (ex_taken)
                        tgt_arr[ex_idx] <= ex_target;
                end else if (ex_taken) begin
                    // Only install new entry for taken branches
                    valid_arr[ex_idx] <= 1'b1;
                    tag_arr  [ex_idx] <= ex_tag;
                    tgt_arr  [ex_idx] <= ex_target;
                    cnt_arr  [ex_idx] <= 2'b10;
                end
            end
            // DPI-C performance counters
            if (ex_update_en && ex_taken) begin
                `YSYX_DPI_C_BTB_PREDICT;
            end
            if (ex_mispredict_en) begin
                `YSYX_DPI_C_BTB_MISPREDICT;
            end
        end
    end

endmodule
