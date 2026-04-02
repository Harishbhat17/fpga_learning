# Constraint Writing Best Practices

> **Navigation:** [← STA Index](../README.md)

---

## Golden Rules

### Rule 1: Define All Clocks First

The first thing in every constraint file must be all `create_clock` and `create_generated_clock` commands. Every other constraint depends on clocks being defined.

```tcl
# ✅ CORRECT order:
create_clock -period 10.0 -name clk_sys [get_ports sys_clk]
derive_clock_uncertainty  ; # or set_clock_uncertainty
set_clock_groups -asynchronous -group {clk_sys} -group {clk_eth}
set_input_delay  -clock clk_sys -max 2.0 [get_ports {din[*]}]

# ❌ WRONG — clock used before defined:
set_input_delay -clock clk_sys -max 2.0 [get_ports {din[*]}]  ; # clk_sys not yet defined!
create_clock -period 10.0 -name clk_sys [get_ports sys_clk]
```

---

### Rule 2: Never Leave Ports Unconstrained

Every primary input and output must have either:
- `set_input_delay` / `set_output_delay` with a real timing value, **or**
- `set_false_path` if the port is not time-critical

```tcl
# Find unconstrained ports
check_timing -verbose  ; # Vivado
check_timing -detailed_report on  ; # Quartus

# Fix: add false path for truly asynchronous ports
set_false_path -from [get_ports {status_leds[*]}]  ; # LEDs not time-critical
set_false_path -from [get_ports {dip_switches[*]}] ; # Static config inputs
```

---

### Rule 3: Use -datapath_only for CDC set_max_delay

When constraining CDC synchronizer paths:

```tcl
# ✅ CORRECT — removes clock uncertainty from the check
set_max_delay -datapath_only \
    -from [get_cells src_reg] \
    -to   [get_cells sync_meta_reg] \
    9.0  ; # < dst_period

# ❌ WRONG — without -datapath_only, clock uncertainty is added,
# making the constraint unnecessarily tight
set_max_delay 9.0 \
    -from [get_cells src_reg] \
    -to   [get_cells sync_meta_reg]
```

---

### Rule 4: Always Set the Hold Adjustment for Multi-Cycle Paths

```tcl
# ✅ CORRECT — always pair setup and hold
set_multicycle_path -setup 3 -from FF_src -to FF_dst
set_multicycle_path -hold  2 -from FF_src -to FF_dst  ; # MANDATORY!

# ❌ WRONG — without hold adjustment, hold is checked very tightly
set_multicycle_path -setup 3 -from FF_src -to FF_dst
# Hold will be checked at cycle 2 (setup_cycles - 1 = 2) → may cause hold violations
```

The hold value should be `setup_cycles - 1` in Vivado.

---

### Rule 5: Document Every Exception

```tcl
# ❌ BAD — undocumented false path is a liability
set_false_path -from [get_cells config_reg*]

# ✅ GOOD — clear documentation
# config_reg is written only once during firmware init (synchronous JTAG write),
# then treated as static. Not a timing-critical path during normal operation.
set_false_path -from [get_cells config_reg*]
```

---

### Rule 6: Use Specific Cell/Net Names, Not Wildcards Where Possible

Wildcards (`*`) match unintended cells:

```tcl
# ❌ RISKY — may match more cells than intended
set_false_path -from [get_cells *data*]

# ✅ BETTER — specific hierarchy
set_false_path -from [get_cells u_config/data_reg]

# If wildcards needed, verify matches:
get_cells -hierarchical -filter {NAME =~ *data*} | head -20
```

---

### Rule 7: Constrain at the Port, Not at Internal Nets

```tcl
# ✅ CORRECT — constraint at the top-level port
set_input_delay -clock clk_sys -max 2.0 [get_ports data_in]

# ❌ WRONG — constraining internal net (may be optimized away)
set_input_delay -clock clk_sys -max 2.0 [get_nets data_in_ibuf_net]
```

---

### Rule 8: Validate Constraints with check_timing

Always run `check_timing` after writing constraints:

```tcl
check_timing -verbose
# Expected output includes:
# Info: No timing violations found.
# OR
# Warning: The following X input ports have no input delay constraints:
#   [list of unconstrained ports]
```

---

## Constraint File Template

```tcl
##############################################################
## File: top.xdc
## Design: my_design
## Device: xczu7ev-ffvc1156-2-e
## Frequency: 200 MHz
## Author: [name]
## Last modified: [date]
## Revision history: [brief change log]
##############################################################

# ============================================================
# SECTION 1: Primary Clocks
# ============================================================
create_clock -period 5.000 -name clk_200 [get_ports clk_in_p]
create_clock -period 8.000 -name clk_eth [get_ports eth_clk]

# ============================================================
# SECTION 2: Generated Clocks (MMCM outputs)
# ============================================================
create_generated_clock -name clk_100 \
    -source [get_pins mmcm/CLKIN1] -divide_by 2 [get_pins mmcm/CLKOUT0]

# ============================================================
# SECTION 3: Clock Groups
# ============================================================
set_clock_groups -asynchronous \
    -group [get_clocks {clk_200 clk_100}] \
    -group [get_clocks clk_eth]

# ============================================================
# SECTION 4: Clock Uncertainty
# ============================================================
set_clock_uncertainty -setup 0.100 [get_clocks clk_200]
set_clock_uncertainty -hold  0.050 [get_clocks clk_200]

# ============================================================
# SECTION 5: I/O Delays
# ============================================================
set_input_delay  -clock clk_200 -max 2.000 [get_ports {din[*]}]
set_input_delay  -clock clk_200 -min 0.800 [get_ports {din[*]}]
set_output_delay -clock clk_200 -max 2.500 [get_ports {dout[*]}]
set_output_delay -clock clk_200 -min -0.500 [get_ports {dout[*]}]

# ============================================================
# SECTION 6: Timing Exceptions
# ============================================================
# Reset — async, not time-critical
set_false_path -from [get_ports rst_n]

# Slow control path — 3-cycle MCP
set_multicycle_path -setup 3 -from [get_cells ctrl_reg*] -to [get_cells result_reg*]
set_multicycle_path -hold  2 -from [get_cells ctrl_reg*] -to [get_cells result_reg*]

# ============================================================
# SECTION 7: Physical Constraints
# ============================================================
set_property IOSTANDARD LVCMOS18 [get_ports {din[*] dout[*] rst_n}]
set_property IOSTANDARD DIFF_SSTL12 [get_ports {clk_in_p clk_in_n}]
```

---

> **See also:** [Common Mistakes](Common-Mistakes.md) | [Optimization Checklist](Optimization-Checklist.md)
