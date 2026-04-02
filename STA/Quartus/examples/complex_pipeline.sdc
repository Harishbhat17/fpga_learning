## complex_pipeline.sdc
## SDC constraints for a pipelined DSP datapath in Quartus
## Design: 4-stage FIR filter pipeline at 200 MHz
## Multi-cycle path for accumulation (3 cycles)

# =============================================================
# Clocks
# =============================================================
derive_pll_clocks -create_base_clocks

# Main DSP clock: 200 MHz
create_clock -period 5.000 -name clk_dsp [get_ports dsp_clk]

# Sample clock: 25 MHz (ADC input rate)
create_clock -period 40.000 -name clk_adc [get_ports adc_clk]

# The ADC clock is asynchronous to DSP clock
set_clock_groups -asynchronous \
    -group { clk_dsp } \
    -group { clk_adc }

derive_clock_uncertainty

# =============================================================
# Multi-Cycle Paths
# =============================================================
# The FIR accumulator runs over 3 DSP clocks (accumulating partial products)
set_multicycle_path -setup \
    -from [get_registers {*fir_stage1_reg[*]}] \
    -to   [get_registers {*fir_accumulator_reg[*]}] \
    3

set_multicycle_path -hold \
    -from [get_registers {*fir_stage1_reg[*]}] \
    -to   [get_registers {*fir_accumulator_reg[*]}] \
    2

# Coefficient ROM read: 2 cycles (ROM access + register)
set_multicycle_path -setup \
    -from [get_registers {*coeff_addr_reg[*]}] \
    -to   [get_registers {*coeff_data_reg[*]}] \
    2

set_multicycle_path -hold \
    -from [get_registers {*coeff_addr_reg[*]}] \
    -to   [get_registers {*coeff_data_reg[*]}] \
    1

# =============================================================
# I/O Delays — ADC domain
# =============================================================
# ADC data valid 8 ns after ADC clock edge (slow ADC, 25 MHz)
set_input_delay -clock clk_adc -max  8.000 [get_ports {adc_data[*]}]
set_input_delay -clock clk_adc -min  4.000 [get_ports {adc_data[*]}]
set_input_delay -clock clk_adc -max  2.000 [get_ports adc_valid]
set_input_delay -clock clk_adc -min  0.500 [get_ports adc_valid]

# =============================================================
# I/O Delays — DSP domain output
# =============================================================
set_output_delay -clock clk_dsp -max 2.000 [get_ports {filter_out[*]}]
set_output_delay -clock clk_dsp -min 0.000 [get_ports {filter_out[*]}]
set_output_delay -clock clk_dsp -max 1.000 [get_ports filter_valid]
set_output_delay -clock clk_dsp -min 0.000 [get_ports filter_valid]

# =============================================================
# False Paths
# =============================================================
set_false_path -from [get_ports rst_n]
set_false_path -from [get_ports {filter_coeff[*]}]  ;# static coefficients
