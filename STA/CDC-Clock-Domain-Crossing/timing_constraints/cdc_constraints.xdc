## cdc_constraints.xdc
## Vivado XDC timing constraints for Clock Domain Crossing (CDC) paths
##
## This file provides templates for constraining CDC synchronizers.
## Adapt register and clock names to your specific design.
##
## Clocks assumed:
##   clk_fast: 200 MHz (5 ns period)
##   clk_slow:  50 MHz (20 ns period)

# =============================================================
# Clock Definitions (if not already in top_clocks.xdc)
# =============================================================
# create_clock -period 5.000  -name clk_fast [get_ports clk_fast]
# create_clock -period 20.000 -name clk_slow [get_ports clk_slow]

# Declare asynchronous relationship (removes STA check on crossing paths)
set_clock_groups -asynchronous \
    -group [get_clocks clk_fast] \
    -group [get_clocks clk_slow]

# =============================================================
# 2-FF Synchronizer Constraints
# =============================================================
# Constrain the combinational path from the source FF (in clk_fast)
# to the first synchronizer FF (in clk_slow).
# The max delay should be <= one dst clock period (20 ns) with margin.

# Single-bit CDC: clk_fast → clk_slow
set_max_delay -datapath_only \
    -from [get_cells -hierarchical -filter {NAME =~ *fast_src_reg}] \
    -to   [get_cells -hierarchical -filter {NAME =~ *sync_meta_reg[0]}] \
    18.000

# Single-bit CDC: clk_slow → clk_fast
set_max_delay -datapath_only \
    -from [get_cells -hierarchical -filter {NAME =~ *slow_src_reg}] \
    -to   [get_cells -hierarchical -filter {NAME =~ *sync_meta_reg[0]}] \
    4.500

# Mark all synchronizer registers with ASYNC_REG
# (Replace pattern with your actual synchronizer instance names)
set_property ASYNC_REG TRUE \
    [get_cells -hierarchical -filter {NAME =~ *sync_meta_reg* || NAME =~ *sync_out_reg*}]

# =============================================================
# Async FIFO Write Pointer: clk_fast → clk_slow
# =============================================================
set_max_delay -datapath_only \
    -from [get_cells -hierarchical -filter {NAME =~ *wr_ptr_gray_reg[*]}] \
    -to   [get_cells -hierarchical -filter {NAME =~ *wr_ptr_sync_meta[*]}] \
    18.000

# Async FIFO Read Pointer: clk_slow → clk_fast
set_max_delay -datapath_only \
    -from [get_cells -hierarchical -filter {NAME =~ *rd_ptr_gray_reg[*]}] \
    -to   [get_cells -hierarchical -filter {NAME =~ *rd_ptr_sync_meta[*]}] \
    4.500

# Mark FIFO synchronizer registers
set_property ASYNC_REG TRUE \
    [get_cells -hierarchical -filter {NAME =~ *wr_ptr_sync_meta* || NAME =~ *wr_ptr_sync_out*}]
set_property ASYNC_REG TRUE \
    [get_cells -hierarchical -filter {NAME =~ *rd_ptr_sync_meta* || NAME =~ *rd_ptr_sync_out*}]

# =============================================================
# Handshake Synchronizer
# =============================================================
# Request toggle: clk_fast → clk_slow
set_max_delay -datapath_only \
    -from [get_cells -hierarchical -filter {NAME =~ *req_toggle_reg}] \
    -to   [get_cells -hierarchical -filter {NAME =~ *req_sync_meta_reg[0]}] \
    18.000

# Acknowledge toggle: clk_slow → clk_fast
set_max_delay -datapath_only \
    -from [get_cells -hierarchical -filter {NAME =~ *ack_toggle_reg}] \
    -to   [get_cells -hierarchical -filter {NAME =~ *ack_sync_meta_reg[0]}] \
    4.500

# Data bus: stable during handshake (max one slow period)
# The data is latched in src domain and read by dst after handshake
set_max_delay -datapath_only \
    -from [get_cells -hierarchical -filter {NAME =~ *data_latch_reg[*]}] \
    -to   [get_cells -hierarchical -filter {NAME =~ *data_dst_reg[*]}] \
    18.000
