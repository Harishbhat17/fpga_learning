# Retiming and Optimization

> **Navigation:** [← STA Index](../README.md)

---

## 1. What Is Retiming?

**Retiming** is a physical synthesis transformation that relocates flip-flops across combinational logic boundaries to balance the delay between pipeline stages. The goal is to equalize combinational depth so that no single stage is the bottleneck.

```
Before retiming:
Stage 1: [FF] ──── 8 LUT levels ──── [FF] ──── 2 LUT levels ──── [FF]
          ← slow path (violating) →   ← fast path (excess margin) →

After retiming:
Stage 1: [FF] ──── 5 LUT levels ──── [FF] ──── 5 LUT levels ──── [FF]
          ← balanced (passes) →       ← balanced (passes) →
```

Retiming **does not change the logical function** — it preserves the output sequence while relocating registers to equalize delays.

---

## 2. Enabling Retiming

### 2.1 Vivado

```tcl
# Enable retiming in synthesis (moves FFs across LUT boundaries)
set_property STEPS.SYNTH_DESIGN.ARGS.RETIMING true [get_runs synth_1]

# Or via constraint attribute on specific modules:
(* retiming_forward = 1 *)  // Push registers toward outputs
(* retiming_backward = 1 *) // Pull registers toward inputs
```

### 2.2 Quartus

```tcl
# Enable in .qsf settings
set_global_assignment -name PHYSICAL_SYNTHESIS_REGISTER_RETIMING ON
```

### 2.3 RTL-Level Control

```verilog
// Prevent retiming across a boundary (preserves exact latency)
(* dont_retime = "true" *) logic [7:0] latency_critical_reg;

// Allow retiming of a pipeline stage
(* retiming_forward  = 1 *) logic [7:0] pipeline_stage_reg;
```

---

## 3. Manual Retiming Strategies

When automated retiming is insufficient, manual retiming provides finer control:

### 3.1 Identify the Imbalance

```tcl
# Vivado: show logic level distribution
report_design_analysis -logic_level_distribution

# Find paths with > 8 logic levels at 200 MHz
report_timing -setup -nworst 50 | grep "Logic Levels"
```

### 3.2 Move Register Forward

If a register has too much logic before it and too little after:

```verilog
// Before: all logic before the FF
always_ff @(posedge clk) begin
    result <= (a * b) + (c * d) + e + f + g;  // 12 logic levels
end

// After: break into two stages
always_ff @(posedge clk) begin
    partial1 <= (a * b) + (c * d);  // 6 levels
    partial2 <= e + f + g;           // 4 levels
end
always_ff @(posedge clk) begin
    result <= partial1 + partial2;   // 2 levels
end
```

---

## 4. Retiming Limitations

| Limitation | Explanation |
|------------|-------------|
| Initial value / reset | Retimed FFs inherit reset state from original; verify correctness |
| Latency increase | Retiming may add pipeline stages, changing functional latency |
| Black boxes | Cannot retime across IP cores or module boundaries without `flatten_hierarchy` |
| Set/Reset constraints | FFs with specific set/reset logic cannot always be retimed |

---

## 5. Synthesis Directives for Optimization

### 5.1 Vivado Synthesis Directives

| Directive | Effect |
|-----------|--------|
| `PerformanceOptimized` | Maximize Fmax (more effort) |
| `AreaOptimized_high` | Minimize LUT count |
| `AlternateRoutability` | Better for congested designs |
| `Flow_RuntimeOptimized` | Fastest synthesis (least optimization) |

```tcl
synth_design -directive PerformanceOptimized \
             -retiming \
             -flatten_hierarchy rebuilt
```

### 5.2 Quartus Synthesis Options

```tcl
set_global_assignment -name SYNTHESIS_EFFORT HIGH
set_global_assignment -name SYNTH_TIMING_DRIVEN_SYNTHESIS ON
set_global_assignment -name TIMING_DRIVEN_SYNTHESIS ON
set_global_assignment -name PHYSICAL_SYNTHESIS_EFFORT HIGH
```

---

## 6. Post-Route Optimization

After routing, both tools provide additional optimization passes:

### 6.1 Vivado Post-Route Physical Optimization

```tcl
phys_opt_design \
    -directive AggressiveExplore \
    -placement_opt \
    -routing_opt \
    -hold_fix \
    -rewire
```

What each option does:
- `-placement_opt` — re-places cells to reduce delay
- `-routing_opt` — re-routes critical nets
- `-hold_fix` — inserts delay buffers for hold violations
- `-rewire` — modifies netlist connections to reduce delay

### 6.2 Quartus Post-Fit Optimization

```tcl
# Enable post-fit optimization in .qsf
set_global_assignment -name PHYSICAL_SYNTHESIS_EFFORT HIGH
set_global_assignment -name PHYSICAL_SYNTHESIS_COMBO_LOGIC_DUPLICATION ON
set_global_assignment -name PHYSICAL_SYNTHESIS_MAP_LOGIC_TO_INPUT_REGISTERS_FOR_SPEED ON
```

---

## 7. ECO (Engineering Change Order) Flow

For minor timing fixes after routing, an ECO modifies individual cells without full re-compilation:

### Vivado ECO

```tcl
# Open implemented design
open_checkpoint design_routed.dcp

# Make a cell-level change (e.g., swap a LUT)
set_property INIT 64'hFEDCBA9876543210 [get_cells my_lut]

# Route only the changed connections
route_design -nets [get_nets changed_net] -physical_nets

# Re-check timing
report_timing_summary
write_checkpoint design_routed_eco.dcp
```

---

> **See also:** [Pipelining Strategies](Pipelining-Strategies.md) | [Register Balancing](Register-Balancing.md)
