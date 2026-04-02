# Timing Optimization Checklist

> **Navigation:** [← STA Index](../README.md)

Use this checklist for systematic timing closure. Work through items in order — earlier items have higher impact.

---

## Phase 1: Constraints (Before Running Implementation)

```
□ All clocks defined with create_clock / create_generated_clock
□ All asynchronous domain pairs declared with set_clock_groups -asynchronous
□ All top-level input ports have set_input_delay (or set_false_path)
□ All top-level output ports have set_output_delay (or set_false_path)
□ All reset ports constrained (usually set_false_path)
□ Multi-cycle paths declared with BOTH setup AND hold adjustments
□ CDC synchronizer paths constrained with set_max_delay -datapath_only
□ check_timing reports no warnings about unconstrained paths
□ report_clocks shows all expected clocks (no extras, none missing)
```

---

## Phase 2: Pre-Implementation RTL Review

```
□ Logic depth estimated: ≤ (f_target × (t_cell + t_net))^-1 levels
□ No logic deeper than 2× target level count in any module
□ All DSP-using paths: PREG/MREG attributes set or inference verified
□ High-fanout signals (>50 loads) replicated or attributed MAX_FANOUT
□ No gated clocks (LUT in clock path)
□ All CDC crossings use proper structures (2-FF, FIFO, handshake)
□ ASYNC_REG attribute applied to all synchronizer registers
□ Retiming enabled if needed (set RETIMING=true in synthesis settings)
```

---

## Phase 3: Post-Synthesis Check

```
□ Synthesis completed without errors or critical warnings
□ report_timing_summary: WNS estimate reasonable (< -2 ns is problematic)
□ report_design_analysis -logic_level_distribution: no paths > 10 levels at target
□ Resource utilization < 70% (higher = congestion risk)
□ DSP blocks inferred: verify PREG/MREG are ON in DSP properties
□ No unexpected clock buffers inserted (check report_clock_networks)
```

---

## Phase 4: Post-Implementation Check

```
□ WNS ≥ 0 (setup) — ALL paths pass
□ WHS ≥ 0 (hold) — ALL hold paths pass
□ TPWS ≥ 0 (pulse width) — clock pulse width requirements met
□ TNS = 0 (no failing endpoints)
□ report_cdc: 0 violations
□ report_drc: 0 critical errors
□ Clock interaction matrix: no "unsafe" domain pairs
□ All clock domains present in timing summary
□ I/O timing passes (in2reg and reg2out paths)
```

---

## Phase 5: Multi-Corner Sign-Off

```
□ Slow corner (setup): WNS ≥ 0
□ Fast corner (hold): WHS ≥ 0
□ Industrial temperature range checked (if applicable: -40°C to +125°C)
□ Recovery/removal checks pass for async reset
□ report_timing_summary at all corners saved to archive
```

---

## Phase 6: Physical Checks

```
□ report_design_analysis -congestion: no regions >85% routing utilization
□ Pblocks properly defined (not over-constrained — try IS_SOFT=TRUE first)
□ No BUFG over-limit warnings (Vivado: ≤12 clocks per clock region)
□ SLR crossing paths (multi-die): ≥ 1 pipeline register per SLR boundary
□ I/O registers packed into IOBs where specified (check IOB property)
```

---

## Phase 7: CDC Verification

```
□ report_cdc: ZERO violations
□ All synchronizer FFs have ASYNC_REG = TRUE (Vivado) or equivalent
□ All CDC paths have set_max_delay -datapath_only constraints
□ Async FIFOs: both wr_ptr and rd_ptr use Gray encoding
□ Single-bit CDC: 2-FF synchronizer (not just 1 FF)
□ Multi-bit CDC: handshake or FIFO (not raw bus synchronizer)
□ No binary counters crossing clock domains
```

---

## Quick Triage Matrix

| Symptom | First Command | Likely Fix |
|---------|-------------|-----------|
| WNS < 0 (many paths) | `report_design_analysis -logic_level_distribution` | RTL pipelining |
| WNS < 0 (few paths) | `report_timing -setup -nworst 5` | Placement / fanout |
| WHS < 0 | `report_timing -hold -nworst 5` | Skew / phys_opt |
| CDC violations | `report_cdc -details` | Synchronizer insertion |
| Congestion | `report_design_analysis -congestion` | Pblock / reduce density |
| Unconstrained paths | `check_timing -verbose` | Add constraints |

---

> **See also:** [Common Mistakes](Common-Mistakes.md) | [Resources: Checklists](../Resources/Checklists.md)
