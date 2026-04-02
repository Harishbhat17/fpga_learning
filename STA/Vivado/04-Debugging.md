# 04 — Debugging Timing Failures in Vivado

> **Navigation:** [← 03 Timing Reports](03-Timing-Reports.md) | [Vivado README](README.md)

---

## 1. Systematic Debugging Approach

```
Step 1: Run report_timing_summary
          │
          ├── Setup violations (WNS < 0)?   → Section 2
          ├── Hold violations  (WHS < 0)?   → Section 3
          ├── CDC warnings?                 → Section 4
          └── Pulse-width violations?       → Section 5
```

Always fix **setup** violations before hold — many hold fixes (adding delay) can worsen setup.

---

## 2. Fixing Setup Violations

### 2.1 Diagnosing the Critical Path

```tcl
# Get the 10 worst setup paths with full clock expansion
report_timing -setup -nworst 10 -path_type full_clock_expanded \
              -delay_type max -file worst_setup.rpt
```

For each path, note:
- **Logic levels** — how many combinational stages?
- **Logic delay vs route delay** — which dominates?
- **Cell types** — any CARRY8, DSP, BRAM that are large?
- **Fanout** — any nets driving > 50 loads?

### 2.2 Fix Strategy Decision Tree

```
Logic levels > 6 (at 200MHz)?
  YES → Pipeline the logic (add register stage)
  NO  → Check fanout and route delay

Route delay > 60% of total?
  YES → Check fanout (add MAX_FANOUT attribute or pipeline)
      → Check placement (use Pblock to co-locate)
  NO  → Check individual cell delays

CARRY8 / DSP in critical path?
  YES → See Section 2.5 (carry chain optimization)

All delays small but slack still negative?
  YES → May be clock skew issue; check clock path
```

### 2.3 Pipelining in RTL

Add a register stage to break a long combinational path:

```verilog
// Before: one-cycle 32-bit multiply
module mul_slow (
    input  logic        clk,
    input  logic [15:0] a, b,
    output logic [31:0] result
);
    assign result_comb = a * b;   // too slow at high frequency

    always_ff @(posedge clk)
        result <= result_comb;
endmodule

// After: two-stage pipeline (2-cycle latency, higher Fmax)
module mul_fast (
    input  logic        clk,
    input  logic [15:0] a, b,
    output logic [31:0] result
);
    logic [31:0] stage1;
    // Split 16x16 into two 8x16 partial products
    always_ff @(posedge clk) begin
        stage1 <= {8'b0, a[15:8]} * b + {8'b0, a[7:0]} * b;
    end
    always_ff @(posedge clk)
        result <= stage1;
endmodule
```

### 2.4 Fanout Reduction

High-fanout nets (> 50 loads) create long routing delays because the router must reach many cells:

```tcl
# Check fanout of nets in the critical path
report_timing -of_objects [get_nets -of_objects [get_cells src_reg]] -max_paths 1
```

**RTL fix:** replicate the register:
```verilog
// Replicate a control signal to reduce fanout
logic ctrl_copy_a, ctrl_copy_b;
always_ff @(posedge clk) ctrl_copy_a <= ctrl;  // drives half the loads
always_ff @(posedge clk) ctrl_copy_b <= ctrl;  // drives other half
```

**Constraint fix:**
```tcl
# Tell Vivado to automatically replicate this cell if fanout exceeds 20
set_property MAX_FANOUT 20 [get_cells high_fanout_reg]
```

### 2.5 Carry Chain Optimization

Long carry chains are the most common bottleneck in arithmetic circuits. Each CARRY8 stage adds ~50–60 ps:

```verilog
// 64-bit adder: 8× CARRY8 = ~450 ps carry chain
assign sum = a + b;  // slow at 200+ MHz

// Faster: use DSP blocks which have internal carry chains
// In Vivado, adding a DSP48 pragma:
(* use_dsp = "yes" *) assign sum = a * scale + offset;
```

Or pipeline the addition:
```verilog
// Two-stage carry-save adder
always_ff @(posedge clk) begin
    sum_low  <= a[31:0] + b[31:0];
    carry_r  <= (a[31:0] + b[31:0]) > 32'hFFFFFFFF;  // carry bit
end
always_ff @(posedge clk) begin
    result <= {a[63:32] + b[63:32] + carry_r, sum_low};
end
```

### 2.6 Physical Optimization Commands

```tcl
# After route, run additional physical optimization
phys_opt_design -directive AggressiveExplore

# Force re-placement of specific cells
place_cell problem_cell SLICE_X10Y20

# Check if better placement helps
report_timing -of_objects [get_cells problem_cell]
```

---

## 3. Fixing Hold Violations

Hold violations typically occur after:
- Excessive beneficial clock skew (capture clock too late)
- Very short data paths (combinational delay < hold time + skew)
- CDC path constraints issues

### 3.1 Diagnosing Hold Violations

