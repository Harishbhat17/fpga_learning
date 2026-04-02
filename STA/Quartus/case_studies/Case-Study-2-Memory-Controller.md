# Case Study 2 — DDR3 Memory Controller Timing Closure (Quartus)

> **Navigation:** [← Quartus README](../README.md) | [STA Index](../../README.md)

---

## Design Overview

**Design:** DDR3-800 memory controller interface  
**Target:** Intel Arria 10 GX — 10AX115S2F45I2SG  
**DDR3 Speed Grade:** DDR3-800 (400 MHz DDR → 800 Mbps/pin)  
**Data Width:** 32-bit DQ bus (4 bytes)  
**Challenge:** Source-synchronous DQS strobe alignment, read/write leveling  

---

## Problem Statement

After generating the Altera Memory IP and running compilation:

```
Timing Summary:
  clk_mem_write (400 MHz DDR, write path): WNS = -0.312 ns  FAIL
  clk_mem_read  (recovered DQS):           WNS = -0.187 ns  FAIL
  clk_core      (200 MHz user logic):      WNS = +0.241 ns  PASS
```

Both the read and write DDR interfaces failed timing.

---

## Diagnosis

### Write Path

```
Slack (VIOLATED): -0.312 ns
Path: wr_data_reg → I/O output register → DQ[15] pin

  Write clock period: 2.5 ns (400 MHz)
  I/O delay (FPGA output register → pad): 0.412 ns
  PCB delay (estimated): 0.850 ns
  DDR3 tDS setup time: 0.175 ns
  Available margin = 2.5/2 - 0.412 - 0.850 - 0.175 = -0.187 ns ← still negative!
```

The center-aligned write strobe requires that data arrives at the DDR3 DQ pin within `T/2 - tDS = 1.250 - 0.175 = 1.075 ns` of the DQS edge.

Root cause: The PCB trace length to DQ pins was not accounted for. Actual measured trace delay: 1.02 ns (vs 0.85 ns estimated).

### Read Path

```
Slack (VIOLATED): -0.187 ns
Path: DQ[*] pin → IDDR register → clk_rd_domain register

  DQS window at FPGA pin: tDQSH = 0.9 ns (DDR3 guaranteed minimum)
  I/O delay (pin → IDDR): 0.312 ns
  IDDR setup: 0.050 ns
  Available margin = 0.900/2 - 0.312 - 0.050 = 0.088 ns only
```

---

## Fixes

### Fix 1: PCB Trace Length Equalization

Board redesign: equalize all DQ trace lengths to the DQS trace ±50 ps. This is a **PCB change**, not an FPGA change — it reduced write PCB delay from 1.02 ns to 0.90 ns.

### Fix 2: I/O Timing Margin via Output Delay Adjustment

```tcl
# Updated write constraint with measured PCB delay
set_output_delay -clock clk_dqs -max  0.900 [get_ports {dq[*]}]  ;# updated from 0.850
set_output_delay -clock clk_dqs -min -0.300 [get_ports {dq[*]}]

# DQS strobe output
set_output_delay -clock clk_dqs -max  0.100 [get_ports {dqs_p dqs_n}]
set_output_delay -clock clk_dqs -min -0.100 [get_ports {dqs_p dqs_n}]
```

### Fix 3: ALTDQS_CLK Phase Adjustment

Using Quartus IP parameterization, adjust the DQS output phase to center-align it with the DQ data window:

In the Arria 10 EMIF IP:
- DQS-DQ output delay: increased from 0 to +150 ps (DQ arrives before DQS center)

### Fix 4: Read Capture — Enable DQS Phase Training

The Arria 10 EMIF IP includes calibration logic that adjusts read DQS phase at startup. Enable it:
```
Enable Read DQ/DQS Leveling: YES (in IP parameter editor)
```

---

## Results After Fixes

```
clk_mem_write: WNS = +0.089 ns  PASS
clk_mem_read:  WNS = +0.112 ns  PASS (after calibration training)
clk_core:      WNS = +0.241 ns  PASS (unchanged)
```

---

## Lessons Learned

| Issue | Cause | Fix |
|-------|-------|-----|
| Write timing | PCB delay underestimated | PCB trace equalization + updated constraints |
| Read timing | DQS window too small | Enable hardware calibration in IP |
| IP timing | EMIF IP requires calibration | Always enable read/write leveling for DDR3 |

---

> **See also:** [Real-World Memory Controller Case Study](../../Real-World-Case-Studies/Case-Study-3-Memory-Controller.md)
