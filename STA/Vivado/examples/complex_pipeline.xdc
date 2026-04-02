## complex_pipeline.xdc
## XDC constraints for a complex pipelined datapath:
## - 4-stage image processing pipeline at 200 MHz
## - Multi-cycle path for the filter kernel computation (3 cycles)
## - Output registered before leaving FPGA
## - Two synchronous clock domains: clk_pixel (148.5 MHz) and clk_proc (200 MHz)

# =============================================================
# Clock Definitions
# =============================================================
# Pixel clock: 148.5 MHz (1080p60 pixel clock)
create_clock -period 6.734 -name clk_pixel [get_ports pclk_p]

# Processing clock: 200 MHz (internal computation)
create_clock -period 5.000 -name clk_proc  [get_ports proc_clk_p]

# =============================================================
# Generated Clocks from MMCM
# =============================================================
# MMCM takes clk_pixel as input and generates clk_proc
# (If derived from the same MMCM, these are synchronous)
create_generated_clock \
    -name clk_proc_gen \
    -source [get_pins mmcm_pixel/CLKIN1] \
    -multiply_by 4 \
    -divide_by 3 \
    -master_clock clk_pixel \
    [get_pins mmcm_pixel/CLKOUT0]

# Declare the two domains as synchronous (both from same MMCM)
# Do NOT use set_clock_groups -asynchronous for synchronous domains

# =============================================================
# Clock Uncertainty
# =============================================================
set_clock_uncertainty -setup 0.100 [get_clocks clk_pixel]
set_clock_uncertainty -hold  0.050 [get_clocks clk_pixel]
set_clock_uncertainty -setup 0.100 [get_clocks clk_proc_gen]
set_clock_uncertainty -hold  0.050 [get_clocks clk_proc_gen]

# =============================================================
# Input Delays — Video input (source-synchronous, clk_pixel)
# =============================================================
# HDMI/sensor: data valid 1.2 ns after pixel clock, held for 0.8 ns
set_input_delay -clock clk_pixel -max 1.200 [get_ports {video_r[*] video_g[*] video_b[*]}]
set_input_delay -clock clk_pixel -min 0.800 [get_ports {video_r[*] video_g[*] video_b[*]}]
set_input_delay -clock clk_pixel -max 1.000 [get_ports {video_hsync video_vsync video_de}]
set_input_delay -clock clk_pixel -min 0.500 [get_ports {video_hsync video_vsync video_de}]

# =============================================================
# Output Delays — Processed video output
# =============================================================
set_output_delay -clock clk_pixel -max 2.000 [get_ports {proc_r[*] proc_g[*] proc_b[*]}]
set_output_delay -clock clk_pixel -min 0.500 [get_ports {proc_r[*] proc_g[*] proc_b[*]}]
set_output_delay -clock clk_pixel -max 1.500 [get_ports {proc_hsync proc_vsync proc_de}]
set_output_delay -clock clk_pixel -min 0.300 [get_ports {proc_hsync proc_vsync proc_de}]

# =============================================================
# Multi-Cycle Paths — 3-cycle filter computation
# =============================================================
# The 5x5 convolution kernel requires 3 clock cycles (clk_proc)
# Stage: kernel_load_reg → accumulator → result_reg

set_multicycle_path -setup 3 \
    -from [get_cells -hierarchical pipeline_stage2_reg*] \
    -to   [get_cells -hierarchical kernel_result_reg*]

set_multicycle_path -hold 2 \
    -from [get_cells -hierarchical pipeline_stage2_reg*] \
    -to   [get_cells -hierarchical kernel_result_reg*]

# 2-cycle path for the bilinear interpolation block
set_multicycle_path -setup 2 \
    -from [get_cells -hierarchical interp_in_reg*] \
    -to   [get_cells -hierarchical interp_out_reg*]

set_multicycle_path -hold 1 \
    -from [get_cells -hierarchical interp_in_reg*] \
    -to   [get_cells -hierarchical interp_out_reg*]

# =============================================================
# False Paths
# =============================================================
# Configuration registers written only once at startup
set_false_path -from [get_ports rst_n]
set_false_path -from [get_ports {config_mode[*]}]

# Test output (not timing critical)
set_false_path -to [get_ports {debug_out[*]}]

# =============================================================
# Physical Constraints — Pipeline placement
# =============================================================
# Keep pipeline stages co-located to minimize routing
create_pblock pbl_pipeline
add_cells_to_pblock pbl_pipeline [get_cells -hierarchical {pipeline_*}]
resize_pblock pbl_pipeline -add {CLOCKREGION_X1Y2:CLOCKREGION_X2Y3}
set_property IS_SOFT TRUE [get_pblocks pbl_pipeline]  ; # soft = hint not hard constraint

# =============================================================
# I/O Standards
# =============================================================
set_property IOSTANDARD LVDS [get_ports {pclk_p pclk_n proc_clk_p proc_clk_n}]
set_property IOSTANDARD LVCMOS18 [get_ports {
    video_r[*] video_g[*] video_b[*] video_hsync video_vsync video_de
    proc_r[*]  proc_g[*]  proc_b[*]  proc_hsync  proc_vsync  proc_de
    config_mode[*] debug_out[*] rst_n
}]
