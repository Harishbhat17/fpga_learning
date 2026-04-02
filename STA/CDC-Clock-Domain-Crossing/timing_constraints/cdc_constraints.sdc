## cdc_constraints.sdc
## Quartus SDC timing constraints for Clock Domain Crossing (CDC) paths
##
## Equivalent to cdc_constraints.xdc but using Quartus SDC format.
## Clocks: clk_fast (200 MHz), clk_slow (50 MHz)

# =============================================================
# Clock Definitions (in main SDC file, not repeated here normally)
# =============================================================
# derive_pll_clocks -create_base_clocks
# create_clock -period 5.000  -name clk_fast [get_ports clk_fast]
# create_clock -period 20.000 -name clk_slow [get_ports clk_slow]

set_clock_groups -asynchronous \
    -group { clk_fast } \
    -group { clk_slow }

# derive_clock_uncertainty

# =============================================================
# 2-FF Synchronizer: clk_fast → clk_slow
# =============================================================
set_max_delay \
    -from [get_registers {*fast_src_reg}] \
    -to   [get_registers {*sync_meta_reg[0]}] \
    18.0

# 2-FF Synchronizer: clk_slow → clk_fast
set_max_delay \
    -from [get_registers {*slow_src_reg}] \
    -to   [get_registers {*sync_meta_reg[0]}] \
    4.5

# =============================================================
# Async FIFO Pointer Synchronization
# =============================================================
# Write pointer (Gray) from clk_fast to clk_slow
set_max_delay \
    -from [get_registers {*wr_ptr_gray_reg[*]}] \
    -to   [get_registers {*wr_ptr_sync_meta[*]}] \
    18.0

# Read pointer (Gray) from clk_slow to clk_fast
set_max_delay \
    -from [get_registers {*rd_ptr_gray_reg[*]}] \
    -to   [get_registers {*rd_ptr_sync_meta[*]}] \
    4.5

# =============================================================
# Handshake Toggle Synchronization
# =============================================================
set_max_delay \
    -from [get_registers {*req_toggle_reg}] \
    -to   [get_registers {*req_sync_meta_reg[0]}] \
    18.0

set_max_delay \
    -from [get_registers {*ack_toggle_reg}] \
    -to   [get_registers {*ack_sync_meta_reg[0]}] \
    4.5

# Stable data bus during handshake
set_max_delay \
    -from [get_registers {*data_latch_reg[*]}] \
    -to   [get_registers {*data_dst_reg[*]}] \
    18.0
