## simple_adder.sdc
## SDC constraints for a simple single-clock pipelined adder in Quartus
## Target: Cyclone V (5CSEBA6U23I7)
## Frequency: 100 MHz

# =============================================================
# Derive PLL Clocks (MUST be first in Quartus SDC files)
# =============================================================
derive_pll_clocks -create_base_clocks

# =============================================================
# Primary Clock
# =============================================================
# 100 MHz system clock
create_clock -period 10.000 -name clk_sys [get_ports clk]

# =============================================================
# Derive Clock Uncertainty
# =============================================================
# Automatically models PLL jitter and inter-clock uncertainty
derive_clock_uncertainty

# =============================================================
# Input Delays
# =============================================================
# Operands available 3 ns after rising edge (i.e., sourced from another 100 MHz device)
set_input_delay -clock clk_sys -max 3.000 [get_ports {a[*]}]
set_input_delay -clock clk_sys -min 1.000 [get_ports {a[*]}]

set_input_delay -clock clk_sys -max 3.000 [get_ports {b[*]}]
set_input_delay -clock clk_sys -min 1.000 [get_ports {b[*]}]

# =============================================================
# Output Delays
# =============================================================
# Downstream latch setup: requires data 2 ns before rising edge
set_output_delay -clock clk_sys -max  2.000 [get_ports {result[*]}]
set_output_delay -clock clk_sys -min -0.500 [get_ports {result[*]}]

set_output_delay -clock clk_sys -max  2.000 [get_ports overflow]
set_output_delay -clock clk_sys -min -0.500 [get_ports overflow]

# =============================================================
# False Paths
# =============================================================
# Async active-low reset
set_false_path -from [get_ports rst_n]
