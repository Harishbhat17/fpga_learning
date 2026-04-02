## cdc_design.sdc
## SDC constraints for Clock Domain Crossing (CDC) design in Quartus
## clk_fast (200 MHz) and clk_slow (50 MHz), asynchronous

# =============================================================
# Clocks
# =============================================================
derive_pll_clocks -create_base_clocks

create_clock -period 5.000  -name clk_fast [get_ports clk_fast]
create_clock -period 20.000 -name clk_slow [get_ports clk_slow]

set_clock_groups -asynchronous \
    -group { clk_fast } \
    -group { clk_slow }

derive_clock_uncertainty

# =============================================================
# 2-FF Synchronizer Constraints
# =============================================================
# The 2-FF synchronizer meta-stability registers are constrained
# to a maximum delay of one slow-clock period minus margin

# Single-bit CDC: fast → slow
set_max_delay -from [get_registers {*fast_data_reg}] \
              -to   [get_registers {*sync_meta_reg}] \
              18.0  ;# < clk_slow period (20 ns), with 2 ns margin

# Single-bit CDC: slow → fast
set_max_delay -from [get_registers {*slow_ack_reg}] \
              -to   [get_registers {*ack_sync_meta_reg}] \
              4.0   ;# < clk_fast period (5 ns), with 1 ns margin

# =============================================================
# Async FIFO — Gray-code pointer constraints
# =============================================================
# Write pointer (Gray) crossing from clk_fast to clk_slow
set_max_delay \
    -from [get_registers {*wr_ptr_gray_reg[*]}] \
    -to   [get_registers {*wr_ptr_sync_meta_reg[*]}] \
    18.0

# Read pointer (Gray) crossing from clk_slow to clk_fast
set_max_delay \
    -from [get_registers {*rd_ptr_gray_reg[*]}] \
    -to   [get_registers {*rd_ptr_sync_meta_reg[*]}] \
    4.0

# =============================================================
# I/O Constraints
# =============================================================
set_input_delay  -clock clk_fast -max 1.5 [get_ports {fast_in[*]}]
set_input_delay  -clock clk_fast -min 0.5 [get_ports {fast_in[*]}]
set_output_delay -clock clk_slow -max 5.0 [get_ports {slow_out[*]}]
set_output_delay -clock clk_slow -min 1.0 [get_ports {slow_out[*]}]

set_false_path -from [get_ports rst_n]
