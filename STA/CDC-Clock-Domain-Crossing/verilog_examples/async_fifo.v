// async_fifo.v
// Asynchronous FIFO with Gray-coded pointer synchronization
//
// Supports independent read and write clock domains.
// Uses Gray-coded read/write pointers synchronized via 2-FF synchronizers
// to generate accurate full/empty flags.
//
// Parameters:
//   DATA_WIDTH  - Width of each data word
//   FIFO_DEPTH  - Number of entries (must be a power of 2)
//
// Interface:
//   Write port: clocked by wr_clk
//   Read port:  clocked by rd_clk
//
// Constraints needed (Vivado XDC example — adapt to your design):
//   set_max_delay -datapath_only -from [wr_ptr_gray_reg] -to [wr_sync_meta_reg] <rd_period*0.9>
//   set_max_delay -datapath_only -from [rd_ptr_gray_reg] -to [rd_sync_meta_reg] <wr_period*0.9>

`timescale 1ns/1ps

module async_fifo #(
    parameter DATA_WIDTH = 8,
    parameter FIFO_DEPTH = 16   // Must be a power of 2
) (
    // Write port
    input  logic                  wr_clk,
    input  logic                  wr_rst_n,   // Async reset (active-low)
    input  logic                  wr_en,
    input  logic [DATA_WIDTH-1:0] wr_data,
    output logic                  full,
    output logic                  almost_full, // Full when ≤ 2 entries remain

    // Read port
    input  logic                  rd_clk,
    input  logic                  rd_rst_n,
    input  logic                  rd_en,
    output logic [DATA_WIDTH-1:0] rd_data,
    output logic                  empty,
    output logic                  almost_empty // Empty when ≤ 2 entries remain
);

    // Pointer width: one extra bit for full/empty disambiguation
    localparam PTR_WIDTH = $clog2(FIFO_DEPTH) + 1;

    // -------------------------------------------------------
    // Internal memory
    // -------------------------------------------------------
    logic [DATA_WIDTH-1:0] mem [0:FIFO_DEPTH-1];

    // -------------------------------------------------------
    // Write domain: write pointer
    // -------------------------------------------------------
    logic [PTR_WIDTH-1:0] wr_ptr_bin;
    logic [PTR_WIDTH-1:0] wr_ptr_gray;

    always_ff @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n)
            wr_ptr_bin <= '0;
        else if (wr_en && !full)
            wr_ptr_bin <= wr_ptr_bin + 1'b1;
    end

    // Write to memory
    always_ff @(posedge wr_clk) begin
        if (wr_en && !full)
            mem[wr_ptr_bin[PTR_WIDTH-2:0]] <= wr_data;
    end

    // Binary to Gray
    assign wr_ptr_gray = (wr_ptr_bin >> 1) ^ wr_ptr_bin;

    // -------------------------------------------------------
    // Read domain: read pointer
    // -------------------------------------------------------
    logic [PTR_WIDTH-1:0] rd_ptr_bin;
    logic [PTR_WIDTH-1:0] rd_ptr_gray;

    always_ff @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n)
            rd_ptr_bin <= '0;
        else if (rd_en && !empty)
            rd_ptr_bin <= rd_ptr_bin + 1'b1;
    end

    // Read from memory (registered output — 1 cycle latency)
    always_ff @(posedge rd_clk) begin
        if (rd_en && !empty)
            rd_data <= mem[rd_ptr_bin[PTR_WIDTH-2:0]];
    end

    // Binary to Gray
    assign rd_ptr_gray = (rd_ptr_bin >> 1) ^ rd_ptr_bin;

    // -------------------------------------------------------
    // Synchronize wr_ptr to rd domain
    // -------------------------------------------------------
    (* ASYNC_REG = "TRUE" *) logic [PTR_WIDTH-1:0] wr_ptr_sync_meta;
    (* ASYNC_REG = "TRUE" *) logic [PTR_WIDTH-1:0] wr_ptr_sync;

    always_ff @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            wr_ptr_sync_meta <= '0;
            wr_ptr_sync      <= '0;
        end else begin
            wr_ptr_sync_meta <= wr_ptr_gray;
            wr_ptr_sync      <= wr_ptr_sync_meta;
        end
    end

    // -------------------------------------------------------
    // Synchronize rd_ptr to wr domain
    // -------------------------------------------------------
    (* ASYNC_REG = "TRUE" *) logic [PTR_WIDTH-1:0] rd_ptr_sync_meta;
    (* ASYNC_REG = "TRUE" *) logic [PTR_WIDTH-1:0] rd_ptr_sync;

    always_ff @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            rd_ptr_sync_meta <= '0;
            rd_ptr_sync      <= '0;
        end else begin
            rd_ptr_sync_meta <= rd_ptr_gray;
            rd_ptr_sync      <= rd_ptr_sync_meta;
        end
    end

    // -------------------------------------------------------
    // Full flag (wr domain): wr pointer has lapped rd pointer
    // Gray-coded: full when top 2 bits differ, rest same
    // -------------------------------------------------------
    assign full = (wr_ptr_gray[PTR_WIDTH-1]   != rd_ptr_sync[PTR_WIDTH-1])  &&
                  (wr_ptr_gray[PTR_WIDTH-2]   != rd_ptr_sync[PTR_WIDTH-2])  &&
                  (wr_ptr_gray[PTR_WIDTH-3:0] == rd_ptr_sync[PTR_WIDTH-3:0]);

    // -------------------------------------------------------
    // Empty flag (rd domain): rd pointer has caught up to wr pointer
    // Gray-coded: empty when all bits match
    // -------------------------------------------------------
    assign empty = (rd_ptr_gray == wr_ptr_sync);

    // -------------------------------------------------------
    // Almost full / almost empty (word count comparison)
    // -------------------------------------------------------
    // Decode synchronized pointers back to binary for word count
    logic [PTR_WIDTH-1:0] wr_ptr_sync_bin, rd_ptr_sync_bin;

    always_comb begin
        wr_ptr_sync_bin[PTR_WIDTH-1] = wr_ptr_sync[PTR_WIDTH-1];  // in rd domain, used for fill level in rd domain
        for (int i = PTR_WIDTH-2; i >= 0; i--)
            wr_ptr_sync_bin[i] = wr_ptr_sync_bin[i+1] ^ wr_ptr_sync[i];
    end

    always_comb begin
        rd_ptr_sync_bin[PTR_WIDTH-1] = rd_ptr_sync[PTR_WIDTH-1];
        for (int i = PTR_WIDTH-2; i >= 0; i--)
            rd_ptr_sync_bin[i] = rd_ptr_sync_bin[i+1] ^ rd_ptr_sync[i];
    end

    logic [PTR_WIDTH-1:0] fill_level_rd;
    assign fill_level_rd = wr_ptr_sync_bin - rd_ptr_bin;
    assign almost_empty  = (fill_level_rd <= 2);

    logic [PTR_WIDTH-1:0] fill_level_wr;
    assign fill_level_wr = wr_ptr_bin - rd_ptr_sync_bin;
    assign almost_full   = (fill_level_wr >= (FIFO_DEPTH - 2));

endmodule
