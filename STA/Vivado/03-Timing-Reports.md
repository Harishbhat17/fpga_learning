# 03 — Timing Reports in Vivado

> **Navigation:** [← 02 XDC Constraints](02-XDC-Constraints.md) | [Vivado README](README.md) | [Next: Debugging →](04-Debugging.md)

---

## 1. The Timing Summary Report

`report_timing_summary` is the primary pass/fail indicator. Run it on the post-route checkpoint:

```tcl
report_timing_summary -max_paths 10 -report_unconstrained -file timing_summary.rpt
```

### 1.1 Key Sections

```
Design Timing Summary
=====================
WNS(ns)    TNS(ns)    TNS Failing Endpoints    TNS Total Endpoints
  0.142      0.000                         0               24,831

WHS(ns)    THS(ns)    THS Failing Endpoints    THS Total Endpoints
  0.018      0.000                         0               24,831

WPWS(ns)   TPWS(ns)   TPWS Failing Endpoints   TPWS Total Endpoints
  0.000      0.000                         0               24,831

No timing violations were found.
```

**Pass criteria:**
- `WNS ≥ 0` (no setup violations)
- `WHS ≥ 0` (no hold violations)
- `WPWS ≥ 0` (no pulse-width violations)
- Failing endpoints = 0 for all checks

### 1.2 Failing Design Example

```
WNS(ns)    TNS(ns)    TNS Failing Endpoints    TNS Total Endpoints
  -0.385    -12.847                       41               24,831

WHS(ns)    THS(ns)    THS Failing Endpoints    THS Total Endpoints
   0.022      0.000                         0               24,831
```

This shows 41 setup-failing endpoints totaling −12.847 ns of violation. The critical path is −0.385 ns. This is a significant timing problem — all 41 paths need to be improved.

---

## 2. Interpreting a Detailed Path Report

```tcl
report_timing -setup -nworst 1 -path_type full_clock_expanded -delay_type max
```

### 2.1 Annotated Output

```
Slack (VIOLATED) :           -0.385ns  <-- negative = violation
  Source:                 src_pipe_reg[7]/C
                            (rising edge-triggered cell FDRE clocked by clk_200)
  Destination:            dst_logic_reg[7]/D
                            (rising edge-triggered cell FDRE clocked by clk_200)
  Path Group:             clk_200
  Path Type:              Setup (Max at Slow Process Corner)
  Requirement:            5.000ns  (clk_200 rise@5.000ns - clk_200 rise@0.000ns)
  Data Path Delay:        5.234ns  (logic 1.847ns  route 3.387ns)
                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
                                    Logic: 35%  Route: 65% — heavy routing
  Logic Levels:           7  (CARRY8=1 LUT3=2 LUT5=1 LUT6=3)
  Clock Path Skew:        -0.049ns  (DCD - SCD + CPP)
  Clock Uncertainty:       0.035ns  (clk_200 input jitter)
  Clock Path:
    ...
    MMCME4_ADV/CLKOUT0  0.000  0.000  clk_200 (MMCM output)
    BUFGCE/O            0.121  r       <clk_200 network>
    ...
    src_pipe_reg[7]/C   3.201  r       (source FF clock arrival)

  Data Path:
    src_pipe_reg[7]/C   0.000  r       (launch edge)
    src_pipe_reg[7]/Q   0.141  r       (clk2q)
    net (fanout=12)     0.487          (routing: 12 loads → high fanout)
    LUT6/I0             0.000  r
    LUT6/O              0.318  r       (combinational)
    net                 0.234
    LUT6/I1             0.000
    LUT6/O              0.301  r
    net                 0.289
    CARRY8/S[3]         0.000
    CARRY8/CO[7]        0.456  r       (8-bit carry = slow!)
    net                 0.198
    dst_logic_reg[7]/D  0.000  r       (destination FF data pin)

  Arrival Time:          5.385ns
  Required Time:         5.000ns
  Slack:                -0.385ns
```

