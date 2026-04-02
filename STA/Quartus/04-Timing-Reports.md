# 04 — Quartus Timing Reports

> **Navigation:** [← 03 TimeQuest Analyzer](03-TimeQuest-Analyzer.md) | [Quartus README](README.md)

---

## 1. Timing Summary Report

The first report to check after any compilation:

```tcl
report_timing_summary -panel_name "Timing Summary"
```

### 1.1 Reading the Summary Table

```
+------------------------------+--------+--------+----------+---------+
|                              | Setup  | Hold   | Recovery | Removal |
| Clock                        | Slack  | Slack  | Slack    | Slack   |
+------------------------------+--------+--------+----------+---------+
| clk_sys:rise                 | 0.312  | 0.028  | N/A      | N/A     |
| clk_dsp:rise                 |-0.214  | 0.041  | N/A      | N/A     |  ← FAIL
| clk_eth:rise                 | 0.087  | 0.012  | N/A      | N/A     |
| rst_n:rise --> clk_sys:rise  | 0.000  | N/A    | 1.234    | 0.456   |
+------------------------------+--------+--------+----------+---------+
```

**Recovery check:** Asynchronous reset must be deasserted at least `t_recovery` before the next clock edge.
**Removal check:** Asynchronous reset must remain asserted for `t_removal` after the active clock edge.

---

## 2. Detailed Path Report

```tcl
report_timing -setup -npaths 1 -detail full_path -panel_name "Critical Path"
```

### 2.1 Full Path Breakdown

```
; Slack : -0.214 ns
;
; Data Required Time
; -----------------------------------
; clock clk_dsp (rise edge)              0.000
; clock network delay (propagated)       0.187   (PLL→BUFG→FF_dst clock pin)
; clock uncertainty                     -0.080   (derived_clock_uncertainty)
; FF_dst|setup time                     -0.050
;                                       -------
; data required time                     0.057
;
; Data Arrival Time
; -----------------------------------
; clock clk_dsp (rise edge)              0.000
; clock network delay (propagated)       0.121   (PLL→BUFG→FF_src clock pin)
; FF_src|clock to output delay           0.115
; net: src_to_lut                        0.287   (routing)
; LUT4|delay                             0.189
; net: lut_to_dsp                        0.143
; DSP|adder delay                        0.521   (Cyclone V LE adder)
; net: dsp_to_dst                        0.217
; FF_dst|setup hold                      0.000
;                                       -------
; data arrival time                      1.593 + [clock arrival 0.121 + clock_src 0.0]
;                                       = 1.593 total
;
; Note: Arrival = launch_clock + t_clk2q + data_path_delay
;       = 0.121 + 0.115 + 1.357 = 1.593 ns
;
; Required Time (capture edge):
;  capture_clock = 0.000 + period(4.0) = 4.000 ns
;  + clock_dst (0.187) - uncertainty (0.080) - setup (0.050) = 4.057 ns
;
; But let's restate as relative to launch edge:
;  Required (relative) = period - uncertainty - setup + skew
;                      = 4.000 - 0.080 - 0.050 + (0.187 - 0.121) = 3.936 ns
;
;  Arrival (data path only):
;  = t_clk2q + data_logic + data_net = 0.115 + 0.189 + 0.521 + 0.147 + 0.287 + 0.143 + 0.217
;  = 1.619 ns
;
;  !! Wait — the total arrival exceeds the period:
;  Launch at 0.121 (clock) + 1.619 (data) = 1.740 ns (data arrives at FF_dst input)
;  Capture required at: 4.000 + 0.187 - 0.080 - 0.050 = 4.057 ns (next cycle)
;  Slack = 4.057 - 1.740 = 2.317 ns  (PASS)
;
;  Hmm — the -0.214 slack from the summary is for clk_dsp domain; revisit with
;  the actual failing path, which is likely a longer chain shown below.
;
; ACTUAL FAILING PATH EXAMPLE:
; Slack: -0.214 ns
; From: pipeline_stage3_reg (clk_dsp, rise)
; To:   output_accumulator_reg (clk_dsp, rise)
;
; Data Path Delay: 4.297 ns
;   t_clk2q:       0.115 ns
;   7 LUT levels:  1.540 ns
;   CARRY chain:   0.931 ns
;   Net routing:   1.711 ns  (64% of data path)
;
; Clock Period:    4.000 ns
; Uncertainty:    -0.080 ns
; Setup:          -0.050 ns
; Skew (helpful): +0.043 ns
; Required:        3.913 ns
; Slack:          -0.384 ns  → VIOLATED
```

