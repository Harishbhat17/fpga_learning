// cdc_single_bit.v
// Two flip-flop synchronizer for single-bit clock domain crossing
// Parameterizable number of synchronizer stages (default: 2)
//
// Usage: Synchronize any single-bit signal from an asynchronous source domain
// to a destination clock domain.
//
// Constraints required (Vivado XDC):
//   set_max_delay -datapath_only -from [src_ff] -to [u_sync/meta_reg[0]] <dst_period*0.9>
//   set_property ASYNC_REG TRUE [get_cells u_sync/sync_reg*]

`timescale 1ns/1ps

module cdc_sync_2ff #(
    parameter STAGES = 2   // Number of synchronizer stages (minimum 2)
) (
    input  logic clk_dst,   // Destination clock domain clock
    input  logic rst_dst_n, // Async reset (active-low), in dst domain
    input  logic data_in,   // Asynchronous input from source domain
    output logic data_out   // Synchronized output in dst domain
);

    // ASYNC_REG attribute tells Vivado to:
    //  1. Co-place these FFs in the same slice
    //  2. Mark them for CDC tool analysis
    //  3. Prevent optimization across the synchronizer boundary
    (* ASYNC_REG = "TRUE" *) logic [STAGES-1:0] sync_reg;

    always_ff @(posedge clk_dst or negedge rst_dst_n) begin
        if (!rst_dst_n) begin
            sync_reg <= {STAGES{1'b0}};
        end else begin
            sync_reg <= {sync_reg[STAGES-2:0], data_in};
        end
    end

    assign data_out = sync_reg[STAGES-1];

endmodule
