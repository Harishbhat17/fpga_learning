# Vivado XDC Examples

> **Navigation:** [← Vivado README](../README.md)

This directory contains XDC constraint examples for common FPGA design patterns.

| File | Description |
|------|-------------|
| [simple_adder.xdc](simple_adder.xdc) | Basic single-clock design |
| [multi_clock.xdc](multi_clock.xdc) | Multiple independent clock domains |
| [cdc_design.xdc](cdc_design.xdc) | Clock domain crossing constraints |
| [complex_pipeline.xdc](complex_pipeline.xdc) | Pipelined datapath with multi-cycle paths |

---

## How to Use

1. Copy the relevant XDC file to your `constraints/` directory
2. Add to your Vivado project: `add_files -fileset constrs_1 constraints/your.xdc`
3. Adapt port names, clock periods, and delay values to your design
4. Always run `check_timing` after applying to validate completeness
