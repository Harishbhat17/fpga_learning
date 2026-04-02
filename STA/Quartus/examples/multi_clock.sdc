## multi_clock.sdc
## SDC constraints for multiple independent asynchronous clock domains in Quartus
## Clocks: clk_core (125 MHz), clk_fast (250 MHz), clk_io (50 MHz)

# =============================================================
# Derive PLL clocks first
# =============================================================
derive_pll_clocks -create_base_clocks

# =============================================================
# Primary Clocks
# =============================================================
create_clock -period  8.000 -name clk_core [get_ports core_clk]
create_clock -period  4.000 -name clk_fast [get_ports fast_clk]
create_clock -period 20.000 -name clk_io   [get_ports io_clk]

# =============================================================
# Clock Groups — Declare asynchronous
# =============================================================
set_clock_groups -asynchronous \
    -group { clk_core } \
    -group { clk_fast } \
    -group { clk_io   }

# =============================================================
# Derive Uncertainty
# =============================================================
derive_clock_uncertainty

# =============================================================
# I/O Delays — clk_core domain
# =============================================================
set_input_delay  -clock clk_core -max 2.000 [get_ports {core_din[*]}]
set_input_delay  -clock clk_core -min 0.800 [get_ports {core_din[*]}]
set_output_delay -clock clk_core -max 2.500 [get_ports {core_dout[*]}]
set_output_delay -clock clk_core -min 0.000 [get_ports {core_dout[*]}]

# =============================================================
# I/O Delays — clk_io domain
# =============================================================
set_input_delay  -clock clk_io -max 5.000 [get_ports {io_data[*]}]
set_input_delay  -clock clk_io -min 2.000 [get_ports {io_data[*]}]
set_output_delay -clock clk_io -max 6.000 [get_ports {io_out[*]}]
set_output_delay -clock clk_io -min 0.000 [get_ports {io_out[*]}]

# =============================================================
# False Paths
# =============================================================
set_false_path -from [get_ports rst_n]
set_false_path -from [get_ports {mode_select[*]}]  ;# static config
