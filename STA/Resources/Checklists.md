# Pre-Sign-Off Checklists

> **Navigation:** [← STA Index](../README.md)

Quick-reference checklists to use before each major milestone.

---

## Checklist A: Before Submitting to Implementation

```
CONSTRAINTS
□ All clocks defined (create_clock / create_generated_clock)
□ Clock periods match your target frequency
□ Clock groups declared for asynchronous domain pairs
□ All ports have timing constraints (input/output delay or false path)
□ check_timing reports no unconstrained paths

RTL REVIEW
□ Logic depth estimate: all critical paths ≤ N levels (N = f × (t_cell+t_net)^-1)
□ All CDC crossings have proper synchronizers (2-FF, FIFO, handshake)
□ ASYNC_REG or equivalent attribute applied to all synchronizer FFs
□ No gated clocks (no LUT in clock path)
□ DSP blocks: PREG/MREG enabled for time-critical paths
□ High-fanout nets (>100 loads): replicated or MAX_FANOUT set

SETTINGS
□ Synthesis strategy appropriate (PerformanceOptimized or equivalent)
□ Retiming enabled if needed
□ Implementation strategy set (Performance_ExplorePostRoutePhysOpt)
□ Post-route physical optimization enabled
```

---

## Checklist B: After Implementation (Pre-Bitstream)

```
TIMING
□ WNS ≥ 0.000 ns (all setup paths pass)
□ WHS ≥ 0.000 ns (all hold paths pass)
□ TPWS ≥ 0.000 ns (pulse width requirements met)
□ TNS = 0.000 ns (zero failing endpoints)

CDC
□ report_cdc: 0 critical violations
□ All synchronizer registers marked ASYNC_REG
□ All CDC constraint paths (set_max_delay -datapath_only) verified

DESIGN QUALITY
□ report_drc: 0 critical errors
□ Utilization < 75% (LUT, FF, BRAM, DSP)
□ No routing congestion above 85% in any region
□ No unconstrained clocks

DOCUMENTATION
□ Final timing reports saved to archive
□ All timing exceptions documented (false paths, MCPs)
□ Constraint file under version control
```

---

## Checklist C: Multi-Corner Sign-Off

```
SLOW CORNER (Setup)
□ WNS ≥ 0 at slow process corner
□ WNS ≥ 0 at maximum temperature
□ WNS ≥ 0 at minimum supply voltage

FAST CORNER (Hold)
□ WHS ≥ 0 at fast process corner
□ WHS ≥ 0 at minimum temperature
□ WHS ≥ 0 at maximum supply voltage

ASYNC RESET (if used)
□ Recovery slack ≥ 0 (slow corner)
□ Removal slack ≥ 0 (fast corner)

DOCUMENTATION
□ All corner reports archived
□ Worst corner WNS/WHS values recorded for each clock domain
```

---

## Checklist D: CDC Final Verification

```
STRUCTURAL
□ Every single-bit CDC path has at least 2 synchronizer FFs
□ Every multi-bit CDC path uses FIFO, handshake, or Gray code
□ No combinational logic between source and synchronizer FF
□ No binary counters crossing asynchronous domain boundaries

CONSTRAINTS
□ set_clock_groups -asynchronous applied to all async domain pairs
□ set_max_delay -datapath_only applied to all synchronizer inputs
□ set_false_path NOT used as a shortcut to silence CDC warnings

SIMULATION
□ CDC paths exercised in RTL simulation
□ Timing simulation run with extracted parasitics (recommended)

TOOL REPORTS
□ Vivado: report_cdc -details shows 0 violations
□ OR Quartus: report_cdc shows 0 violations
□ Clock interaction matrix reviewed for unexpected relationships
```

---

## Timing Margin Targets

| Clock Domain | Minimum WNS (ns) | Recommended WNS (ns) |
|-------------|-----------------|----------------------|
| ≤ 100 MHz | 0.0 | 0.2 |
| 100–200 MHz | 0.0 | 0.1 |
| 200–300 MHz | 0.0 | 0.075 |
| 300–500 MHz | 0.0 | 0.050 |
| > 500 MHz | 0.0 | 0.025 |

A "recommended" margin provides a safety buffer for:
- OCV variations not captured in slow corner
- Temperature/voltage excursions in the field
- Aging effects over device lifetime

---

> **See also:** [Optimization Checklist](../Best-Practices/Optimization-Checklist.md) | [Common Mistakes](../Best-Practices/Common-Mistakes.md)
