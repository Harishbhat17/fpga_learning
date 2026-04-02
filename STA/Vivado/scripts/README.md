# Vivado TCL Scripts

> **Navigation:** [← Vivado README](../README.md)

This directory contains ready-to-run TCL scripts for automating timing analysis and closure in Vivado.

| Script | Description |
|--------|-------------|
| [timing_closure_flow.tcl](timing_closure_flow.tcl) | End-to-end compile and timing check flow |
| [batch_analysis.tcl](batch_analysis.tcl) | Batch analysis across multiple checkpoints |

---

## Usage

```bash
# Run from Vivado TCL console or batch mode:
vivado -mode batch -source scripts/timing_closure_flow.tcl

# Or from within Vivado:
source scripts/timing_closure_flow.tcl
```
