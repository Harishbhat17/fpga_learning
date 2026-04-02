# Case Study 2 — High-Speed I/O Interface Timing Closure (Vivado)

> **Navigation:** [← Vivado README](../README.md) | [STA Index](../../README.md)

---

## Design Overview

**Design:** 10 Gbps LVDS serial interface with 8b/10b encoding  
**Target:** Xilinx UltraScale+ xcku5p-sfvb784-2-e  
**Interface:** 16-lane LVDS at 625 MHz DDR (1.25 Gbps per lane)  
**Core clock:** 312.5 MHz  
**Challenge:** Closing source-synchronous I/O timing with tight strobe windows  

---

## Problem Statement

The initial I/O constraints were estimated from the PCB schematic. After board bring-up, the actual measured trace delays differed from estimates, resulting in:

```
WNS (setup, in2reg): -0.435 ns   Failing I/O paths: 16
WHS (hold,  in2reg):  0.008 ns   (hold barely passing)
```

All 16 failing paths are on the same 16 LVDS receive lanes — systematic offset.

---

## Initial Constraint (Estimated)

```tcl
# Original estimate: 1.5 ns PCB delay
set_input_delay -clock clk_strobe -max 1.500 [get_ports {rx_data[*]}]
set_input_delay -clock clk_strobe -min 0.400 [get_ports {rx_data[*]}]
```

---

## Diagnosis

### Step 1: Check the Timing Path

```
Slack: -0.435 ns
  Required time:  3.400 ns  (period 4.0 ns - t_setup 0.050 ns - uncertainty 0.550 ns)
  Arrival time:   3.835 ns
  Input delay:    1.500 ns  (constraint value)
  Internal path:  2.335 ns  (from pad to FF)
  
  Total (I/O):    3.835 ns  vs required 3.400 ns
```

The internal path from the pad to the first register is 2.335 ns — higher than expected. The IDELAY component was not being used to trim the delay.

### Step 2: Measure Actual Board Delay

Using an oscilloscope with DDR probing:
- Actual PCB trace delay: 2.1 ns (vs 1.5 ns estimated)
- Strobe-to-data offset: 200 ps (data arrives slightly before strobe)

---

## Fix: Implement IDELAY-Based Delay Adjustment

In Xilinx UltraScale devices, the IDELAYE3 primitive allows fine-grained delay adjustment of individual I/O pins in 2.5 ps steps (up to ~512 steps × 2.5 ps = 1.28 ns range):

### Verilog Change

```verilog
// Before: direct connection from IBUFDS to FF
IBUFDS #(.DIFF_TERM("TRUE")) ibuf_inst (
    .I(rx_data_p), .IB(rx_data_n), .O(rx_data_raw)
);
// rx_data_raw → register

// After: add IDELAYE3 for programmable delay trim
IBUFDS #(.DIFF_TERM("TRUE")) ibuf_inst (
    .I(rx_data_p), .IB(rx_data_n), .O(rx_data_raw)
);

IDELAYE3 #(
    .CASCADE("NONE"),
    .DELAY_FORMAT("COUNT"),
    .DELAY_SRC("IDATAIN"),
    .DELAY_TYPE("FIXED"),
    .DELAY_VALUE(50),      // 50 × 2.5 ps = 125 ps initial trim
    .REFCLK_FREQUENCY(300.0)
) idelay_inst (
    .DATAIN(1'b0), .IDATAIN(rx_data_raw),
    .DATAOUT(rx_data_delayed),
    .CLK(clk_idelay), .EN_VTC(1'b1),
    .RST(1'b0), .LOAD(1'b0), .CE(1'b0), .INC(1'b0)
);
// rx_data_delayed → register
```

### XDC Update

```tcl
# Updated input delay constraint after measuring actual board timing
set_input_delay -clock clk_strobe -max 2.100 [get_ports {rx_data[*]}]
set_input_delay -clock clk_strobe -min 1.650 [get_ports {rx_data[*]}]

# Set IDELAY group for each lane (all in same IODELAY group)
set_property IODELAY_GROUP RX_GROUP [get_cells idelay_inst*]

# Reduce setup uncertainty for source-synchronous interfaces
# (source and destination clocks are the same PCB clock)
set_clock_uncertainty -setup 0.300 -from [get_clocks clk_strobe] \
                                   -to   [get_clocks clk_strobe]
```

---

## Results After Fix

```
WNS (setup): +0.127 ns   Failing endpoints: 0
WHS (hold):  +0.215 ns   (improved — IDELAY also helps hold margin)
```

All 16 lanes closed timing with comfortable margin.

---

## Lessons Learned

| Issue | Cause | Fix |
|-------|-------|-----|
| I/O timing failure | PCB delay underestimated by 600 ps | Measure actual delay; update constraints |
| Systematic offset on all lanes | Same PCB routing, same error | IDELAY trim corrects physical delay |
| Setup/hold asymmetry | Data arrives before strobe | Reduce IDELAY value to align edges |

**Key takeaway:** Source-synchronous I/O timing failures are often **measurement problems** before they are design problems. Always validate PCB delay estimates with hardware measurements before aggressive RTL changes.

---

> **See also:** [XDC CDC Example](../examples/cdc_design.xdc) | [Real-World Case Study 4: High-Speed IO](../../Real-World-Case-Studies/Case-Study-4-High-Speed-IO.md)
