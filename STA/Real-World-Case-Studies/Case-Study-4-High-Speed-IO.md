# Case Study 4 — High-Speed LVDS I/O Interface

> **Navigation:** [← Case Studies README](README.md) | [STA Index](../README.md)

---

## Design Specification

| Parameter | Value |
|-----------|-------|
| Device | Xilinx UltraScale+ xcku5p |
| Interface | 10G LVDS link (8b/10b encoded) |
| Bit rate | 10 Gbps (1 Gbps per lane × 10 lanes) |
| Serialization | 8:1 SERDES (625 MHz DDR × 2 = 1.25 Gbps/lane) |
| Capture clock | 625 MHz |
| Challenge | Source-synchronous skew, IDELAY alignment |

---

## Initial Status

```
WNS (clk_625MHz, setup): -0.312 ns   FAIL  ← SERDES deserializer
WNS (clk_312MHz, setup):  +0.142 ns  PASS  ← Core logic
WHS (all domains):         +0.018 ns  PASS
```

---

## Architecture

```
External LVDS Source
    │
    ↓
IBUFDS (differential input buffer)
    │
    ↓
IDELAYE3 (programmable delay, 2.5ps steps)
    │
    ↓
ISERDESE3 (1:8 deserializer)
    │ (8-bit parallel at 78.125 MHz)
    ↓
FIFO (elastic buffer, 625MHz → 312MHz crossing)
    │
    ↓
Core Logic (312 MHz)
```

---

## Diagnosis

### SERDES Input Timing Failure

The ISERDESE3 has a setup requirement of 50 ps from the data input to the clock edge (internal strobe). The margin is squeezed by:

1. **IBUFDS delay variation** across 10 lanes: ±150 ps (due to PCB skew)
2. **Source clock jitter** at the FPGA input: ±100 ps
3. **IDELAY at 0 taps** — not compensating for lane-to-lane PCB skew

```
Available window at 625 MHz: 1/625MHz / 2 = 0.800 ns (half period, DDR)
IBUFDS delay:         0.450 ns
IDELAYE3 (0 taps):    0.000 ns
ISERDESE3 setup:      0.050 ns
Clock uncertainty:    0.100 ns
                    ----------
Total consumed:       0.600 ns
Remaining margin:     0.800 - 0.600 = +0.200 ns  (nominal)
```

But with maximum PCB skew (lane N is 150 ps slower than lane 0):
```
IBUFDS + PCB skew:    0.450 + 0.150 = 0.600 ns
+ ISERDESE3 + clk_unc: 0.150 ns
Total:                0.750 ns → Margin = 0.800 - 0.750 = 0.050 ns
                      → Tool pessimism makes this -0.312 ns
```

---

## Root Causes

| # | Cause | Effect |
|---|-------|--------|
| 1 | PCB lane skew ±150 ps uncompensated | Eats into 800 ps window |
| 2 | IDELAY at default 0 taps | Not centering data in clock eye |
| 3 | Source clock jitter not characterized | Uncertainty over-budgeted by 50 ps |

---

## Fixes

### Fix 1: Per-Lane IDELAY Calibration

Measure PCB delay for each lane during board characterization. Then set IDELAY values in XDC:

```tcl
# Example measured delays (in IDELAY tap counts, 1 tap = 2.5 ps):
# Lane 0: 0 ps skew (reference) → 0 taps
# Lane 1: +45 ps → 18 taps (to compensate, delay = 45/2.5 = 18 taps)
# Lane 2: -30 ps → will need 0 taps + phase shift
# ... etc.

set_property IDELAY_VALUE 18 [get_cells rx_idelaye3_lane1]
set_property IDELAY_VALUE  0 [get_cells rx_idelaye3_lane2]
# ...
```

### Fix 2: Enable Automatic IDELAY Training

The design includes a IDELAYCTRL primitive for voltage/temperature compensation:

```tcl
# Ensure IDELAYCTRL is present in each bank that uses IDELAY
# Verify in Vivado design flow:
report_drc -checks {PDRC-28}
# PDRC-28 checks for missing IDELAYCTRL
```

### Fix 3: Reduce Clock Uncertainty

After measuring actual source clock jitter with a real-time spectrum analyzer:
- Measured peak-to-peak jitter: 85 ps (vs 100 ps assumed)

```tcl
# Update clock constraint with measured jitter
create_clock -period 1.600 -name clk_625 [get_ports lvds_clk_p]
set_clock_uncertainty -setup 0.085 [get_clocks clk_625]  # actual jitter
```

---

## Results

```
WNS (clk_625MHz, setup): +0.124 ns  PASS
WNS (clk_312MHz, setup): +0.142 ns  PASS (unchanged)
WHS:                     +0.018 ns  PASS (unchanged)
```

---

## Lessons Learned

1. **Per-lane PCB skew must be characterized** — cannot be estimated
2. **IDELAY is for alignment, not just timing** — use it to compensate board-level variation
3. **Measure actual jitter** — conservative estimates waste precious margin at high speeds
4. **Always instantiate IDELAYCTRL** in every I/O bank using IDELAY

---

> **Next:** [Case Study 5: Multi-Clock SoC](Case-Study-5-Multi-Clock-System.md)
