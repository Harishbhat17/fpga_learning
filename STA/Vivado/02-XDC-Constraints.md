# 02 — XDC Constraints in Vivado

> **Navigation:** [← 01 Project Setup](01-Project-Setup.md) | [Vivado README](README.md) | [Next: Timing Reports →](03-Timing-Reports.md)

---

## 1. XDC File Overview

Xilinx Design Constraints (XDC) is a superset of the industry-standard Synopsys Design Constraints (SDC) format. Constraints are executed as TCL commands sequentially. The most important rule:

> **Clock constraints must be defined before any other timing constraint that references them.**

---

## 2. Clock Constraints

### 2.1 Primary Clock from Port

```tcl
# Single 200 MHz clock on port clk_in
create_clock -period 5.000 -name clk_200 -waveform {0.000 2.500} [get_ports clk_in]
```

- `-period 5.000` — clock period in nanoseconds (= 200 MHz)
- `-waveform {rise fall}` — defines rising and falling edges (default: 50% duty cycle)
- `[get_ports clk_in]` — the physical top-level port that carries the clock

### 2.2 Generated Clock from MMCM/PLL

```tcl
# MMCM output at 150 MHz derived from 200 MHz input
create_generated_clock \
    -name clk_150 \
    -source [get_pins mmcm_inst/CLKIN1] \
    -multiply_by 3 \
    -divide_by 4 \
    -master_clock clk_200 \
    [get_pins mmcm_inst/CLKOUT0]
```

Vivado also auto-derives MMCM output clocks in most cases, but explicitly defining them gives you control over names used in reports and exceptions.

### 2.3 Multiple Independent Clocks

```tcl
create_clock -period 10.000 -name clk_100 [get_ports sys_clk]
create_clock -period  8.000 -name clk_125 [get_ports eth_clk]
create_clock -period  4.000 -name clk_250 [get_ports adc_clk]

# Declare all three as asynchronous (no fixed phase relationship)
set_clock_groups -asynchronous \
    -group [get_clocks clk_100] \
    -group [get_clocks clk_125] \
    -group [get_clocks clk_250]
```

### 2.4 Virtual Clock for I/O Timing

A virtual clock has no physical source — it represents the clock at an external device:

```tcl
# External DAC runs at 100 MHz, but that clock pin is not in the FPGA
create_clock -period 10.000 -name clk_ext_dac -virtual

set_output_delay -clock clk_ext_dac -max 2.0 [get_ports dac_data[*]]
set_output_delay -clock clk_ext_dac -min 0.5 [get_ports dac_data[*]]
```

---

## 3. I/O Delay Constraints

### 3.1 Input Delay

`set_input_delay` tells Vivado how much of the clock period is consumed **outside the FPGA** on the input path:

```
Board delay
     ├── PCB trace (launch FF to FPGA pad): t_board_delay
     ├── Source FF setup time: t_ext_setup
     └── set_input_delay -max = t_board_delay + t_ext_setup
```

```tcl
# Source-synchronous input: data valid 1.5 ns after rising edge
# Data held for at least 0.8 ns after rising edge
set_input_delay -clock clk_100 -max 1.500 [get_ports adc_data[*]]
set_input_delay -clock clk_100 -min 0.800 [get_ports adc_data[*]]
```

For **both edges** (DDR):
```tcl
set_input_delay -clock clk_100 -max  1.200 -rise [get_ports ddr_dq[*]]
set_input_delay -clock clk_100 -max  1.200 -fall [get_ports ddr_dq[*]]
set_input_delay -clock clk_100 -min  0.300 -rise [get_ports ddr_dq[*]]
set_input_delay -clock clk_100 -min  0.300 -fall [get_ports ddr_dq[*]]
```

### 3.2 Output Delay

```tcl
# Downstream device requires data 2.0 ns before rising edge
# Data must be held for 0.5 ns after rising edge
set_output_delay -clock clk_100 -max  2.000 [get_ports data_out[*]]
set_output_delay -clock clk_100 -min -0.500 [get_ports data_out[*]]
```

