# 02 — SDC Constraints in Quartus

> **Navigation:** [← 01 Project Setup](01-Project-Setup.md) | [Quartus README](README.md) | [Next: TimeQuest Analyzer →](03-TimeQuest-Analyzer.md)

---

## 1. SDC File Basics

Quartus TimeQuest uses **SDC (Synopsys Design Constraints)** — the same format as Vivado's XDC core, but without the Xilinx-specific extensions. The same fundamental commands apply:
- `create_clock` / `create_generated_clock`
- `set_input_delay` / `set_output_delay`
- `set_false_path` / `set_multicycle_path` / `set_max_delay`
- `set_clock_uncertainty` / `set_clock_groups`

---

## 2. Clock Constraints

### 2.1 Primary Clock

```tcl
# 100 MHz system clock on port sys_clk
create_clock -period 10.000 -name clk_sys [get_ports sys_clk]

# 50 MHz derived — but NOT from a PLL, just a divider FF (use generated clock)
# Note: if the 50 MHz clock goes through a PLL, use create_generated_clock instead
```

### 2.2 PLL Output Clock

```tcl
# PLL takes 50 MHz reference, outputs 200 MHz
# The PLL output port: altera_pll_inst|altera_pll_i|general[0].gpll~FRACTIONAL_PLL|vcoph[0]
# Typically Quartus auto-generates this, but you can override:

create_generated_clock \
    -name clk_200 \
    -source [get_ports refclk] \
    -multiply_by 4 \
    [get_pins pll_inst|clk_200_output]
```

In practice, Quartus auto-creates generated clock constraints for PLL outputs. To see them:
```tcl
# In TimeQuest TCL console:
report_clocks
```

### 2.3 Clock Groups

```tcl
# Three independent asynchronous clocks
set_clock_groups -asynchronous \
    -group { clk_sys } \
    -group { clk_dsp } \
    -group { clk_eth }
```

### 2.4 Derive Clock Uncertainty (Recommended)

Quartus provides a special command to automatically derive jitter from PLL characterization:

```tcl
# Derive PLL output jitter from device models (recommended over manual set_clock_uncertainty)
derive_pll_clocks -create_base_clocks

# Also derive uncertainty based on device timing models
derive_clock_uncertainty
```

This is the **Quartus best practice** — always call `derive_pll_clocks` and `derive_clock_uncertainty` after defining your clocks.

---

## 3. I/O Delay Constraints

### 3.1 Input Delay

```tcl
# Data valid 2 ns after rising edge, held for 1 ns after rising edge
set_input_delay -clock clk_sys -max 2.000 [get_ports {data_in[*]}]
set_input_delay -clock clk_sys -min 1.000 [get_ports {data_in[*]}]
```

### 3.2 Output Delay

```tcl
# Downstream requires data 3 ns before rising edge, hold 0.5 ns after
set_output_delay -clock clk_sys -max 3.000 [get_ports {data_out[*]}]
set_output_delay -clock clk_sys -min -0.500 [get_ports {data_out[*]}]
```

### 3.3 Source-Synchronous I/O

```tcl
# Source-synchronous input: the clock comes with the data (e.g., RGMII)
create_clock -period 8.000 -name clk_data_in [get_ports rx_clk]

set_input_delay -clock clk_data_in -max 1.000 [get_ports {rxd[*]}]
set_input_delay -clock clk_data_in -min -1.000 [get_ports {rxd[*]}]
```

---

## 4. Timing Exceptions

### 4.1 False Path

```tcl
# Async reset — no timing check
set_false_path -from [get_ports rst_n]

# Between unrelated domains
set_false_path -from [get_clocks clk_a] -to [get_clocks clk_b]

# Specific cell instances
set_false_path -from [get_cells cfg_latch*]
```

### 4.2 Multi-Cycle Path

```tcl
# 3-cycle path: setup check at cycle 3, hold check at cycle 2
set_multicycle_path -setup -from [get_cells slow_div_in*] \
                           -to   [get_cells slow_div_out*] 3
set_multicycle_path -hold  -from [get_cells slow_div_in*] \
                           -to   [get_cells slow_div_out*] 2

# Note: In Quartus, the hold adjustment value means "hold is checked at
# (setup_cycles - hold_value) = 3 - 2 = 1 cycle before the setup edge"
# This is the same as Vivado's convention.
```

### 4.3 Maximum Delay

```tcl
# Allow 20 ns for JTAG paths (not speed-critical)
set_max_delay -from [get_ports tck] -to [get_cells jtag_ff*] 20.0
```

---

## 5. SDC File Structure Best Practice

```tcl
##############################################
## File: top.sdc
## Project: my_design
## Description: Top-level timing constraints
##############################################

# -------------------------------------------
# 1. Derive PLL clocks (MUST be first for Quartus)
# -------------------------------------------
derive_pll_clocks -create_base_clocks

# -------------------------------------------
# 2. Primary (non-PLL) clocks
# -------------------------------------------
create_clock -period 10.000 -name clk_sys  [get_ports sys_clk]
create_clock -period  8.000 -name clk_eth  [get_ports eth_rx_clk]

# -------------------------------------------
# 3. Clock groups
# -------------------------------------------
set_clock_groups -asynchronous \
    -group { clk_sys } \
    -group { clk_eth }

# -------------------------------------------
# 4. Derive clock uncertainty (after all clocks defined)
# -------------------------------------------
derive_clock_uncertainty

# -------------------------------------------
# 5. I/O delays
# -------------------------------------------
set_input_delay  -clock clk_sys -max 2.0 [get_ports {din[*]}]
set_input_delay  -clock clk_sys -min 1.0 [get_ports {din[*]}]
set_output_delay -clock clk_sys -max 3.0 [get_ports {dout[*]}]
set_output_delay -clock clk_sys -min 0.0 [get_ports {dout[*]}]

# -------------------------------------------
# 6. Exceptions
# -------------------------------------------
set_false_path -from [get_ports rst_n]
set_multicycle_path -setup 2 -from [get_cells mul_reg*] -to [get_cells result_reg*]
set_multicycle_path -hold  1 -from [get_cells mul_reg*] -to [get_cells result_reg*]
```

---

## 6. Validating SDC Constraints

```tcl
# In TimeQuest Timing Analyzer TCL console:
# Check for unconstrained clocks/paths
check_timing

# Verify all clocks are defined
report_clocks

# Check which exceptions are in effect
report_exceptions -all
```

Common validation messages to look for:
- `Critical Warning: No output delay constraint found` — missing `set_output_delay`
- `Warning: Found X input ports not constrained for setup/hold` — missing `set_input_delay`
- `Info: Timing requirements are met` — all paths pass

---

> **Next:** [03 — TimeQuest Analyzer](03-TimeQuest-Analyzer.md) — GUI walkthrough and advanced reporting commands.
