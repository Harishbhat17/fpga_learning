## simple_adder.xdc
## XDC constraints for a simple single-clock pipelined adder design
## Target: Xilinx UltraScale+ (xczu7ev)
## Frequency: 200 MHz

# =============================================================
# Primary Clock
# =============================================================
# 200 MHz system clock on dedicated clock-capable input pin
create_clock -period 5.000 -name clk_200 -waveform {0.000 2.500} [get_ports clk_in_p]

# If using single-ended clock:
# create_clock -period 5.000 -name clk_200 [get_ports clk_in]

# =============================================================
# Generated Clock (if MMCM/PLL present)
# =============================================================
# Example: MMCM divides 200 MHz by 2 to create 100 MHz output
# (Vivado auto-derives MMCM clocks, but explicit definition is preferred)
# create_generated_clock \
#     -name clk_100 \
#     -source [get_pins mmcm_inst/CLKIN1] \
#     -divide_by 2 \
#     -master_clock clk_200 \
#     [get_pins mmcm_inst/CLKOUT0]

# =============================================================
# Clock Uncertainty (optional additional margin)
# =============================================================
# Adds 100 ps setup margin and 50 ps hold margin beyond tool defaults
set_clock_uncertainty -setup 0.100 [get_clocks clk_200]
set_clock_uncertainty -hold  0.050 [get_clocks clk_200]

# =============================================================
# Input Delays
# =============================================================
# Operand A: valid 2.0 ns after rising edge, held for 1.0 ns
set_input_delay -clock clk_200 -max 2.000 [get_ports {a[*]}]
set_input_delay -clock clk_200 -min 1.000 [get_ports {a[*]}]

# Operand B: same timing
set_input_delay -clock clk_200 -max 2.000 [get_ports {b[*]}]
set_input_delay -clock clk_200 -min 1.000 [get_ports {b[*]}]

# =============================================================
# Output Delays
# =============================================================
# Result: downstream device requires data 1.5 ns before clock edge
# Minimum hold at output: 0.5 ns after clock edge
set_output_delay -clock clk_200 -max  1.500 [get_ports {result[*]}]
set_output_delay -clock clk_200 -min -0.500 [get_ports {result[*]}]

# Overflow/carry output
set_output_delay -clock clk_200 -max  1.500 [get_ports overflow]
set_output_delay -clock clk_200 -min -0.500 [get_ports overflow]

# =============================================================
# False Paths
# =============================================================
# Asynchronous active-low reset — no timing check needed
set_false_path -from [get_ports rst_n]

# =============================================================
# I/O Standards and Pin Assignments
# =============================================================
set_property IOSTANDARD LVCMOS33 [get_ports {a[*] b[*] result[*] overflow rst_n}]
set_property IOSTANDARD DIFF_SSTL12 [get_ports {clk_in_p clk_in_n}]

# Example pin assignments for a KC705 board — replace with your pin assignments
# set_property PACKAGE_PIN AD11 [get_ports clk_in_p]
# set_property PACKAGE_PIN AD10 [get_ports clk_in_n]
