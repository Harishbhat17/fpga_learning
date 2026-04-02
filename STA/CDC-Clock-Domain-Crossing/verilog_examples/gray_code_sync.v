// gray_code_sync.v
// Gray-coded counter with safe cross-domain synchronization
//
// A binary counter is encoded as Gray code before crossing the clock domain.
// Since Gray code changes only one bit per count, a 2-FF synchronizer per
// bit is safe (at most one bit is metastable at a time, and the sampled
// value is always a valid Gray code).
//
// The synchronized value is then decoded back to binary in the dst domain.

`timescale 1ns/1ps

module gray_code_sync #(
    parameter WIDTH = 4   // Counter width (up to 2^WIDTH values)
) (
    // Source domain: counter increments here
    input  logic             clk_src,
    input  logic             rst_src_n,
    input  logic             increment,   // Pulse to advance counter

    // Destination domain: synchronized count value
    input  logic             clk_dst,
    input  logic             rst_dst_n,
    output logic [WIDTH-1:0] count_dst    // Synchronized count (binary) in dst domain
);

    // -------------------------------------------------------
    // Source domain: binary counter + Gray encode
    // -------------------------------------------------------
    logic [WIDTH-1:0] count_bin_src;
    logic [WIDTH-1:0] count_gray_src;

    always_ff @(posedge clk_src or negedge rst_src_n) begin
        if (!rst_src_n)
            count_bin_src <= '0;
        else if (increment)
            count_bin_src <= count_bin_src + 1'b1;
    end

    // Binary to Gray: gray[i] = bin[i] ^ bin[i+1]  (MSB: gray[N-1] = bin[N-1])
    assign count_gray_src = (count_bin_src >> 1) ^ count_bin_src;

    // -------------------------------------------------------
    // 2-FF synchronizer for each Gray-code bit
    // -------------------------------------------------------
    (* ASYNC_REG = "TRUE" *) logic [WIDTH-1:0] gray_sync_meta;
    (* ASYNC_REG = "TRUE" *) logic [WIDTH-1:0] gray_sync_out;

    always_ff @(posedge clk_dst or negedge rst_dst_n) begin
        if (!rst_dst_n) begin
            gray_sync_meta <= '0;
            gray_sync_out  <= '0;
        end else begin
            gray_sync_meta <= count_gray_src;
            gray_sync_out  <= gray_sync_meta;
        end
    end

    // -------------------------------------------------------
    // Destination domain: Gray decode back to binary
    // -------------------------------------------------------
    logic [WIDTH-1:0] count_bin_dst;

    always_comb begin
        count_bin_dst[WIDTH-1] = gray_sync_out[WIDTH-1];
        for (int i = WIDTH-2; i >= 0; i--) begin
            count_bin_dst[i] = count_bin_dst[i+1] ^ gray_sync_out[i];
        end
    end

    assign count_dst = count_bin_dst;

endmodule
