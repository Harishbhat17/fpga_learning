# 03 — TimeQuest Timing Analyzer

> **Navigation:** [← 02 SDC Constraints](02-SDC-Constraints.md) | [Quartus README](README.md) | [Next: Timing Reports →](04-Timing-Reports.md)

---

## 1. Launching TimeQuest

### 1.1 From Quartus GUI

After compilation: **Tools → TimeQuest Timing Analyzer**

TimeQuest opens with:
- **Tasks** panel (left): Run commands like "Read Netlist", "Create Timing Netlist", "Report Timing Summary"
- **Timing Analyzer** panel (right): Tabular results
- **Console** panel (bottom): TCL command input/output

### 1.2 Standalone Batch Mode

```bash
# Run timing analysis and generate reports from command line
quartus_sta my_design --do_report_timing
```

### 1.3 Interactive TCL Session

```bash
# Launch interactive TimeQuest
quartus_sta -s

# Or from within Quartus TCL console:
load_package timing_check
```

---

## 2. Basic TimeQuest Workflow

Execute these commands in order (Tasks panel or TCL console):

```tcl
## Step 1: Load the compiled netlist
## (Run after quartus_fit has completed)
read_netlist

## Step 2: Read your SDC constraints
read_sdc constraints/top.sdc

## Step 3: Build the timing netlist (annotates delays)
create_timing_netlist

## Step 4: Propagate timing (compute AT and RAT for all nodes)
update_timing_netlist

## Step 5: Generate reports
report_timing_summary -panel_name "Timing Summary"
report_fmax_summary   -panel_name "Fmax Summary"
```

**Important:** Never skip `update_timing_netlist` before reporting — stale results will be used otherwise.

---

## 3. The Timing Summary Panel

After `report_timing_summary`, the panel shows:

```
Clock     Setup     Hold    Recovery   Removal
          Slack     Slack   Slack      Slack
clk_sys   0.142 ns  0.031   N/A        N/A
clk_dsp  -0.085 ns  0.012   N/A        N/A   ← SETUP FAIL
clk_eth   0.215 ns  0.044   N/A        N/A
```

Any negative value is a violation. Double-click a cell to drill into the failing paths.

---

## 4. Critical Path Analysis

```tcl
# Worst 10 setup paths with full detail
report_timing \
    -setup \
    -npaths 10 \
    -detail full_path \
    -panel_name "Worst Setup Paths"

# Specific clock domain
report_timing \
    -setup \
    -npaths 5 \
    -from_clock { clk_dsp } \
    -to_clock   { clk_dsp } \
    -detail full_path
```

### 4.1 Annotated Path Report

```
Slack       : -0.085 ns
From Clock  : clk_dsp (rise)
To Clock    : clk_dsp (rise)
Required    : 4.000 ns
Arrival     : 4.085 ns
                                
Data Path:
  src_dsp_reg|q      0.000   (launch)
  src_dsp_reg|q      0.112   clk2q  
  net (fanout=8)     0.341   routing
  mul_lut6|o         0.298   cell
  net                0.187   routing
  dsp_block|dataa    0.000
  dsp_block|result  0.897   DSP (multiplier)
  net                0.218   routing
  dst_dsp_reg|d      0.000   destination
  ----               
  Data delay         2.053 ns
  Clock path         2.032 ns  (launch)
  Arrival            4.085 ns

  Clock period       4.000 ns
  Uncertainty       -0.080 ns  (derived_clock_uncertainty)
  Required           3.920 ns

  Slack = 3.920 - 4.085 = -0.085 ns  VIOLATED
```

---

## 5. Fmax Report

```tcl
report_fmax_summary -panel_name "Fmax Summary"
```

```
Fmax Summary
+-------------+-----------+----------+--------+
| Clock       | Constrained | Actual  | Status |
+-------------+-----------+----------+--------+
| clk_sys     | 100 MHz   | 142.3 MHz | PASS   |
| clk_dsp     | 250 MHz   | 241.5 MHz | FAIL   |
| clk_eth     | 125 MHz   | 167.8 MHz | PASS   |
+-------------+-----------+----------+--------+
```

Note: **Actual Fmax** is calculated as `1 / (T - WNS)`. A failing clock shows the **achievable** Fmax, not the target.

---

## 6. Clock Transfer Analysis

```tcl
# Show clock domain crossings
report_cdc -panel_name "CDC Analysis"

# Show the transfer matrix between clock domains
report_timing \
    -setup \
    -npaths 5 \
    -from_clock { clk_sys } \
    -to_clock   { clk_dsp } \
    -panel_name "sys-to-dsp transfers"
```

---

## 7. GUI Workflow Tips

### 7.1 Cross-Probing to Floorplan

In the timing report, right-click any cell name → **Locate in Chip Planner** to see its physical placement. This is invaluable for diagnosing long routing delays.

### 7.2 Node Finder

Use **Edit → Find** to search for specific register or net names in the timing hierarchy.

### 7.3 Saved Reports

```tcl
# Save all open panels to a file
save_report -file timing_analysis.html -format html

# Or individual panel
report_timing_summary -file timing_summary.rpt
```

---

## 8. Scripted Full Analysis

```tcl
## full_sta_analysis.tcl
## Run complete timing analysis and save all reports

package require ::quartus::report
package require ::quartus::sta

# Load netlist and apply constraints
read_netlist
read_sdc constraints/top.sdc
create_timing_netlist
update_timing_netlist

set rpt_dir "./timing_reports"
file mkdir $rpt_dir

# Core reports
report_timing_summary   -file ${rpt_dir}/timing_summary.rpt
report_fmax_summary     -file ${rpt_dir}/fmax_summary.rpt
report_timing -setup -npaths 20 -detail full_path \
              -file ${rpt_dir}/worst_setup.rpt
report_timing -hold  -npaths 20 -detail full_path \
              -file ${rpt_dir}/worst_hold.rpt
report_cdc              -file ${rpt_dir}/cdc.rpt
report_exceptions -all  -file ${rpt_dir}/exceptions.rpt
report_clock_fmax_summary \
              -file ${rpt_dir}/clock_fmax.rpt

# Check for violations
set wns [get_timing_analysis_summary_results -setup]
if {$wns < 0} {
    puts "FAIL: Setup timing not met. WNS = $wns ns"
} else {
    puts "PASS: Timing closed. WNS = $wns ns"
}
```

---

> **Next:** [04 — Timing Reports](04-Timing-Reports.md) — In-depth guide to reading and acting on Quartus timing reports.
