`include "ysyx_25040131_config.svh"

// Return Address Stack: 8-entry LIFO
// Push on call (jal/jalr rd=x1), pop on ret (jalr rd=x0, rs1=x1)
// Operates in ID stage (combinational read, registered write)
module ysyx_25040131_ras #(
    parameter DEPTH = 8,
    parameter PTR_W = 3   // log2(DEPTH)
)(
    input  logic        clk,
    input  logic        rst,

    // ID-stage signals (combinational)
    input  logic        id_valid,       // ID stage has a valid instruction
    input  logic        id_is_call,     // jal/jalr with rd=x1
    input  logic        id_is_ret,      // jalr with rd=x0, rs1=x1
    input  logic [31:0] id_pc,          // PC of the call instruction (push pc+4)

    // Prediction output (combinational, for ret)
    output logic        ras_hit,        // 1 = ret detected, use ras_target
    output logic [31:0] ras_target,     // predicted return address

    // Flush on misprediction / trap (invalidate speculative pushes)
    // For simplicity: full flush on any pipeline redirect
    input  logic        flush
);

    logic [31:0] stack [DEPTH];
    logic [PTR_W-1:0] sp; // points to next free slot (empty = sp==0)

    // Combinational: peek top of stack for ret prediction
    assign ras_hit    = id_valid && id_is_ret && (sp != '0);
    assign ras_target = stack[PTR_W'(sp - 1'b1)];

    always_ff @(posedge clk) begin
        if (rst || flush) begin
            sp <= '0;
        end else if (id_valid) begin
            if (id_is_call && !id_is_ret) begin
                stack[sp] <= id_pc + 32'd4;
                sp <= PTR_W'(sp + 1'b1);
            end else if (id_is_ret && (sp != '0)) begin
                sp <= PTR_W'(sp - 1'b1);
            end
        end
    end

endmodule
