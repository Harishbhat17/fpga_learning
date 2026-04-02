# Vivado vs Quartus — Tool Comparison

> **Navigation:** [← STA Index](../README.md)

---

## 1. Overview

| Feature | Vivado (AMD/Xilinx) | Quartus Prime (Intel) |
|---------|--------------------|-----------------------|
| Target devices | Xilinx 7-Series, UltraScale, UltraScale+ | Intel Cyclone, Arria, Stratix, Agilex |
| Constraint format | XDC (superset of SDC) | SDC (industry standard) |
| STA engine | Built-in (based on Synopsys PrimeTime algorithms) | TimeQuest (Standard/Pro) |
| TCL console | Yes — full TCL interface | Yes — full TCL interface |
| GUI timing reports | Yes — timing report viewer | Yes — panel-based viewer |
| Multi-corner | Slow + Fast (default) | Multiple models |
| OCV | Flat OCV (default), POCV (2021.2+) | OCV with POCV (Pro) |
| CDC reporting | report_cdc (built-in) | report_cdc (TimeQuest) |

---

## 2. Constraint Language Comparison

| Operation | Vivado XDC | Quartus SDC |
|-----------|-----------|-------------|
| Create clock | `create_clock -period T [get_ports p]` | `create_clock -period T [get_ports p]` |
| Generated clock | `create_generated_clock -source -multiply_by -divide_by` | Same syntax |
| PLL clocks | Manual or auto-derived | `derive_pll_clocks -create_base_clocks` |
| Clock uncertainty | `set_clock_uncertainty -setup / -hold` | `derive_clock_uncertainty` (preferred) |
| Clock groups | `set_clock_groups -asynchronous -group` | Same syntax |
| Input delay | `set_input_delay -clock -max/-min` | Same syntax |
| Output delay | `set_output_delay -clock -max/-min` | Same syntax |
| False path | `set_false_path` | Same syntax |
| Multi-cycle | `set_multicycle_path -setup/-hold` | Same syntax |
| Max delay (CDC) | `set_max_delay -datapath_only` | `set_max_delay` |
| Physical constraints | In XDC (`IOSTANDARD`, `LOC`, Pblock) | In .qsf (`set_instance_assignment`) |

**Key Differences:**
- Quartus requires `derive_pll_clocks` before other clock commands
- Quartus `derive_clock_uncertainty` is preferred over manual `set_clock_uncertainty`
- Vivado `set_max_delay -datapath_only` is unique — Quartus `set_max_delay` without the flag includes clock uncertainty

---

## 3. Timing Report Comparison

| Report | Vivado Command | Quartus Command |
|--------|---------------|-----------------|
| Timing summary | `report_timing_summary` | `report_timing_summary` |
| Critical path | `report_timing -setup -nworst N` | `report_timing -setup -npaths N` |
| Hold paths | `report_timing -hold -nworst N` | `report_timing -hold -npaths N` |
| Fmax | Derived from WNS | `report_fmax_summary` (explicit) |
| CDC analysis | `report_cdc -details` | `report_cdc` |
| Clock interaction | `report_clock_interaction` | `report_clock_transfers` |
| Utilization | `report_utilization -hierarchical` | `report_utilization` |
| Congestion | `report_design_analysis -congestion` | Chip Planner routing view |
| I/O timing | `report_io` | `report_io` |

---

## 4. Physical Optimization

| Feature | Vivado | Quartus |
|---------|--------|---------|
| Post-route phys opt | `phys_opt_design -directive AggressiveExplore` | Built into Fitter (`PHYSICAL_SYNTHESIS_EFFORT HIGH`) |
| Placement regions | Pblocks | LogicLock regions (.qsf) |
| Register retiming | `RETIMING` synthesis option + `phys_opt` | `PHYSICAL_SYNTHESIS_REGISTER_RETIMING ON` |
| Fanout opt | `phys_opt_design -fanout_opt` | `PHYSICAL_SYNTHESIS_REGISTER_DUPLICATION ON` |
| Multi-threading | `-jobs N` in all commands | Fitter automatically multi-threaded |
| Design Space Explore | Manual seed changes | `quartus_dse` automation |

---

## 5. CDC Features

| Feature | Vivado | Quartus |
|---------|--------|---------|
| CDC detection | `report_cdc` — categories include MULTI_BIT_COMBO, COMBO_LOGIC | `report_cdc` — "No synchronization" etc. |
| Synchronizer marking | `set_property ASYNC_REG TRUE [get_cells ...]` | Attribute assignment in .qsf |
| CDC fix guidance | report_cdc includes fix recommendations | report_cdc includes severity levels |

---

## 6. Flow Summary

### Vivado Quick Closure Flow

```bash
1. Write XDC (clocks → I/O → exceptions)
2. synth_design -directive PerformanceOptimized -retiming
3. impl_1: strategy = Performance_ExplorePostRoutePhysOpt
4. report_timing_summary → check WNS/WHS
5. If failing: report_timing → diagnose → fix RTL/add Pblock
6. phys_opt_design -directive AggressiveExplore
7. Sign off: WNS ≥ 0, WHS ≥ 0, CDC clean
```

### Quartus Quick Closure Flow

```bash
1. Write SDC (derive_pll_clocks → clocks → I/O → derive_clock_uncertainty → exceptions)
2. Set SYNTHESIS_EFFORT HIGH, PHYSICAL_SYNTHESIS_REGISTER_RETIMING ON
3. Run quartus_fit + quartus_sta
4. report_timing_summary + report_fmax_summary
5. If failing: report_timing → diagnose → fix RTL
6. Try multiple seeds with quartus_dse
7. Sign off: all domains PASS in report_timing_summary
```

---

## 7. Choosing the Right Tool

Both tools are excellent — the choice is determined by the target device:
- **Vivado** for AMD/Xilinx FPGAs (UltraScale+, Zynq, Versal)
- **Quartus** for Intel/Altera FPGAs (Agilex, Stratix, Arria, Cyclone)

The SDC constraint language is compatible enough that you can often reuse 80–90% of your constraint file between tools.

---

> **See also:** [Vivado XDC Examples](../Vivado/examples/README.md) | [Quartus SDC Examples](../Quartus/examples/README.md)
