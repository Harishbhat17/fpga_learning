# Case Study 3 — DDR4 Memory Controller

> **Navigation:** [← Case Studies README](README.md) | [STA Index](../README.md)

---

## Design Specification

| Parameter | Value |
|-----------|-------|
| Device | Xilinx UltraScale+ xczu7ev |
| Interface | DDR4-2133 (1066 MHz, 2133 Mbps/pin) |
| Width | 64-bit data bus + 8-bit ECC |
| User clock | 266 MHz (1/4 of DDR4 rate) |
| Challenge | Source-synchronous read/write I/O timing |

---

## Initial Status

Using Xilinx MIG (Memory IP Generator) for DDR4, initial compilation produced:

```
WNS (user domain, setup):  +0.312 ns  PASS
WNS (PHY read capture):    -0.142 ns  FAIL  ← read data eye timing
WNS (PHY write):           -0.089 ns  FAIL  ← write DQS-to-DQ alignment
WHS (user domain):         +0.024 ns  PASS
```

---

## Read Path Failure Analysis

### DDR4 Read Timing Model

```
         DQ strobe window at FPGA input
         │←── tDQSH/2 ──→│
         │               │
DQS edge ─┼───────────────┼─  (nominal center)
         │               │
DQ valid ─────────────────────  (DQ data)
         │←── tDQS_valid →│

Available setup window = tDQSH/2 - t_FPGA_IO_setup = 0.45 ns - 0.05 ns = 0.40 ns
Actual timing path:  0.40 + 0.142 ns = 0.542 ns budget but path takes 0.542 ns
                     → Exactly no margin (violation due to pessimism in tool model)
```

### Vivado Timing Report (Read Path)

```
Slack: -0.142 ns
Source: DQ[23] (input pad)
Dest:   PHY_RD_FIFO/din_reg[23]/D

Data Path:
  DQ[23] pad → IBUF         0.312 ns  (pad to IBUF output)
  IBUF → IDELAYE3/IDATAIN    0.041 ns  (short net)
  IDELAYE3 tap delay         0.000 ns  (default: 0 taps)
  IDELAYE3/DATAOUT → IDDR/D  0.124 ns
  IDDR setup time            0.050 ns
  Total:                     0.527 ns

  Required window (DQS-based): 0.385 ns
  Slack: 0.385 - 0.527 = -0.142 ns
```

---

## Write Path Failure Analysis

```
Slack: -0.089 ns
Path: write_data_reg[23] → ODELAYE3 → OBUF → DQ[23] pad

The write DQS strobe is launched at the same time as data,
but DQ must arrive at DDR4 tDS = 175 ps before the DQS edge.

Measured board delay difference: DQS arrives 1.8 ns after FPGA FF,
DQ[23] arrives 1.8 + 0.089 ns (90 ps longer trace)
→ DQ[23] is 90 ps too late
```

---

## Fixes

### Fix 1: IDELAYE3 Calibration for Read Path

The `IDELAYE3` primitive can add programmable delay in 2.5 ps steps to center the DQ sampling within the DQS eye:

```tcl
# Calculate required IDELAY tap count:
# Target: center DQ within DQS eye
# DQS period: 1/1066 MHz = 0.938 ns → quarter period = 0.234 ns
# Need to delay DQ by 0.142 ns (the violation amount) → 0.142/0.0025 = 57 taps

# Apply in XDC:
set_property IDELAY_VALUE 57 [get_cells -hierarchical *IDELAYE3* \
    -filter {NAME =~ *dq23*}]
```

In practice, the MIG IP includes automatic calibration that sets this at runtime. Verify calibration is enabled:
```
In MIG IP: "Enable Dynamic DQS Phase Detection" = YES
```

### Fix 2: Output Delay Correction for Write Path

Board measurement confirmed DQ[23] trace is 90 ps longer than DQS. Add ODELAYE3:

```tcl
# XDC: set output delay element
set_property ODELAY_VALUE 36 [get_cells -hierarchical *ODELAYE3* \
    -filter {NAME =~ *dq23*}]
# 36 taps × 2.5 ps = 90 ps — advances DQ by 90 ps
```

### Fix 3: PCB Fix (Long Term)

For production hardware revision: equalize DQ[23] trace length with DQS trace (±50 ps tolerance across all bits).

---

## Results

```
WNS (PHY read capture):    +0.089 ns  PASS (fixed with IDELAY)
WNS (PHY write):           +0.023 ns  PASS (fixed with ODELAY)
WNS (user domain):         +0.312 ns  PASS (unchanged)
```

---

## Key DDR4 Timing Rules

| Rule | Value | Purpose |
|------|-------|---------|
| tDQS_valid window | ±0.4 ns | DQ must change within this window |
| Max trace length mismatch | ±50 ps | Between DQ bits in same byte lane |
| tDS (DQ setup to DQS) | 175 ps min | DDR4-2133 spec |
| IDELAY resolution | 2.5 ps/tap | UltraScale+ |
| Max IDELAY range | 1.28 ns | 512 taps × 2.5 ps |

---

> **Next:** [Case Study 4: High-Speed IO](Case-Study-4-High-Speed-IO.md)
