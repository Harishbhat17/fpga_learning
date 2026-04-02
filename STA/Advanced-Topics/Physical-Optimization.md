# Physical Optimization

> **Navigation:** [← STA Index](../README.md)

---

## 1. Overview

Physical optimization encompasses placement and routing strategies that directly address timing violations that cannot be fixed by RTL changes alone. When a design has negative slack due to routing delay (rather than logic depth), physical constraints are the most effective fix.

---

## 2. Diagnosing Routing-Dominated Paths

```tcl
# Vivado: check the ratio of logic to route delay
report_timing -setup -nworst 20 -path_type full | \
    awk '/Data Path Delay/ {print NR, $0}'
```

**Indicator:** If route delay > 60% of total path delay, physical optimization is needed.

---

## 3. Pblocks (Placement Blocks) — Vivado

Pblocks constrain a set of cells to a defined region of the device, reducing routing distance.

### 3.1 Creating Pblocks via Tcl

```tcl
# Define a region in terms of Slices
create_pblock pbl_critical_path
add_cells_to_pblock pbl_critical_path \
    [get_cells -hierarchical {pipeline_stage*}]
resize_pblock pbl_critical_path -add {SLICE_X40Y60:SLICE_X79Y119}

# Soft constraint (hint) — tool can violate if needed
set_property IS_SOFT TRUE [get_pblocks pbl_critical_path]

# Hard constraint — tool MUST respect
set_property IS_SOFT FALSE [get_pblocks pbl_critical_path]
```

### 3.2 Choosing Pblock Size

- Too small → over-constrained, router can't find valid placement
- Too large → no benefit, cells spread out anyway
- **Rule of thumb:** Start at 120% of estimated resource usage, shrink if timing improves

### 3.3 Clock Region Pblocks

For designs with multiple clock domains, keep each domain in its own clock region:

```tcl
# Assign domain A to left half of device
create_pblock pbl_domain_a
add_cells_to_pblock pbl_domain_a [get_cells clk_a_logic*]
resize_pblock pbl_domain_a -add {CLOCKREGION_X0Y0:CLOCKREGION_X2Y5}

# Assign domain B to right half
create_pblock pbl_domain_b
add_cells_to_pblock pbl_domain_b [get_cells clk_b_logic*]
resize_pblock pbl_domain_b -add {CLOCKREGION_X3Y0:CLOCKREGION_X5Y5}
```

---

## 4. LogicLock Regions — Quartus

Quartus uses **LogicLock** regions (Standard) or **Design Partition Planner** (Pro) for similar placement control:

```tcl
# .qsf assignment for a LogicLock region
set_instance_assignment -name LOGICLOCK_REGION_SIZE "40 30" \
    -to "|top|fast_path_module"
set_instance_assignment -name LOGICLOCK_REGION_ORIGIN "X1 Y5" \
    -to "|top|fast_path_module"
set_instance_assignment -name LOGICLOCK_REGION_EXCLUSIVE ON \
    -to "|top|fast_path_module"
```

---

## 5. Placement Directives

### 5.1 Vivado Place Directives

```tcl
# Standard placement
place_design -directive Default

# For congested designs
place_design -directive AltSpreadLogic_high

# For timing-critical designs
place_design -directive ExtraTimingOpt

# Aggressive timing exploration
place_design -directive ExtraPostPlacementOpt
```

### 5.2 Physical Optimization After Placement

```tcl
# Run phys_opt_design after placement for incremental improvement
phys_opt_design -directive AggressiveExplore

# Specific optimizations
phys_opt_design \
    -fanout_opt                    \  # Optimize high-fanout nets
    -placement_opt                 \  # Re-place cells
    -critical_cell_opt             \  # Optimize cells on critical paths
    -hold_fix                      \  # Fix hold violations
    -slr_crossing_opt              \  # SLR-crossing optimization (multi-die)
    -rewire                           # Rewire netlist connections
```

---

## 6. Fanout Optimization

High fanout nets create long, spread-out routing trees:

```tcl
# Vivado: report high fanout nets
report_high_fanout_nets -fanout_greater_than 50 -max_nets 20

# Force automatic replication
set_property MAX_FANOUT 20 [get_nets high_fanout_net]

# Or manually replicate in RTL
```

**Automatic fanout optimization:**
```tcl
# Vivado phys_opt with fanout optimization
phys_opt_design -fanout_opt -force_replication_on_nets [get_nets high_fanout_net]
```

---

## 7. SLR-Crossing Optimization (Multi-Die Devices)

UltraScale+ stacked silicon interconnect (SSI) devices have multiple Super Logic Regions (SLRs). Paths crossing SLR boundaries have extra delay (~2–3 ns). 

### 7.1 Detecting SLR Crossings

```tcl
report_design_analysis -slr_crossing_stats
```

### 7.2 Adding SLR Crossing Registers

```verilog
// Add pipeline registers at SLR boundary
// These FFs should be placed near the SLR boundary
(* keep_hierarchy = "yes" *) module slr_crossing_buf #(parameter W=32) (
    input  logic        clk,
    input  logic [W-1:0] din,
    output logic [W-1:0] dout
);
    (* DONT_TOUCH = "true" *) logic [W-1:0] pipe_reg;
    always_ff @(posedge clk) pipe_reg <= din;
    assign dout = pipe_reg;
endmodule
```

### 7.3 Pblock for SLR Boundary FFs

```tcl
# Place the crossing registers near the SLR boundary (SLR0/SLR1)
create_pblock pbl_slr_crossing
add_cells_to_pblock pbl_slr_crossing [get_cells slr_crossing_buf*]
resize_pblock pbl_slr_crossing -add {CLOCKREGION_X3Y4:CLOCKREGION_X5Y5}
```

---

## 8. Summary

| Technique | When to Use | Tool |
|-----------|------------|------|
| Pblock | Route delay > 60%, co-location needed | Vivado |
| LogicLock | Same as Pblock | Quartus |
| `phys_opt_design` | Post-route fine-tuning | Vivado |
| `MAX_FANOUT` | High-fanout nets causing routing spread | Both |
| SLR crossing buffer | Multi-die device with long SLR paths | Vivado (SSI) |
| Place directive `ExtraTimingOpt` | When default placement leaves margin | Vivado |

---

> **See also:** [Multi-Corner Analysis](Multi-Corner-Analysis.md) | [Vivado Debugging](../Vivado/04-Debugging.md)
