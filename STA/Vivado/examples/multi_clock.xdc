## multi_clock.xdc
## XDC constraints for a design with multiple independent clock domains
## Design has: clk_sys (100 MHz), clk_dsp (250 MHz), clk_eth (125 MHz)
## All clocks are asynchronous to each other (different PLLs, no phase lock)

# =============================================================
# Primary Clocks
# =============================================================
# System clock: 100 MHz — main control and data path clock
create_clock -period 10.000 -name clk_sys  -waveform {0.000 5.000} [get_ports sys_clk_p]

# DSP clock: 250 MHz — high-speed compute core
create_clock -period  4.000 -name clk_dsp  -waveform {0.000 2.000} [get_ports dsp_clk_p]

# Ethernet clock: 125 MHz — recovered from GbE PHY
create_clock -period  8.000 -name clk_eth  -waveform {0.000 4.000} [get_ports eth_rx_clk]

# =============================================================
# Clock Groups — Declare asynchronous relationships
# =============================================================
# All three clocks are from independent sources — no phase relationship
set_clock_groups -asynchronous \
    -group [get_clocks clk_sys] \
    -group [get_clocks clk_dsp] \
    -group [get_clocks clk_eth]

# Note: This removes all inter-domain timing checks.
# You MUST ensure proper CDC synchronizers are in place (see CDC examples).

# =============================================================
# Clock Uncertainty (per clock domain)
# =============================================================
# System clock: board oscillator — low jitter
set_clock_uncertainty -setup 0.080 [get_clocks clk_sys]
set_clock_uncertainty -hold  0.040 [get_clocks clk_sys]

# DSP clock: high-frequency PLL output — slightly higher jitter
set_clock_uncertainty -setup 0.120 [get_clocks clk_dsp]
set_clock_uncertainty -hold  0.060 [get_clocks clk_dsp]

# Ethernet clock: recovered clock — highest jitter
set_clock_uncertainty -setup 0.200 [get_clocks clk_eth]
set_clock_uncertainty -hold  0.100 [get_clocks clk_eth]

# =============================================================
# Input Delays — clk_sys domain
# =============================================================
set_input_delay -clock clk_sys -max 3.000 [get_ports {cpu_data[*]}]
set_input_delay -clock clk_sys -min 1.000 [get_ports {cpu_data[*]}]
set_input_delay -clock clk_sys -max 2.500 [get_ports {cpu_addr[*]}]
set_input_delay -clock clk_sys -min 0.800 [get_ports {cpu_addr[*]}]

# =============================================================
# Input Delays — clk_eth domain (source-synchronous)
# =============================================================
# RGMII: data valid 1 ns before/after clock edge (DDR)
set_input_delay -clock clk_eth -max  1.000 -rise [get_ports {rgmii_rxd[*]}]
set_input_delay -clock clk_eth -max  1.000 -fall [get_ports {rgmii_rxd[*]}]
set_input_delay -clock clk_eth -min -1.000 -rise [get_ports {rgmii_rxd[*]}]
set_input_delay -clock clk_eth -min -1.000 -fall [get_ports {rgmii_rxd[*]}]

# =============================================================
# Output Delays — clk_sys domain
# =============================================================
set_output_delay -clock clk_sys -max 4.000 [get_ports {result_data[*]}]
set_output_delay -clock clk_sys -min 1.000 [get_ports {result_data[*]}]

# =============================================================
# Output Delays — clk_eth domain (RGMII transmit, DDR)
# =============================================================
set_output_delay -clock clk_eth -max  1.000 -rise [get_ports {rgmii_txd[*]}]
set_output_delay -clock clk_eth -max  1.000 -fall [get_ports {rgmii_txd[*]}]
set_output_delay -clock clk_eth -min -1.000 -rise [get_ports {rgmii_txd[*]}]
set_output_delay -clock clk_eth -min -1.000 -fall [get_ports {rgmii_txd[*]}]

# =============================================================
# False Paths
# =============================================================
set_false_path -from [get_ports rst_n]
set_false_path -from [get_ports {config_reg[*]}]  ; # written only during init

# =============================================================
# I/O Standards
# =============================================================
set_property IOSTANDARD LVCMOS18 [get_ports {cpu_data[*] cpu_addr[*] result_data[*]}]
set_property IOSTANDARD LVCMOS25 [get_ports {rgmii_rxd[*] rgmii_txd[*] eth_rx_clk}]
set_property IOSTANDARD DIFF_SSTL12 [get_ports {sys_clk_p sys_clk_n}]
set_property IOSTANDARD DIFF_SSTL12 [get_ports {dsp_clk_p dsp_clk_n}]
