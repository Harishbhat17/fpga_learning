# Quartus Prime — Static Timing Analysis

> **Navigation:** [← STA Index](../README.md)

Intel Quartus Prime integrates the **TimeQuest Timing Analyzer** (TQ), which uses the industry-standard SDC (Synopsys Design Constraints) format. This section covers the end-to-end STA flow for Quartus Prime Pro/Standard edition targeting Cyclone V, Arria 10, Stratix 10, and Agilex devices.

---

## Contents

| File | Description |
|------|-------------|
| [01 — Project Setup](01-Project-Setup.md) | Creating projects, fitter settings for timing |
| [02 — SDC Constraints](02-SDC-Constraints.md) | Writing clock, I/O delay, and exception constraints |
| [03 — TimeQuest Analyzer](03-TimeQuest-Analyzer.md) | Using the TQ GUI and TCL console |
| [04 — Timing Reports](04-Timing-Reports.md) | Interpreting Fmax, slack, and path reports |
| [scripts/](scripts/README.md) | TCL automation scripts |
| [examples/](examples/README.md) | SDC constraint examples |
| [case_studies/](case_studies/Case-Study-1-DSP-Design.md) | DSP chain timing closure |

---

## Quick Reference — Most-Used TimeQuest TCL Commands

```tcl
# Open TimeQuest (from Quartus TCL console)
quartus_sta my_design --do_report_timing

# OR from TimeQuest TCL console:
read_netlist
read_sdc constraints/top.sdc
create_timing_netlist
update_timing_netlist

# Summary report
report_timing_summary -panel_name "Timing Summary"

# Critical path
report_timing -setup -npaths 10 -detail full_path -panel_name "Setup Paths"

# Hold
report_timing -hold  -npaths 10 -detail full_path -panel_name "Hold Paths"

# Fmax summary
report_fmax_summary

# CDC
report_cdc -panel_name "CDC Analysis"

# Clock domains
report_clock_fmax_summary
```

---

## Quartus Tool Editions

| Edition | STA Tool | Devices Supported |
|---------|----------|-------------------|
| Lite | TimeQuest (basic) | MAX 10, Cyclone V |
| Standard | TimeQuest (full) | Arria V, Cyclone 10 |
| Pro | Timing Analyzer (advanced) | Stratix 10, Agilex |

> **Note:** Quartus Prime Pro uses a different Timing Analyzer with enhanced features (POCV, multi-corner). The TCL command set is largely the same but some commands differ.

---

> **Start here:** [01 — Project Setup](01-Project-Setup.md)
