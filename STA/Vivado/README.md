# Vivado — Static Timing Analysis

> **Navigation:** [← STA Index](../README.md)

Xilinx Vivado Design Suite provides a fully integrated STA engine based on industry-standard constraint syntax (XDC — Xilinx Design Constraints, a superset of SDC). This section documents the end-to-end timing closure flow for Vivado 2023.x targeting 7-Series, UltraScale, and UltraScale+ devices.

---

## Contents

| File | Description |
|------|-------------|
| [01 — Project Setup](01-Project-Setup.md) | Creating a project, synthesis/implementation run settings |
| [02 — XDC Constraints](02-XDC-Constraints.md) | Writing clock, I/O delay, and timing exception constraints |
| [03 — Timing Reports](03-Timing-Reports.md) | Reading `report_timing_summary` and interpreting results |
| [04 — Debugging](04-Debugging.md) | Fixing negative slack, CDC violations, and hold failures |
| [scripts/](scripts/README.md) | TCL automation scripts for batch timing analysis |
| [examples/](examples/README.md) | XDC constraint examples for common design patterns |
| [case_studies/](case_studies/Case-Study-1-Image-Processing.md) | Real-world timing closure case study |

---

## Quick Reference — Most-Used TCL Commands

```tcl
# Open implemented checkpoint
open_checkpoint design_routed.dcp

# Full timing summary
report_timing_summary -file timing_summary.rpt

# Critical path (worst 10 setup paths)
report_timing -setup -nworst 10 -path_type full_clock_expanded -file setup_paths.rpt

# Hold check
report_timing -hold  -nworst 10 -path_type full -file hold_paths.rpt

# CDC analysis
report_cdc -details -file cdc.rpt

# Clock interaction matrix
report_clock_interaction -delay_type min_max -file clock_interaction.rpt

# Utilization
report_utilization -file utilization.rpt

# DRC (includes timing-relevant checks)
report_drc -file drc.rpt
```

---

## Tool Versions

| Version | Notable STA Features Added |
|---------|---------------------------|
| Vivado 2021.2 | POCV support, improved CDC reporting |
| Vivado 2022.1 | Enhanced path grouping, ECO flow |
| Vivado 2023.1 | AI-assisted placement hints, improved MMCM jitter models |
| Vivado 2023.2 | Multi-threading improvements for large designs |

---

> **Start here:** [01 — Project Setup](01-Project-Setup.md)
