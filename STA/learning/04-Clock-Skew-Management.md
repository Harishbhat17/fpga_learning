# 04 — Clock Skew Management

> **Navigation:** [← 03 Setup & Hold Analysis](03-Setup-Hold-Analysis.md) | [STA Index](../README.md)

---

## 1. Clock Skew Defined

**Clock skew** is the spatial variation in clock arrival time across registers in the same clock domain. If `FF_A` sees its clock edge at time `T_A` and `FF_B` at time `T_B`, the skew for a path from A to B is:

```
t_skew = T_B - T_A  (positive = destination clock arrives later)
```

As shown in [Setup & Hold Analysis](03-Setup-Hold-Analysis.md):
- Positive skew **helps setup** but **hurts hold**
- Negative skew **hurts setup** and **helps hold**

---

## 2. Sources of Clock Skew

| Source | Magnitude | Controllable? |
|--------|-----------|---------------|
| Clock buffer insertion delay variation | 10–200 ps | Partially (placement) |
| Wire length differences in clock tree | 50–500 ps | Yes (clock tree synthesis) |
| Different clock buffer types (BUFG vs BUFR) | 100–2000 ps | Yes (constraint) |
| Temperature gradient across die | 20–100 ps | No |
| Voltage droops | 10–50 ps | No |

---

## 3. FPGA Clock Distribution Resources

### 3.1 Xilinx UltraScale+ Clock Hierarchy

```
Clock Source (pin, GT, internal oscillator)
        │
        ▼
  MMCM / PLL (jitter cleaning, frequency synthesis)
        │
        ▼
  BUFGCE / BUFGCTRL  (global clock enable, muxing)
        │
        ▼
  Horizontal Clock Rows (H-trees through device)
        │
        ▼
  BUFCE_ROW / BUFCE_LEAF  (regional distribution)
        │
        ▼
  Clock Spines → Local Clock Leaves → FF clock pins
```

**BUFG family** provides balanced, low-skew global distribution. The clock insertion delay is matched across all FFs driven by the same BUFG.

**BUFR / BUFIO** are regional buffers intended for high-speed I/O clock distribution within a single I/O column.

### 3.2 Intel Cyclone V / Arria 10 Clock Hierarchy

```
Clock Input Pin
       │
       ▼
  PLL (up to 5 output clocks per PLL)
       │
       ▼
  Global Clock Network (GCLK — 16 per device)
       │
       ▼
  Regional Clock Network (RCLK — dedicated region coverage)
       │
       ▼
  Local LAB routing → FF clock pins
```

The Quartus fitter automatically promotes clocks to global networks when fan-out exceeds a threshold (typically ~16 FFs).

---

## 4. Clock Jitter

Jitter is the **temporal variation** in the clock edge position from cycle to cycle. Unlike skew (spatial), jitter affects every register equally per cycle.

### 4.1 Types of Jitter

| Type | Description | STA Impact |
|------|-------------|-----------|
| Period jitter | Variation in period from ideal | Setup/hold uncertainty |
| Cycle-to-cycle jitter | Period difference between adjacent cycles | Must be fully budgeted |
| Phase noise | Frequency-domain representation | Converted to peak-to-peak jitter |
| Long-term jitter | Accumulated over many cycles | Relevant for multi-cycle paths |

### 4.2 Jitter in the Timing Equation

The STA tool adds jitter to the clock uncertainty budget:

```
Effective_T_available = T - t_jitter_setup - t_noise_setup - t_user_uncertainty
```

For Vivado, the MMCM jitter is automatically extracted from the MMCM configuration and included in `report_clock_interaction`. You can also add extra margin:

```tcl
set_clock_uncertainty -setup 0.100 [get_clocks clk_200]  ; # add 100 ps margin
```

---

## 5. Clock Domain Crossing and Skew

When two clock domains share a common phase reference (e.g., both derived from the same MMCM), the STA tool can compute the **inter-domain skew** precisely. The tool checks:

1. **Synchronous CDC:** Both domains have a known phase relationship → single-cycle or multi-cycle path check
2. **Asynchronous CDC:** No known relationship → `set_clock_groups -asynchronous` removes the check and requires manual synchronizer insertion (see [CDC section](../CDC-Clock-Domain-Crossing/CDC-Fundamentals.md))

---

## 6. Measuring and Reporting Skew

### 6.1 Vivado

