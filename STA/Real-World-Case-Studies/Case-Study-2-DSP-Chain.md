# Case Study 2 — DSP Chain at 250 MHz

> **Navigation:** [← Case Studies README](README.md) | [STA Index](../README.md)

---

## Design Specification

| Parameter | Value |
|-----------|-------|
| Device | Xilinx UltraScale+ xcku5p |
| Function | 32-tap symmetric FIR filter |
| Target | 250 MHz |
| DSP blocks | 16 DSP58E2 |
| Input | 16-bit PCM samples |
| Output | 32-bit filtered output |

---

## Initial Timing Failure

```
WNS: -0.621 ns   TNS: -18.7 ns   Failing endpoints: 31
Clock: clk_dsp (250 MHz, 4 ns period)
```

---

## Diagnosis

### Critical Path

```
Slack: -0.621 ns
From: tap_coeff_reg[7]  (DSP58E2 output register)
To:   partial_sum_reg[7]
Data: 4.621 ns (logic 2.847 ns = 62%, route 1.774 ns = 38%)
Levels: 9  (DSP58E2=1, CARRY8=2, LUT6=4, LUT5=2)
```

**Issue:** The DSP block output `PREG` is not being used — synthesis generated combinational DSP output connected to a carry chain.

### Verification

```tcl
# Check if PREG is enabled on DSP instances
report_property [get_cells -hierarchical -filter {PRIMITIVE_TYPE == DSP58E2}]
# Shows: PREG = 0  ← should be 1 to use internal pipeline register
```

`PREG = 0` means the DSP P output is combinational. The result must travel from the DSP, through 2 CARRY8 stages, before reaching the destination FF — total 4.62 ns at 250 MHz (needs to be < 4.0 ns).

---

## Root Causes

| # | Issue | Effect |
|---|-------|--------|
| 1 | DSP `PREG` not used | 2 extra CARRY8 stages after DSP |
| 2 | Symmetric filter not using DSP accumulate mode | Extra adder LUTs |
| 3 | Fitter seed 1 placed DSP blocks in west, accumulators in center | Long routing |

---

## Fixes

### Fix 1: Enable DSP Pipeline Registers

In RTL, ensure the multiplier output is registered within the DSP block:

```verilog
// Before: synthesis infers PREG=0
logic [31:0] product;
assign product = coeff[i] * sample[i];  // combinational
always_ff @(posedge clk) partial_sum <= partial_sum + product;

// After: two register stages → MREG=1, PREG=1 inferred
logic [31:0] product_r;
always_ff @(posedge clk) product_r <= coeff[i] * sample[i]; // PREG=1 inferred
always_ff @(posedge clk) partial_sum <= partial_sum + product_r;
```

Or use an explicit DSP attribute:
```verilog
(* use_dsp = "yes" *) (* DSP_MODE = "INT24" *)
logic [31:0] mac_result;
```

### Fix 2: Restructure for DSP Accumulate Mode

Xilinx DSP58E2 supports a built-in accumulator (`P = P + A*B`). Use it:

```verilog
// Let synthesis infer DSP accumulate mode
always_ff @(posedge clk) begin
    if (clear_acc)
        accumulator <= '0;
    else
        accumulator <= accumulator + coeff[tap_idx] * sample_delayed;
end
// Synthesis should map accumulator + product → DSP with PREG and ACC
```

### Fix 3: Multi-Cycle Path for Accumulation

Since the FIR filter accumulates over 32 taps (32 clock cycles before outputting the final result), the accumulator-to-output path can be a multi-cycle path:

```tcl
set_multicycle_path -setup 2 \
    -from [get_cells -hierarchical accumulator_reg*] \
    -to   [get_cells -hierarchical output_reg*]
set_multicycle_path -hold 1 \
    -from [get_cells -hierarchical accumulator_reg*] \
    -to   [get_cells -hierarchical output_reg*]
```

### Fix 4: Placement with Pblock

```tcl
# Place DSP blocks and their immediate registers together
create_pblock pbl_fir_core
add_cells_to_pblock pbl_fir_core \
    [get_cells -hierarchical {fir_inst|*}]
resize_pblock pbl_fir_core -add {CLOCKREGION_X2Y2:CLOCKREGION_X3Y4}
```

---

## Results

| Step | WNS (ns) | TNS (ns) | Failing |
|------|---------|---------|---------|
| Initial | −0.621 | −18.7 | 31 |
| After DSP PREG fix | −0.187 | −3.2 | 8 |
| After MCP constraint | +0.042 | 0.0 | 0 |
| After Pblock | **+0.183** | **0.0** | **0** |

Final Fmax: **254.4 MHz** (vs 250 MHz target — 4.4 MHz margin).

---

## Lessons Learned

1. **Always check DSP PREG/MREG** — unused internal pipeline registers waste 1–2 ns of margin
2. **Multi-cycle paths are powerful** for accumulator architectures
3. **DSP blocks need physical co-location** with their accumulation registers

---

> **Next:** [Case Study 3: Memory Controller](Case-Study-3-Memory-Controller.md)
