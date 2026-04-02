# Case Study 1 — Image Processing Pipeline

> **Navigation:** [← Case Studies README](README.md) | [STA Index](../README.md)

---

## Design Specification

| Parameter | Value |
|-----------|-------|
| Device | Xilinx UltraScale+ xczu7ev |
| Function | Real-time RGB sharpening + histogram equalization |
| Resolution | 1920×1080 at 60 fps |
| Pixel clock | 148.5 MHz |
| Processing clock | 150 MHz |
| Pipeline stages | 6 |

---

## Initial Timing Failure

After first implementation with default Vivado settings:

```
Design Timing Summary
WNS:  -1.247 ns   TNS:  -87.432 ns   Failing endpoints: 214
WHS:   0.032 ns   THS:    0.000 ns
Clock: clk_proc (150 MHz)
```

---

## Diagnosis (Step by Step)

### Step 1: Logic Level Distribution

```tcl
report_design_analysis -logic_level_distribution
```

```
Logic Levels  Count   %
1–4            4,100  45%
5–7            3,200  35%
8–10           1,700  19%   ← borderline at 150 MHz
11–13            214   2%   ← ALL failing paths
14+                0   0%
```

All 214 violations are paths with 11–13 logic levels. Target for 150 MHz is ≤ 10 levels.

### Step 2: Critical Path Analysis

```tcl
report_timing -setup -nworst 5 -path_type full_clock_expanded
```

```
Path 1: -1.247 ns
  Source:  sharpen_kernel_reg[8]/C
  Dest:    hist_accum_reg[15]/D
  Data:    6.247 ns total (logic 2.847 ns, route 3.400 ns)
  Levels:  11 (LUT6×5, LUT5×2, CARRY8×2, DSP48E2×1, MUXF8×1)
```

**Finding:** The sharpening output feeds directly into the histogram accumulator in one combinational stage — these are two different algorithmic operations that should be separate pipeline stages.

### Step 3: Fanout Analysis

```tcl
report_high_fanout_nets -fanout_greater_than 100
```

```
Net               Fanout  Clock
pixel_valid_r     312     clk_proc   ← very high
line_start_r      198     clk_proc
frame_start_r     156     clk_proc
```

`pixel_valid_r` has 312 loads. The routing tree for this net adds ~0.7 ns to every path it touches.

---

## Root Cause Summary

| # | Root Cause | Impact |
|---|-----------|--------|
| 1 | Sharpening + histogram in one stage | 11-level critical paths |
| 2 | pixel_valid_r fanout = 312 | 0.7 ns penalty on touching paths |
| 3 | Default placement strategy | Suboptimal placement of kernel logic |

---

## Fixes Applied

### Fix 1: Add Pipeline Stage Between Sharpening and Histogram

```verilog
// Before: combined in one stage
always_ff @(posedge clk_proc) begin
    hist_bin <= sharpen_filter(pixel_in) >> 3;  // 11 LUT levels
end

// After: explicit pipeline boundary
logic [7:0] sharpened_pixel;
always_ff @(posedge clk_proc)
    sharpened_pixel <= sharpen_filter(pixel_in);  // Stage 5: 6 levels

always_ff @(posedge clk_proc)
    hist_bin <= sharpened_pixel >> 3;             // Stage 6: 4 levels
```

This adds one cycle of latency (total pipeline latency: 6 → 7 cycles) but dramatically reduces the critical path.

### Fix 2: Register Replication for pixel_valid

```verilog
// Create 4 copies to reduce per-copy fanout to ~80
logic pixel_valid_r [0:3];
generate
    for (genvar i = 0; i < 4; i++) begin : valid_replication
        always_ff @(posedge clk_proc)
            pixel_valid_r[i] <= pixel_valid;
    end
endgenerate

// Assign each copy to a bank of downstream logic
// (or let synthesis tool assign automatically with MAX_FANOUT)
```

```tcl
set_property MAX_FANOUT 50 [get_cells pixel_valid_reg]
```

### Fix 3: Implementation Strategy

```tcl
set_property strategy "Performance_ExplorePostRoutePhysOpt" [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
```

---

## Results

| Step | WNS (ns) | TNS (ns) | Failing Paths |
|------|---------|---------|---------------|
| Initial | −1.247 | −87.432 | 214 |
| After Fix 1 (RTL pipeline) | −0.312 | −8.241 | 21 |
| After Fix 1+2 (fanout) | −0.089 | −1.247 | 7 |
| After All Fixes | **+0.118** | **0.000** | **0** |

---

## Lessons Learned

1. **Check logic levels first** — always the fastest path to the root cause
2. **High fanout (>100) kills timing** — replicate or add MAX_FANOUT attribute
3. **RTL pipelining beats constraint tweaking** — constraints cannot reduce combinational depth
4. **One additional pipeline stage often fixes 90% of violations** in a systemic problem

---

> **Next:** [Case Study 2: DSP Chain](Case-Study-2-DSP-Chain.md)
