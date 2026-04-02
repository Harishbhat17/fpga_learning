// cdc_handshake.v
// Toggle-based pulse synchronizer + four-phase handshake for CDC
//
// This module safely transfers:
//   1. A single-cycle pulse from clk_src to clk_dst (toggle sync)
//   2. A multi-bit data value from clk_src to clk_dst (handshake)
//
// Protocol:
//   1. Assert send_req in src domain with valid data_src
//   2. Wait for send_ack (src domain) — data has been captured in dst domain
//   3. Deassert send_req; new transfer can begin after send_ack goes low
//
// Constraints required:
//   set_max_delay -datapath_only -from req_toggle_reg -to req_sync_reg[0] <dst_period*0.9>
//   set_max_delay -datapath_only -from ack_toggle_reg -to ack_sync_reg[0] <src_period*0.9>

`timescale 1ns/1ps

module cdc_handshake #(
    parameter DATA_WIDTH = 8
) (
    // Source domain
    input  logic                  clk_src,
    input  logic                  rst_src_n,
    input  logic                  send_req,       // Pulse: initiate transfer
    input  logic [DATA_WIDTH-1:0] data_src,
    output logic                  send_ack,       // Pulse: transfer complete

    // Destination domain
    input  logic                  clk_dst,
    input  logic                  rst_dst_n,
    output logic                  data_valid,     // Pulse: new data available
    output logic [DATA_WIDTH-1:0] data_dst
);

    // -------------------------------------------------------
    // Source domain: toggle request
    // -------------------------------------------------------
    logic                  req_toggle;   // Toggles on each send_req
    logic [DATA_WIDTH-1:0] data_latch;

    always_ff @(posedge clk_src or negedge rst_src_n) begin
        if (!rst_src_n) begin
            req_toggle <= 1'b0;
            data_latch <= '0;
        end else begin
            if (send_req) begin
                req_toggle <= ~req_toggle;  // Toggle on request
                data_latch <= data_src;     // Latch data at request time
            end
        end
    end

    // -------------------------------------------------------
    // Sync req_toggle to dst domain (2-FF synchronizer)
    // -------------------------------------------------------
    (* ASYNC_REG = "TRUE" *) logic [1:0] req_sync_reg;
    logic req_dst, req_dst_prev;

    always_ff @(posedge clk_dst or negedge rst_dst_n) begin
        if (!rst_dst_n) begin
            req_sync_reg <= 2'b00;
        end else begin
            req_sync_reg <= {req_sync_reg[0], req_toggle};
        end
    end

    always_ff @(posedge clk_dst or negedge rst_dst_n) begin
        if (!rst_dst_n) begin
            req_dst      <= 1'b0;
            req_dst_prev <= 1'b0;
        end else begin
            req_dst_prev <= req_sync_reg[1];
            req_dst      <= req_sync_reg[1];
        end
    end

    // Detect level transition in dst domain → pulse
    assign data_valid = req_dst ^ req_dst_prev;

    // Capture data on rising edge of data_valid
    always_ff @(posedge clk_dst or negedge rst_dst_n) begin
        if (!rst_dst_n)
            data_dst <= '0;
        else if (data_valid)
            data_dst <= data_latch;
    end

    // -------------------------------------------------------
    // Sync ack toggle back to src domain
    // -------------------------------------------------------
    logic ack_toggle;

    always_ff @(posedge clk_dst or negedge rst_dst_n) begin
        if (!rst_dst_n)
            ack_toggle <= 1'b0;
        else if (data_valid)
            ack_toggle <= ~ack_toggle;
    end

    (* ASYNC_REG = "TRUE" *) logic [1:0] ack_sync_reg;
    logic ack_src, ack_src_prev;

    always_ff @(posedge clk_src or negedge rst_src_n) begin
        if (!rst_src_n) begin
            ack_sync_reg <= 2'b00;
        end else begin
            ack_sync_reg <= {ack_sync_reg[0], ack_toggle};
        end
    end

    always_ff @(posedge clk_src or negedge rst_src_n) begin
        if (!rst_src_n) begin
            ack_src      <= 1'b0;
            ack_src_prev <= 1'b0;
        end else begin
            ack_src_prev <= ack_sync_reg[1];
            ack_src      <= ack_sync_reg[1];
        end
    end

    assign send_ack = ack_src ^ ack_src_prev;

endmodule