---

## 3. Identifying Routing-Dominated Paths

A path where routing delay > 60% of total indicates placement is spread out:

```tcl
# Find paths with high routing delay percentage
report_timing -setup -npaths 50 -detail full_path | \
    grep -E "routing.*[6-9][0-9]\%|routing.*100\%"
```

In the Chip Planner, select the source and destination registers to visualize routing:
1. Right-click source cell → **Locate → In Chip Planner**
2. In Chip Planner → View → Show Connections

If the path crosses multiple logic array blocks (LABs) or even clock regions, placement constraints (LogicLock in Quartus Standard, or pipelining) are needed.

---

## 4. Clock Fmax Summary

```tcl
report_clock_fmax_summary -panel_name "Fmax Summary"
```

This shows the **maximum achievable frequency** per clock domain. Useful for exploring frequency headroom:

```
+----------+-------+--------+----------+-------+
| Clock    | Target | Actual  | Required | Pass? |
+----------+-------+--------+----------+-------+
| clk_sys  | 100   | 158.7  | 100.0    | YES   |
| clk_dsp  | 250   | 235.8  | 250.0    | NO    |
| clk_eth  | 125   | 189.4  | 125.0    | YES   |
+----------+-------+--------+----------+-------+
```

`clk_dsp` achieves only 235.8 MHz vs target 250 MHz → need to close 14.2 MHz gap (~5.7% improvement).

---

## 5. Hold Analysis

```tcl
report_timing -hold -npaths 10 -detail full_path -panel_name "Hold Paths"
```

Hold violations in Quartus are often caused by:
1. **Zero-delay paths** (e.g., shift registers with direct connections)
2. **Large positive clock skew** (destination clock much later than source)
3. **Incorrect `set_multicycle_path` without hold adjustment**

The fitter automatically inserts hold buffers in most cases. If WHS < 0 after fitting:

```tcl
# Check if the violation is due to clock skew
report_timing -hold -npaths 1 -detail full_path
# Look for "Clock Skew" in the path report
```

---

## 6. Useful Report Commands Reference

| Command | Purpose |
|---------|---------|
| `report_timing_summary` | Overall pass/fail for all clocks |
| `report_fmax_summary` | Achievable Fmax per clock |
| `report_timing -setup -npaths N` | N worst setup paths |
| `report_timing -hold  -npaths N` | N worst hold paths |
| `report_cdc` | CDC path analysis |
| `report_exceptions -all` | All false paths and MCPs |
| `report_clock_fmax_summary` | Detailed Fmax per domain |
| `report_clock_transfers` | Inter-domain timing |
| `check_timing -detailed_report on` | Constraint completeness |
| `report_net_timing` | Specific net timing |

---

## 7. Comparing Results Across Compilations

```tcl
## compare_timing.tcl
## Compare WNS/Fmax between two compilation results

proc open_and_get_wns {project_dir project_name} {
    project_open ${project_dir}/${project_name}
    load_package timing_check
    read_netlist
    create_timing_netlist
    update_timing_netlist
    set wns [get_timing_analysis_summary_results -setup]
    project_close
    return $wns
}

set wns_v1 [open_and_get_wns "./build_v1" "my_design"]
set wns_v2 [open_and_get_wns "./build_v2" "my_design"]

puts "Version 1 WNS: $wns_v1 ns"
puts "Version 2 WNS: $wns_v2 ns"
if {$wns_v2 > $wns_v1} {
    puts "V2 is BETTER by [expr {$wns_v2 - $wns_v1}] ns"
} else {
    puts "V1 is BETTER — revert to V1!"
}
```

---

> **See also:** [Quartus Scripts](scripts/README.md) | [SDC Examples](examples/README.md) | [Case Studies](case_studies/Case-Study-1-DSP-Design.md)
