# Case Study 1 — Image Processing Pipeline Timing Closure (Vivado)

> **Navigation:** [← Vivado README](../README.md) | [STA Index](../../README.md)

---

## Design Overview

**Design:** 8-bit RGB video processing pipeline (sharpening + color correction)  
**Target:** Xilinx UltraScale+ xczu7ev-ffvc1156-2-e  
**Target Frequency:** 150 MHz (clk_proc), 148.5 MHz (clk_pixel)  
**Pipeline Depth:** 6 stages  
**Resources:** 12,400 LUTs, 18,200 FFs, 12 DSP48E2, 4 RAMB36E2  

---

## Problem Statement

After initial implementation with default strategies, the design failed timing:

```
Design Timing Summary
WNS: -1.247 ns   TNS: -87.432 ns   Failing endpoints: 214
WHS:  0.032 ns   THS:   0.000 ns
```

214 setup-failing endpoints with a worst-case violation of −1.247 ns at 150 MHz. The design needs another ~1.25 ns of margin across the critical paths.

---

## Initial Timing Report Analysis

### Worst Setup Path

```
Slack (VIOLATED): -1.247 ns
Source:          sharpen_coeff_reg[7]/C  (clk_proc)
Destination:     color_matrix_out_reg[7]/D
Data Path Delay: 7.913 ns (logic 3.841 ns = 48.5%, route 4.072 ns = 51.5%)
Logic Levels:    11 (LUT6=6 LUT5=2 DSP48E2=1 CARRY8=2)
```

**Key observations:**
1. Logic depth of **11 levels** is far too deep for 150 MHz (target ≤ 6 levels)
2. Two CARRY8 instances in series → ~1 ns of carry chain delay
3. Route delay is also high (51%) → long-distance routing

### Logic-Level Distribution

```
report_design_analysis -logic_level_distribution

Logic Level Distribution (Setup paths):
  Levels  Count    Percentage
  1-3     3,812    42.1%
  4-6     3,901    43.1%   ← most paths in this range (OK for 150 MHz)
  7-9       891     9.8%   ← borderline
  10-12     214     2.4%   ← these are the 214 failing paths
  13+         0     0.0%
```

The 214 failing paths all have 10–12 logic levels — we need to pipeline these.

---

## Diagnosis

### Root Cause 1: Merged Color Correction and Sharpening

The synthesizer merged the sharpening coefficient multiply-accumulate with the color matrix multiplication into a single combinational stage:

```
sharpen_coeff × pixel → [10 LUT levels + 2 carry chains] → color_matrix_out
```

This should have been **two separate pipeline stages** with a register boundary between them.

### Root Cause 2: High Fanout on `coeff_valid`

```
report_high_fanout_nets -fanout_greater_than 100

Net: coeff_valid     Fanout: 312
Net: rst_pipeline_n  Fanout: 8,241  (ignore — reset is special)
```

`coeff_valid` driving 312 FFs creates long routing that adds 0.8 ns to many paths.

---

## Fixes Applied

### Fix 1: RTL Pipelining (Primary Fix)

Added an explicit pipeline register between the sharpening and color correction stages:

```verilog
// Before: single combined stage (too deep)
always_ff @(posedge clk_proc) begin
    color_out <= (sharpen_result * coeff_r) + (sharpen_result * coeff_g);
end

// After: two registered stages
logic [23:0] sharpened;   // intermediate register

always_ff @(posedge clk_proc)
    sharpened <= sharpen_result * sharpen_coeff;   // stage 5

always_ff @(posedge clk_proc)
    color_out <= (sharpened * coeff_r) + (sharpened * coeff_g);  // stage 6
```

This adds one cycle of latency but halves the combinational depth on both halves.

### Fix 2: Fanout Reduction for `coeff_valid`

```verilog
// Replicate coeff_valid across 4 copies to reduce per-copy fanout to ~80
logic coeff_valid_r [0:3];
always_ff @(posedge clk_proc) begin
    for (int i = 0; i < 4; i++)
        coeff_valid_r[i] <= coeff_valid;
end
```

```tcl
# Additionally set MAX_FANOUT attribute
set_property MAX_FANOUT 50 [get_cells coeff_valid_reg]
```

### Fix 3: Improved Implementation Strategy

```tcl
set_property strategy "Performance_ExplorePostRoutePhysOpt" [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]
```

### Fix 4: Pblock for Critical Path Registers

```tcl
create_pblock pbl_sharpening
add_cells_to_pblock pbl_sharpening [get_cells -hierarchical sharpening_*]
resize_pblock pbl_sharpening -add {CLOCKREGION_X1Y2:CLOCKREGION_X1Y3}
```

---

## Results After Fixes

### After Fix 1 (RTL pipelining) + re-run:

```
WNS: -0.312 ns   TNS: -8.241 ns   Failing endpoints: 21
```

Significant improvement — 214 failures down to 21.

### After All Fixes:

```
WNS:  0.118 ns   TNS:   0.000 ns   Failing endpoints: 0
WHS:  0.041 ns   THS:   0.000 ns

Timing closure ACHIEVED at 150 MHz
```

---

## Lessons Learned

| Issue | Root Cause | Fix |
|-------|-----------|-----|
| 11-level logic depth | Two operations merged by synthesis | Explicit pipeline register in RTL |
| High fanout (312) | `coeff_valid` unregistered/unreplicated | Register replication + MAX_FANOUT attribute |
| Route delay 51% | Logic spread across many clock regions | Pblock to co-locate critical registers |
| 214 failing endpoints | Systemic depth issue | RTL restructuring (not just constraint tweaks) |

**Key takeaway:** When TNS is large (−87 ns) with many failing endpoints, the root cause is almost always **RTL architecture** — too much logic in one clock cycle. Constraints alone cannot fix this; the design must be pipelined.

---

> **See also:** [Advanced Pipelining Strategies](../../Advanced-Topics/Pipelining-Strategies.md) | [Real-World Case Study 1](../../Real-World-Case-Studies/Case-Study-1-Image-Processing-Pipeline.md)
