## cdc_design.xdc
## XDC constraints for a design with proper Clock Domain Crossing (CDC)
## Design: clk_fast (200 MHz) → 2FF synchronizer → clk_slow (50 MHz)
##         Single-bit control signals and multi-bit data via async FIFO

# =============================================================
# Clock Definitions
# =============================================================
create_clock -period 5.000 -name clk_fast [get_ports clk_fast_p]
create_clock -period 20.000 -name clk_slow [get_ports clk_slow_p]

# These clocks are asynchronous — no phase relationship
set_clock_groups -asynchronous \
    -group [get_clocks clk_fast] \
    -group [get_clocks clk_slow]

# =============================================================
# CDC Single-Bit Synchronizer Constraints
# =============================================================
# The 2-FF synchronizer registers are marked ASYNC_REG in RTL.
# We constrain the launch-to-meta flip-flop path to prevent the
# router from placing them too far apart.

# Identify synchronizer cells (named by convention: *_sync_meta and *_sync_ff)
# and constrain max delay on the crossing wire
set_max_delay -datapath_only \
    -from [get_cells -hierarchical -filter {NAME =~ *_fast_reg}] \
    -to   [get_cells -hierarchical -filter {NAME =~ *_sync_meta_reg}] \
    15.0  ; # Less than one clk_slow period

# Ensure the two synchronizer FFs are placed together
set_property ASYNC_REG TRUE \
    [get_cells -hierarchical -filter {NAME =~ *_sync_meta_reg || NAME =~ *_sync_ff_reg}]

# =============================================================
# Async FIFO Constraints
# =============================================================
# For async FIFOs, the write-pointer Gray code crosses from clk_fast to clk_slow.
# The read-pointer Gray code crosses from clk_slow to clk_fast.
# Each individual bit of a Gray-coded pointer changes at most once per transition,
# so a simple 2-FF synchronizer per bit is sufficient.

# Constrain Gray-code pointer crossing: max one slow-clock period
set_max_delay -datapath_only \
    -from [get_cells -hierarchical -filter {NAME =~ *fifo*wr_ptr_gray_reg*}] \
    -to   [get_cells -hierarchical -filter {NAME =~ *fifo*wr_ptr_sync_meta*}] \
    18.0  ; # < clk_slow period (20 ns) with margin

set_max_delay -datapath_only \
    -from [get_cells -hierarchical -filter {NAME =~ *fifo*rd_ptr_gray_reg*}] \
    -to   [get_cells -hierarchical -filter {NAME =~ *fifo*rd_ptr_sync_meta*}] \
    4.5   ; # < clk_fast period (5 ns) with margin

# =============================================================
# Handshake Protocol Constraints
# =============================================================
# Handshake: request (clk_fast) → sync to clk_slow, ack (clk_slow) → sync to clk_fast
# The data bus is only sampled after the handshake completes (multi-cycle stable)

set_max_delay -datapath_only \
    -from [get_cells -hierarchical -filter {NAME =~ *req_fast_reg}] \
    -to   [get_cells -hierarchical -filter {NAME =~ *req_sync_meta*}] \
    15.0

set_max_delay -datapath_only \
    -from [get_cells -hierarchical -filter {NAME =~ *data_latch_reg*}] \
    -to   [get_cells -hierarchical -filter {NAME =~ *data_cdc_sync*}] \
    15.0

# =============================================================
# I/O Constraints
# =============================================================
set_input_delay  -clock clk_fast -max 1.5 [get_ports {fast_data_in[*]}]
set_input_delay  -clock clk_fast -min 0.5 [get_ports {fast_data_in[*]}]
set_output_delay -clock clk_slow -max 5.0 [get_ports {slow_data_out[*]}]
set_output_delay -clock clk_slow -min 1.0 [get_ports {slow_data_out[*]}]

set_false_path -from [get_ports rst_n]

set_property IOSTANDARD LVCMOS18 [get_ports {fast_data_in[*] slow_data_out[*] rst_n}]
set_property IOSTANDARD DIFF_SSTL12 [get_ports {clk_fast_p clk_fast_n clk_slow_p clk_slow_n}]
