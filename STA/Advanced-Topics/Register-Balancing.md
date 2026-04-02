# Register Balancing

> **Navigation:** [← STA Index](../README.md)

---

## 1. Introduction

**Register balancing** is the process of ensuring that the number of combinational logic levels between every pair of consecutive registers is approximately equal. An imbalanced pipeline wastes timing margin on fast stages while violating timing on slow stages.

---

## 2. DSP Block Packing

### 2.1 Why DSP Packing Matters

FPGA DSP blocks (DSP48E2 in Xilinx, DSP18 in Intel) have internal pipeline registers. If you do not use them, the DSP block's output must drive fabric logic before reaching the next FF — adding combinational delay. If you do use them, the DSP block contributes zero combinational delay (output is already registered).

```verilog
// BAD: Not using DSP internal registers — long path
logic [31:0] product_comb;
assign product_comb = a * b;     // combinational multiply through DSP
always_ff @(posedge clk)
    result <= product_comb + offset;  // logic sees full DSP + adder delay

// GOOD: Using DSP pipeline registers (2-cycle latency, higher Fmax)
// Inferred when synthesis sees registered multiplier output:
always_ff @(posedge clk) begin
    product_r <= a * b;          // DSP uses P-register (internal pipeline)
end
always_ff @(posedge clk) begin
    result    <= product_r + offset;  // short path (just adder after DSP)
end
```

### 2.2 Inferring DSP Pipeline Registers (Vivado)

Use `MREG` and `PREG` attributes or rely on synthesis inference:

```tcl
# Tell synthesis to infer DSP blocks with input and output registers
set_property USE_DSP yes [get_cells -hierarchical -filter {IS_PRIMITIVE == 0}]
```

Or in RTL:
```verilog
(* use_dsp = "yes" *) logic [31:0] result;
```

---

## 3. LUT Balancing

### 3.1 Detecting Imbalanced LUT Paths

```tcl
# Vivado: find logic-level distribution
report_design_analysis -logic_level_distribution -max_paths 1000

# Output example:
# Levels  Count   Percentage
#   1-4    6,200   68.5%
#   5-7    2,400   26.5%
#   8-10     400    4.4%   ← these are the violating paths
#   11+       34    0.4%   ← these definitely need fixing
```

### 3.2 Balancing by Adding Registers

```verilog
// Before: 9 levels of LUT logic in one stage
always_ff @(posedge clk)
    out <= f(a) & g(b) | h(c) ^ k(d) | m(e) & n(f);

// After: split into two balanced stages (4-5 levels each)
logic tmp1, tmp2;
always_ff @(posedge clk) begin
    tmp1 <= f(a) & g(b) | h(c);      // ~4 levels
    tmp2 <= k(d) | m(e) & n(f);      // ~4 levels
end
always_ff @(posedge clk)
    out <= tmp1 ^ tmp2;               // 1 level
```

---

## 4. Carry Chain Balancing

Carry chains are the most common cause of long paths in arithmetic circuits:

| Bitwidth | CARRY8 stages (Xilinx) | Approx delay | Notes |
|----------|----------------------|--------------|-------|
| 8-bit | 1 | ~60 ps | Usually fine up to 400 MHz |
| 16-bit | 2 | ~120 ps | Fine up to 250 MHz |
| 32-bit | 4 | ~240 ps | May violate at 250 MHz |
| 64-bit | 8 | ~480 ps | Violates above 200 MHz |

For wide adders, break the add into two halves with carry look-ahead:

```verilog
// 64-bit adder with explicit half-carry pipelining
logic [32:0] sum_lo;   // 33-bit (32 data + 1 carry)
logic [31:0] sum_hi;

always_ff @(posedge clk) begin
    sum_lo <= {1'b0, a[31:0]}  + {1'b0, b[31:0]};
    sum_hi <= a[63:32] + b[63:32];  // will add carry in next stage
end

always_ff @(posedge clk) begin
    result <= {sum_hi + sum_lo[32], sum_lo[31:0]};  // combine with carry
end
```

---

## 5. I/O Register Packing

FPGAs provide dedicated I/O registers (IOB registers) adjacent to the I/O pads. Using them reduces the routing distance from pad to first internal register:

```tcl
# Vivado: force I/O registers into IOB
set_property IOB TRUE [get_cells -hierarchical -filter {IS_SEQUENTIAL && IS_PRIMITIIVE}]

# Or per-cell
set_property IOB TRUE [get_cells input_stage_reg]
```

```verilog
// RTL approach: declare top-level I/O registers
(* IOB = "TRUE" *) logic [7:0] data_in_reg;
always_ff @(posedge clk) data_in_reg <= data_in_port;
```

---

## 6. Summary Checklist

```
□ All DSP-using paths use DSP pipeline registers (P-register enabled)?
□ No carry chain > 4 CARRY8 stages on paths violating at target frequency?
□ Logic-level distribution shows < 5% paths at > 8 levels (for 200 MHz)?
□ I/O registers packed into IOBs for high-speed I/O?
□ Report retiming enabled and no unexpected latency changes?
```

---

> **See also:** [Pipelining Strategies](Pipelining-Strategies.md) | [Physical Optimization](Physical-Optimization.md)
