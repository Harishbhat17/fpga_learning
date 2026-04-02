# 01 — Vivado Project Setup for Timing Analysis

> **Navigation:** [← Vivado README](README.md) | [Next: XDC Constraints →](02-XDC-Constraints.md)

---

## 1. Creating a New Project

### 1.1 GUI Flow

1. Open Vivado → **Create Project**
2. Choose **RTL Project** (not Post-synthesis — we want Vivado to run synthesis)
3. Set **Default Part** or board (e.g., `xczu7ev-ffvc1156-2-e` for ZCU104)
4. Add HDL source files and constraints (XDC)
5. Click **Finish**

### 1.2 TCL Flow (Recommended for Automation)

```tcl
# create_project.tcl
create_project my_design ./my_design -part xczu7ev-ffvc1156-2-e -force

# Add source files
add_files -norecurse {
    src/top.v
    src/pipeline.v
    src/alu.v
}

# Add constraint file
add_files -fileset constrs_1 -norecurse constraints/top.xdc

# Set top module
set_property top top [current_fileset]

# Set synthesis strategy
set_property strategy "Vivado Synthesis Defaults" [get_runs synth_1]

# Optionally enable retiming
set_property STEPS.SYNTH_DESIGN.ARGS.RETIMING true [get_runs synth_1]
```

---

## 2. Synthesis Settings for Timing Closure

### 2.1 Key Synthesis Properties

```tcl
# Enable register retiming (moves FFs across combinational logic)
set_property STEPS.SYNTH_DESIGN.ARGS.RETIMING true [get_runs synth_1]

# Flatten hierarchy for better cross-module optimization
set_property STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY rebuilt [get_runs synth_1]

# Target a specific Fmax (in MHz) to guide synthesis
set_property STEPS.SYNTH_DESIGN.ARGS.DIRECTIVE PerformanceOptimized [get_runs synth_1]

# FSM encoding style
set_property STEPS.SYNTH_DESIGN.ARGS.FSM_EXTRACTION one_hot [get_runs synth_1]
```

### 2.2 Synthesis Strategies Compared

| Strategy | When to Use | Trade-off |
|----------|------------|-----------|
| `Vivado Synthesis Defaults` | Initial exploration | Balanced |
| `Flow_PerfOptimized_high` | Needs better Fmax | Longer runtime |
| `Flow_AreaOptimized_high` | Resource-constrained | May hurt timing |
| `Flow_AlternateRoutability` | Congestion issues | Timing may suffer slightly |

---

## 3. Implementation Settings

### 3.1 Place and Route Strategy

```tcl
# Set implementation strategy
set_property strategy "Performance_ExplorePostRoutePhysOpt" [get_runs impl_1]

# Enable physical optimization
set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]

# Enable post-route physical optimization
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
```

### 3.2 Implementation Step Directives

| Step | Directive | Effect |
|------|-----------|--------|
| `opt_design` | `ExploreSequentialArea` | Reduces FF count to ease routing |
| `place_design` | `AltSpreadLogic_high` | Alternative placement for congested designs |
| `phys_opt_design` | `AggressiveExplore` | Aggressive fanout optimization |
| `route_design` | `AggressiveExplore` | More routing iterations |
| `post_route_phys_opt` | `AggressiveExplore` | Post-route timing driven optimization |

---

## 4. Running the Full Compile

### 4.1 GUI

In the **Flow Navigator** panel:
1. Click **Run Synthesis** → wait for completion
2. Click **Run Implementation** → wait (this runs opt, place, route, phys_opt)
3. Click **Generate Bitstream** (only after timing is closed)

### 4.2 TCL Batch Mode

```tcl
# run_all.tcl — run synthesis + implementation in one shot
launch_runs synth_1 -jobs 8
wait_on_run synth_1

if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    error "Synthesis failed!"
}

launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1

if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    error "Implementation failed!"
}

# Open routed checkpoint for timing analysis
open_checkpoint [get_property DIRECTORY [get_runs impl_1]]/[get_property TOP [current_design]]_routed.dcp

report_timing_summary -file reports/timing_summary.rpt
report_utilization     -file reports/utilization.rpt
report_drc             -file reports/drc.rpt
```

---

## 5. Project Settings — Timing Targets

Always set your timing constraint **before** running synthesis. This tells the tool what frequency to optimize for:

```tcl
# In your XDC constraint file (not in a run script):
create_clock -period 5.000 -name clk_200 [get_ports clk_in]
```

The period in the `create_clock` constraint is the **only** way to tell Vivado your target frequency. There is no separate "set frequency" command.

---

## 6. Incremental Compilation

For large designs with small changes, incremental compilation can dramatically speed up iteration:

```tcl
# Save reference checkpoint after first successful implementation
write_checkpoint -force checkpoints/reference.dcp

# In next run, enable incremental mode
set_property incremental_checkpoint checkpoints/reference.dcp [get_runs impl_1]
launch_runs impl_1 -incremental
```

Vivado will only re-place and re-route the changed modules, preserving timing for unchanged sections.

---

## 7. Timing Analysis Checkpoints

Analyze timing at each stage of implementation to catch problems early:

| Checkpoint | Command | What to Check |
|------------|---------|---------------|
| Post-synthesis | `open_checkpoint synth.dcp` | Logic depth estimates |
| Post-placement | `open_checkpoint placed.dcp` | Optimistic routing estimate |
| Post-route | `open_checkpoint routed.dcp` | **Final, sign-off quality** |

```tcl
# Report timing at each stage
foreach stage {synth placed routed} {
    open_checkpoint checkpoints/${stage}.dcp
    report_timing_summary -file reports/timing_${stage}.rpt
    close_design
}
```

---

> **Next:** [02 — XDC Constraints](02-XDC-Constraints.md) — Writing clock definitions, I/O delays, and timing exceptions.