```tcl
# Report worst skew in the design
report_clock_interaction -delay_type min_max -significant_digits 3

# Show the clock network for a specific clock
report_cdc -details

# Inspect clock arrival at specific register
report_timing -from [get_cells src_reg/C] -to [get_cells dst_reg/D] -delay_type min_max
```

The **Clock Skew** field in `report_timing` shows:
```
Clock Skew:                 0.045 ns
  (Path from MMCM to src_reg: 0.312 ns)
  (Path from MMCM to dst_reg: 0.357 ns)
  Skew = 0.357 - 0.312 = +0.045 ns  (helpful for setup)
```

### 6.2 Quartus TimeQuest

```tcl
# Report clock latency and skew
report_clock_fmax_summary

# Detailed clock transfer report between two registers
report_timing -setup -from src_reg -to dst_reg -npaths 1 -detail full_path
```

---

## 7. Strategies to Manage Skew

### 7.1 Use Global Clock Buffers

Always route clocks through global buffers (BUFG in Vivado, GCLK in Quartus) to benefit from matched insertion delays:

```tcl
# Vivado: Force clock onto global buffer
set_property CLOCK_DEDICATED_ROUTE TRUE [get_nets clk_sys]
```

### 7.2 Minimize Clock Gating at Non-Clock Sites

Avoid using LUT-based clock gating — it introduces asymmetric delays. Use dedicated clock enable (CE) inputs on flip-flops instead:

```verilog
// BAD: LUT gate in clock path
assign gated_clk = clk & enable;   // Never do this!

// GOOD: Use FF clock enable
always_ff @(posedge clk) begin
    if (enable)
        q <= d;
end
```

### 7.3 MMCM/PLL Phase Adjustment

If a specific source-to-destination skew is causing systematic hold violations, the MMCM `PHASE_SHIFT` parameter can phase-shift the output clock by a known amount:

```verilog
// Vivado IP: shift output clock by 45 degrees to increase hold margin
// In MMCME4 instantiation:
.CLKOUT0_PHASE(45.0),   // 45-degree phase shift
```

**Caution:** Shifting the clock phase does not help the overall frequency but can redistribute the setup/hold budget.

### 7.4 Pipelining to Reduce Skew Sensitivity

When skew is large relative to the setup margin, add pipeline registers to reduce the combinational depth between FFs (fewer cross-quadrant routing segments → more balanced clock trees within each pipeline stage).

### 7.5 Physical Placement Constraints

Place registers that are timing-critical in the same clock region to minimize differential clock insertion delay:

```tcl
# Vivado: Place a group of registers in a specific region
create_pblock pb_critical
add_cells_to_pblock pb_critical [get_cells -hierarchical critical_path_reg*]
resize_pblock pb_critical -add {CLOCKREGION_X0Y2:CLOCKREGION_X1Y2}
```

---

## 8. Clock Tree Synthesis (CTS) in FPGAs

Unlike ASICs where CTS is a separate step, FPGA tools automatically balance the clock tree during placement. Key concepts:

| FPGA Tool | Clock Tree Feature | User Control |
|-----------|-------------------|--------------|
| Vivado | BUFG/BUFCE hierarchy, automatic leaf insertion | Pblock, `CLOCK_REGION` constraints |
| Quartus | Global/regional clock network, PLL-based distribution | `set_clock_groups`, LAB placement |

### 8.1 Clock Region Budgeting (Vivado)

Each UltraScale device is divided into clock regions (e.g., X0Y0 through X5Y7). Each region can source from at most **12 unique clock nets**. If your design uses too many clocks, Vivado will generate:

```
[Place 30-574] Sub-optimal placement for a clock region
  Only N clocks are available in region X2Y3, but M are required.
```

Resolution: merge functionally related clocks, use `set_clock_groups` to limit relationships, or change the floor plan.

---

## 9. Summary

| Concept | Key Takeaway |
|---------|-------------|
| Skew | Destination arrives later → helps setup, hurts hold |
| Jitter | Random cycle-to-cycle variation → included in uncertainty budget |
| BUFG | Use global buffers for balanced, low-skew distribution |
| MMCM phase | Can shift phase to redistribute setup/hold budget |
| Pblocks | Co-locate critical registers to minimize differential clock delay |
| Clock regions | Each region has limited clock net capacity; budget carefully |

---

> **Back to:** [STA Index](../README.md) | Continue with [Vivado Workflows](../Vivado/README.md) or [Quartus Workflows](../Quartus/README.md)
