# Common Timing Mistakes

> **Navigation:** [← STA Index](../README.md)

The following mistakes are frequently encountered in FPGA timing closure. Each entry describes the mistake, its symptom, and the correct approach.

---

## Mistake 1: Missing Hold Adjustment on Multi-Cycle Paths

**Mistake:**
```tcl
set_multicycle_path -setup 3 -from reg_a -to reg_b
# Hold adjustment forgotten!
```

**Symptom:** Hold violations appear on the multi-cycle path after routing. The hold check is now performed at cycle 2 (one cycle before the relaxed setup edge), which may be tighter than the default 0-cycle hold check.

**Fix:**
```tcl
set_multicycle_path -setup 3 -from reg_a -to reg_b
set_multicycle_path -hold  2 -from reg_a -to reg_b  # ALWAYS include this
```

---

## Mistake 2: Applying set_false_path to a Live CDC Path

**Mistake:**
```tcl
# Declaring a live CDC path as false to silence the CDC warning
set_false_path -from [get_clocks clk_fast] -to [get_clocks clk_slow]
```

**Symptom:** Design works in simulation and on the bench initially, then fails intermittently in production — classic metastability signature.

**Fix:** Use a proper 2-FF synchronizer for single-bit signals, an async FIFO for multi-bit data. Only use `set_false_path` for paths that are **truly** functionally irrelevant (written only during reset, or mux selects that are static).

---

## Mistake 3: Gated Clocks (LUT in Clock Path)

**Mistake:**
```verilog
assign gated_clk = clk & enable;  // Using LUT as clock gating!
reg q;
always @(posedge gated_clk) q <= d;
```

**Symptom:** DRC error `[DRC REQP-52]` in Vivado. Clock timing analysis incorrect. Possible glitches on the gated clock causing metastability.

**Fix:** Use the flip-flop's clock enable input:
```verilog
always_ff @(posedge clk)
    if (enable) q <= d;
```

Or use a dedicated clock buffer with enable (BUFGCE):
```tcl
set_property CLOCK_BUFFER_TYPE BUFGCE [get_nets gated_clk]
```

---

## Mistake 4: Not Using ASYNC_REG on Synchronizer Flip-Flops

**Mistake:**
```verilog
// 2-FF sync without ASYNC_REG attribute
logic meta_r, sync_r;
always_ff @(posedge clk_dst) meta_r <= src_signal;
always_ff @(posedge clk_dst) sync_r <= meta_r;
```

**Symptom:** Vivado may optimize away `meta_r` (it's "redundant"), or place `meta_r` and `sync_r` in different slices, increasing the metastability settling time window between them.

**Fix:**
```verilog
(* ASYNC_REG = "TRUE" *) logic meta_r, sync_r;
always_ff @(posedge clk_dst) meta_r <= src_signal;
always_ff @(posedge clk_dst) sync_r <= meta_r;
```

---

## Mistake 5: Binary Bus Across Asynchronous Domains

**Mistake:**
```verilog
// Binary counter clocked by clk_a, read in clk_b domain
logic [7:0] counter;
always_ff @(posedge clk_a) counter <= counter + 1;
// Directly reading counter in clk_b domain — UNSAFE!
logic [7:0] counter_b;
always_ff @(posedge clk_b) counter_b <= counter;
```

**Symptom:** Random incorrect counter values in clk_b domain. Many bits change simultaneously in binary transitions (e.g., 0111→1000 changes all 4 bits), and if the capture FF samples during transition, it can capture a completely wrong value.

**Fix:** Use Gray code (for pointer/counter) or async FIFO (for data):
```verilog
// Gray-coded counter or async_fifo for data — see CDC section
```

---

## Mistake 6: Constraining Internal Nets Instead of Ports

**Mistake:**
```tcl
set_input_delay -clock clk_sys -max 2.0 [get_nets data_in_ibuf]  # internal net!
```

**Symptom:** `check_timing` warns about unconstrained input ports. The constraint is applied to an internal net that may be optimized away or renamed by synthesis.

**Fix:**
```tcl
set_input_delay -clock clk_sys -max 2.0 [get_ports data_in]  # top-level port
```

---

## Mistake 7: Ignoring Post-Route Hold Violations

**Mistake:** Seeing WHS < 0 after routing and assuming it will be fixed automatically.

**Symptom:** In Vivado, some hold violations ARE fixed automatically by the router (which inserts delay buffers). However, if hold violations remain after routing AND after phys_opt_design, they represent real functional failures.

**Fix:**
```tcl
# After routing, explicitly run hold fix
phys_opt_design -hold_fix -directive AggressiveExplore
report_timing -hold -nworst 10
# Verify WHS ≥ 0 after this step
```

---

## Mistake 8: Setting Clock Period Tighter Than Actually Needed

**Mistake:**
```tcl
# Design needs 200 MHz, but engineer adds extra margin by constraining to 250 MHz
create_clock -period 4.000 -name clk_sys [get_ports clk_in]  # 250 MHz (over-constrained)
```

**Symptom:** Implementation takes much longer (more iterations), may never close, and Vivado uses more aggressive (and potentially less reliable) optimization.

**Fix:** Constrain to your actual target frequency. If you want margin, add 10%:
```tcl
# Target 200 MHz with 10% margin → constrain to 220 MHz = 4.545 ns
create_clock -period 4.545 -name clk_sys [get_ports clk_in]
```

---

## Mistake 9: Not Running check_timing After Writing Constraints

**Mistake:** Writing constraints and proceeding directly to implementation without verifying them.

**Symptom:** Silent timing failures: paths that appear to pass (WNS ≥ 0) but are actually unconstrained and never checked.

**Fix:**
```tcl
check_timing -verbose
# Look for:
# "No timing violations" (good)
# "The following N ports are unconstrained" (action needed)
# "Clock X has no period constraint" (action needed)
```

---

## Mistake 10: Treating -max and -min Input Delay as Independent

**Mistake:**
```tcl
# Setting -max only (forgetting -min) or using wrong signs
set_input_delay -clock clk -max 3.0 [get_ports din]
# Missing -min → hold check unconstrained
```

**Symptom:** Hold timing on input paths is unconstrained or overly optimistic.

**Fix:**
```tcl
# Always set both -max (setup check) and -min (hold check)
set_input_delay -clock clk -max 3.0 [get_ports din]  # setup: latest arrival
set_input_delay -clock clk -min 1.0 [get_ports din]  # hold: earliest arrival
```

---

> **See also:** [Constraint Writing](Constraint-Writing.md) | [Optimization Checklist](Optimization-Checklist.md)
