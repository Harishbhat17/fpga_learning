# Case Study 1 — DSP FIR Filter Chain Timing Closure (Quartus)

> **Navigation:** [← Quartus README](../README.md) | [STA Index](../../README.md)

---

## Design Overview

**Design:** 32-tap symmetric FIR filter implemented with 16 DSP blocks (Cyclone V)  
**Target:** Intel Cyclone V SoC — 5CSEBA6U23I7  
**Target Frequency:** 200 MHz (clk_dsp)  
**Input Rate:** 25 Msps (clk_adc = 25 MHz)  
**Resources:** 16 DSP18s, 2,800 ALMs, 4,100 registers  

---

## Problem Statement

Initial compilation with default settings achieved:

```
Fmax Summary:
  clk_dsp: 173.2 MHz (target: 200 MHz) — FAIL
  clk_adc:  48.9 MHz (target:  25 MHz) — PASS

WNS (clk_dsp setup): -0.724 ns
TNS: -31.2 ns  (47 failing endpoints)
```

The DSP clock is 26.8 MHz short of the 200 MHz target.

---

## Initial Analysis

### Critical Path

```
Slack: -0.724 ns
From: tap_product_reg[15] (clk_dsp)
To:   partial_sum_reg[23]  (clk_dsp)

Data Path Delay: 5.724 ns
  tap_product_reg|clk→q:  0.112 ns
  CARRY chain (24-bit):   2.187 ns  ← DOMINANT (38%)
  Net routing:            2.891 ns  (50%)
  LUT delay:              0.534 ns

Logic Levels: 13 (CARRY4=6 LUT3=4 LUT4=2 LUT6=1)
```

**Root causes:**
1. The 24-bit partial sum accumulation uses a CARRY4 chain (Cyclone V uses 4-bit carry primitives vs Xilinx's 8-bit CARRY8), so 24 bits needs 6 CARRY4 stages = significant delay
2. Long routing from the DSP block output across the device (DSP tiles vs logic tiles placement)

### Utilization

```
  ALMs:  2,800 / 41,910 (6.7%)   ← very low utilization
  DSPs:     16 / 112     (14%)
  Registers: 4,100       (very low)
```

Low utilization rules out congestion — the problem is architectural (carry chains + placement).

---

## Diagnosis

### Why the CARRY Chain?

The FIR accumulator was written as a simple behavioral always block:

```verilog
// Original RTL — single-cycle 24-bit accumulation
always_ff @(posedge clk_dsp) begin
    partial_sum <= partial_sum + tap_product;
end
```

`partial_sum + tap_product` where both are 24-bit requires a 24-bit full adder = 6 CARRY4 chains in Cyclone V.

### Why the Long Routing?

The 16 DSP blocks are placed in one physical column (west side of device), but the accumulation registers were placed in the center. The 24-bit result bus must traverse many routing channels.

---

## Fixes

### Fix 1: Pipelined Adder Tree (Primary Fix)

Replace the single accumulation register with a 2-stage carry-save adder:

```verilog
// Stage 1: Add 3 partial products → save/carry form (3:2 reduction)
logic [24:0] sum_s1, carry_s1;
always_ff @(posedge clk_dsp) begin
    sum_s1   <= product_a ^ product_b ^ product_c;
    carry_s1 <= (product_a & product_b) | (product_b & product_c) | (product_a & product_c);
end

// Stage 2: Final carry-propagate add
logic [25:0] result;
always_ff @(posedge clk_dsp) begin
    result <= sum_s1 + carry_s1;
end
```

This breaks the 24-bit carry chain into two 12-bit stages (each requiring only 3 CARRY4 chains).

### Fix 2: Multi-Cycle Path for Accumulation

Since the FIR structure allows accumulating partial products over multiple cycles before the final output:

```tcl
# SDC: 3-cycle accumulation
set_multicycle_path -setup \
    -from [get_registers {*tap_product_reg[*]}] \
    -to   [get_registers {*partial_sum_reg[*]}] \
    3

set_multicycle_path -hold \
    -from [get_registers {*tap_product_reg[*]}] \
    -to   [get_registers {*partial_sum_reg[*]}] \
    2
```

### Fix 3: LogicLock Region

In Quartus Standard, use LogicLock to co-locate the DSP blocks and their accumulation registers:

In the Assignment Editor:
```
New LogicLock Region: "fir_dsp_core"
Assigned cells: fir_inst|tap_product_reg* fir_inst|partial_sum_reg*
Size: Auto-size with 20% margin
```

Or via .qsf:
```
set_instance_assignment -name LOGICLOCK_REGION_SIZE "80 20" -to "fir_inst"
set_instance_assignment -name LOGICLOCK_REGION_ORIGIN "X1 Y1" -to "fir_inst"
```

### Fix 4: Enable Register Retiming

```
set_global_assignment -name PHYSICAL_SYNTHESIS_REGISTER_RETIMING ON
```

This allows the fitter to move registers across the multiplier combinational logic.

---

## Results

### After Fix 1 (Pipelined Adder):

```
WNS: -0.183 ns   Failing: 8 endpoints
Fmax: 193.5 MHz
```

### After All Fixes:

```
WNS: +0.142 ns   Failing: 0 endpoints
WHS: +0.031 ns
Fmax: 208.1 MHz  (8.1 MHz margin above 200 MHz target)
```

Timing closure achieved with comfortable margin.

---

## Lessons Learned

| Issue | Cause | Fix |
|-------|-------|-----|
| 24-bit CARRY chain slow | Single-cycle full accumulation | Carry-save adder tree (pipeline) |
| DSP-to-logic routing | DSP tiles far from logic tiles | LogicLock co-location |
| Fmax 27 MHz below target | Architectural + placement | RTL refactor + placement hint |
| Many failing endpoints | Systemic carry issue | Single RTL change fixed majority |

---

> **See also:** [Advanced Register Balancing](../../Advanced-Topics/Register-Balancing.md) | [Real-World DSP Case Study](../../Real-World-Case-Studies/Case-Study-2-DSP-Chain.md)