```tcl
report_timing -hold -nworst 10 -path_type full -delay_type min
```

Hold violation example:
```
Slack (VIOLATED) : -0.022 ns
  Data Delay:  0.165 ns  (logic 0.141 ns = clk2q, route 0.024 ns)
  Clock Skew:  0.205 ns  (capture arrives 0.205 ns later → hurts hold!)
  Hold Time:   0.030 ns
  
  Hold Slack = Data_delay - Hold_time - Skew
             = 0.165 - 0.030 - 0.205 = -0.070 ns VIOLATED
```

### 3.2 Hold Fix Methods

**Method 1: Let the router insert hold buffers automatically**

Vivado's `route_design` automatically fixes hold violations by inserting delay buffers. If hold violations remain after routing:

```tcl
# Post-route physical optimization to fix hold
phys_opt_design -hold_fix -directive AggressiveExplore
```

**Method 2: Multi-cycle path for hold**

If the path is a legitimate multi-cycle path, also set the hold cycle:
```tcl
set_multicycle_path -setup 2 -from FF_src -to FF_dst
set_multicycle_path -hold  1 -from FF_src -to FF_dst  # REQUIRED!
```

**Method 3: Placement to reduce skew**

If skew is the cause (> 200 ps), constrain placement so source and destination FFs are in the same clock region:
```tcl
create_pblock pb_hold_critical
add_cells_to_pblock pb_hold_critical [get_cells {FF_src FF_dst}]
resize_pblock pb_hold_critical -add {CLOCKREGION_X1Y2}
```

---

## 4. Fixing CDC Issues

### 4.1 CDC Violations from report_cdc

```
Violation (COMBO_LOGIC):
  Source clock: clk_fast (250 MHz)
  Dest clock:   clk_slow (100 MHz)
  Path: comb_logic/out -> clk_slow_reg/D
  Issue: Combinational logic between clock domains — no synchronizer present
```

**Fix:** Insert a 2-FF synchronizer (see [CDC section](../CDC-Clock-Domain-Crossing/Synchronization-Techniques.md)):

```verilog
// Two flip-flop synchronizer
module sync_2ff #(parameter WIDTH = 1) (
    input  logic             clk_dst,
    input  logic [WIDTH-1:0] data_in,
    output logic [WIDTH-1:0] data_out
);
    (* ASYNC_REG = "TRUE" *) logic [WIDTH-1:0] meta, sync;
    always_ff @(posedge clk_dst) begin
        meta <= data_in;
        sync <= meta;
    end
    assign data_out = sync;
endmodule
```

The `(* ASYNC_REG = "TRUE" *)` attribute tells Vivado to:
1. Place the two FFs in the same slice (minimizes inter-FF routing)
2. Report them correctly in `report_cdc`
3. Not optimize away the "redundant" register

### 4.2 Suppressing False CDC Warnings

For paths that are genuinely safe (e.g., a configuration register written once during reset):
```tcl
set_false_path -from [get_clocks clk_fast] -to [get_clocks clk_slow]
# OR for a specific path:
set_max_delay -datapath_only 8.0 -from [get_cells cfg_reg*] -to [get_cells sync_meta*]
```

---

## 5. Pulse-Width Violations

```tcl
report_pulse_width -file pulse_width.rpt
```

Pulse-width violations occur when:
- A very high-frequency clock (> 500 MHz) has a pulse width narrower than the FF's minimum spec
- A clock enable signal toggles at a frequency that creates narrow pulses on a gated clock

Fix: Use BUFGCE (clock enable buffer) instead of gated clocks:
```tcl
# Force BUFGCE insertion for gated clock
set_property CLOCK_BUFFER_TYPE BUFGCE [get_nets gated_clock_net]
```

---

## 6. Constraint Debugging

```tcl
# Find paths not covered by any timing constraint
check_timing -verbose

# See what timing exception applies to a specific path
get_timing_paths -from [get_cells src*] -to [get_cells dst*]

# List all false paths
report_exceptions -false_path

# List all multi-cycle paths
report_exceptions -multi_cycle
```

---

## 7. Quick-Reference: Vivado Timing Debug Checklist

```
□ WNS ≥ 0?  If no → report_timing -setup -nworst 20
□ WHS ≥ 0?  If no → report_timing -hold  -nworst 20
□ CDC clean? → report_cdc -details
□ All ports constrained? → check_timing
□ No unconstrained clocks? → report_clocks
□ No DRC errors? → report_drc
□ Logic depth reasonable? → report_design_analysis -logic_level_distribution
□ Fanout acceptable? → report_high_fanout_nets -fanout_greater_than 50
□ Congestion OK? → report_design_analysis -congestion
```

---

> **See also:** [Vivado Scripts](scripts/README.md) | [XDC Examples](examples/README.md) | [Case Studies](case_studies/Case-Study-1-Image-Processing.md)
