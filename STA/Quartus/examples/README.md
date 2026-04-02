# Quartus SDC Examples

> **Navigation:** [← Quartus README](../README.md)

| File | Description |
|------|-------------|
| [simple_adder.sdc](simple_adder.sdc) | Basic single-clock adder |
| [multi_clock.sdc](multi_clock.sdc) | Multiple independent clock domains |
| [cdc_design.sdc](cdc_design.sdc) | Clock domain crossing constraints |
| [complex_pipeline.sdc](complex_pipeline.sdc) | Pipelined DSP datapath |

## Key Differences from XDC

| Feature | XDC (Vivado) | SDC (Quartus) |
|---------|-------------|----------------|
| PLL jitter | Auto-modeled | Use `derive_pll_clocks` |
| Clock uncertainty | `set_clock_uncertainty` | `derive_clock_uncertainty` (preferred) |
| Physical constraints | In XDC | In .qsf (LogicLock) |
| File extension | `.xdc` | `.sdc` |