Note: negative `-min` output delay means the downstream device allows data to change after the clock edge (hold requirement is relaxed).

---

## 4. Timing Exceptions

### 4.1 False Path

```tcl
# Asynchronous reset — it doesn't carry data so timing is irrelevant
set_false_path -from [get_ports rst_n]

# Test-mode mux output never carries time-critical data in normal operation
set_false_path -through [get_cells test_mux/Y]

# Between two unrelated asynchronous domains
set_false_path -from [get_clocks clk_a] -to [get_clocks clk_b]
```

### 4.2 Multi-Cycle Path

```tcl
# A 32-bit multiplier takes 3 clock cycles to compute
# Registers launching into multiplier: mul_in_reg*
# Registers capturing from multiplier: mul_out_reg*

set_multicycle_path -setup 3 -from [get_cells mul_in_reg*] -to [get_cells mul_out_reg*]
set_multicycle_path -hold  2 -from [get_cells mul_in_reg*] -to [get_cells mul_out_reg*]
# Note: hold adjustment = setup_cycles - 1 = 2
```

### 4.3 Maximum Delay Override

For board-level paths like JTAG where you want to limit total path delay:
```tcl
set_max_delay 20.0 -datapath_only -from [get_ports tdi] -to [get_cells jtag_reg*]
```

`-datapath_only` removes the clock uncertainty and clock skew from the calculation — use only for paths where clocks are truly unrelated.

---

## 5. Clock Uncertainty

```tcl
# Add 150 ps setup margin and 75 ps hold margin on clk_200
set_clock_uncertainty -setup 0.150 [get_clocks clk_200]
set_clock_uncertainty -hold  0.075 [get_clocks clk_200]

# Add uncertainty between two synchronous domains
set_clock_uncertainty -from [get_clocks clk_200] -to [get_clocks clk_150] 0.100
```

---

## 6. Physical Constraints

### 6.1 I/O Standards and Location

```tcl
# Assign I/O standard and pin location
set_property IOSTANDARD LVCMOS33 [get_ports {data_out[*]}]
set_property PACKAGE_PIN T22 [get_ports clk_in]

# LVDS differential pair
set_property IOSTANDARD LVDS    [get_ports {clk_p clk_n}]
set_property DIFF_TERM  TRUE    [get_ports {clk_p clk_n}]
```

### 6.2 Placement Blocks (Pblocks)

```tcl
# Co-locate time-critical registers in one clock region
create_pblock pbl_fast_path
add_cells_to_pblock pbl_fast_path [get_cells -hierarchical fast_logic*]
resize_pblock pbl_fast_path -add {SLICE_X50Y100:SLICE_X99Y149}
```

---

## 7. XDC File Organization Best Practice

```
constraints/
├── top_clocks.xdc         # All create_clock / create_generated_clock
├── top_io_delays.xdc      # All set_input_delay / set_output_delay
├── top_exceptions.xdc     # All set_false_path / set_multicycle_path
├── top_physical.xdc       # IOSTANDARD, LOC, Pblocks
└── top_timing_groups.xdc  # set_clock_groups, set_clock_uncertainty
```

In your Vivado project, add all files to the `constrs_1` fileset. Vivado processes them in alphabetical order by default, so the `top_clocks.xdc` naming ensures clocks are defined first.

---

## 8. Constraint Validation

After writing constraints, validate them before running implementation:

```tcl
open_checkpoint design_synthesized.dcp
read_xdc constraints/top_clocks.xdc
read_xdc constraints/top_io_delays.xdc
read_xdc constraints/top_exceptions.xdc

# Check for unconstrained ports
check_timing -verbose -file constraint_check.rpt

# See what clocks were created
report_clocks

# See what paths are constrained
report_timing_summary -check_timing_verbose
```

Look for warnings like:
- `[Timing 38-316] Clock period '...' not specified` — missing clock constraint
- `[Timing 38-282] The design had unconstrained inputs` — missing input delay

---

> **Next:** [03 — Timing Reports](03-Timing-Reports.md) — How to read and act on Vivado timing reports.