**Key observations from this path:**
1. **Logic depth = 7 levels** — near the limit for 200 MHz; target is typically ≤ 5–6
2. **Route delay > logic delay (65% routing)** — suggests high fanout or long distance
3. **CARRY8 = 0.456 ns** — the carry chain is the bottleneck
4. **Fanout=12** on the first net — a fanout buffer may help

---

## 3. Clock Interaction Report

```tcl
report_clock_interaction -delay_type min_max
```

This produces a matrix showing the relationship between every pair of clock domains:

```
                  clk_200   clk_100   clk_eth
  clk_200   [  safe  ] [  MCP  ] [ unsafe ]
  clk_100   [  MCP   ] [ safe  ] [ unsafe ]
  clk_eth   [ unsafe ] [ unsafe] [  safe  ]
```

- **safe** — all paths analyzed, no issues
- **MCP** — multi-cycle paths exist between domains
- **unsafe** — CDC paths need explicit synchronization constraints

---

## 4. CDC Report

```tcl
report_cdc -details -file cdc_report.rpt
```

CDC violations appear as:
```
Violation (MULTI_BIT_COMBO):
  Source clock: clk_200
  Dest clock:   clk_100
  Driver cell:  data_bus_reg[7:0]/Q
  Number of bits: 8
  Severity: Critical
  Recommendation: Use a proper CDC structure (FIFO, Gray-coded counter, or
                  handshake) instead of directly registering multi-bit data
                  across clock domains.
```

---

## 5. Utilization Report

```tcl
report_utilization -hierarchical -file utilization.rpt
```

```
+-------------------+------+-------+-----------+-------+
|    Primitive      | Used | Fixed | Available | Util% |
+-------------------+------+-------+-----------+-------+
| FDRE              | 8241 |     0 |    522240 |  1.58 |
| LUT6              | 6102 |     0 |    261120 |  2.34 |
| LUT5              | 1879 |     0 |    261120 |  0.72 |
| CARRY8            |  102 |     0 |     32640 |  0.31 |
| RAMB36E2          |   18 |     0 |       312 |  5.77 |
| DSP58E2           |   24 |     0 |       360 |  6.67 |
+-------------------+------+-------+-----------+-------+
```

High utilization (> 70–75%) often correlates with routing congestion and timing closure difficulty.

---

## 6. Congestion Report

```tcl
report_design_analysis -congestion -file congestion.rpt
```

The congestion map shows where routing resources are overloaded. Critical regions appear as red in the Vivado device view:

```
Congestion Summary:
  Global Congestion: MEDIUM
  Worst Congestion Region: X2Y3 (routing utilization: 92%)
  
Recommendation: Floorplan logic to spread cells more evenly in X2Y3 region.
```

---

## 7. Timing Closure Iteration Loop

```
1. report_timing_summary     → Check WNS/TNS
        │
        ├── WNS < 0 → report_timing (worst paths)
        │       │
        │       ├── Logic too deep? → Pipeline or optimize RTL
        │       ├── Routing too slow? → Placement directive or Pblock
        │       └── Fanout too high? → Add pipeline register or MAX_FANOUT attribute
        │
        └── WNS ≥ 0 → DONE ✓
```

---

## 8. Useful Report Commands Reference

| Command | Purpose |
|---------|---------|
| `report_timing_summary` | Overall pass/fail |
| `report_timing -setup -nworst 20` | Top 20 setup violators |
| `report_timing -hold -nworst 20` | Top 20 hold violators |
| `report_cdc` | CDC path analysis |
| `report_clock_interaction` | Clock domain matrix |
| `report_design_analysis -congestion` | Routing congestion |
| `report_utilization -hierarchical` | Resource usage by module |
| `report_pulse_width` | Minimum clock pulse width |
| `check_timing` | Incomplete/incorrect constraints |
| `report_io` | I/O timing and pin assignments |

---

> **Next:** [04 — Debugging Timing Failures](04-Debugging.md) — Systematic approaches to fixing setup, hold, and CDC violations.
