# Multi-Corner Analysis

> **Navigation:** [← STA Index](../README.md)

---

## 1. What Is Multi-Corner Analysis?

Real FPGA devices operate across a range of **process (P)**, **voltage (V)**, and **temperature (T)** conditions. A design that passes timing under typical conditions may fail under worst-case conditions. Multi-corner analysis ensures the design is robust across the full operating range.

---

## 2. PVT Corners Defined

### 2.1 Process Corners

| Corner | Process | Description |
|--------|---------|-------------|
| Typical (TT) | Nominal | Average manufacturing variation |
| Slow-Slow (SS) | Slow | NMOS and PMOS both slower than nominal |
| Fast-Fast (FF) | Fast | NMOS and PMOS both faster than nominal |
| Slow-Fast (SF) | Skewed | NMOS slow, PMOS fast (I/O dominant effects) |
| Fast-Slow (FS) | Skewed | NMOS fast, PMOS slow |

For FPGA STA:
- **Slow corner → Setup analysis** (longest delays → hardest to meet setup)
- **Fast corner → Hold analysis** (shortest delays → hardest to meet hold)

### 2.2 Voltage Corners

| Voltage | Effect on Speed |
|---------|----------------|
| High Vcc | Faster cell delays |
| Low Vcc | Slower cell delays (setup risk), hold easier |

FPGA datasheets specify Vcc_min, Vcc_typ, Vcc_max for each power rail.

### 2.3 Temperature Corners

| Temperature | Effect |
|-------------|--------|
| Cold (-40°C) | Usually faster (lower resistance) but some effects invert at very cold |
| Nominal (+25°C) | Typical |
| Hot (+125°C) | Slower logic and routing (thermal resistance increase) |

---

## 3. FPGA Tool Corners

### 3.1 Vivado

Vivado performs timing analysis at two corners by default:

```
Slow Corner (Worst-Case): Process=Slow, Temperature=85°C (commercial) or 125°C (industrial)
  → Used for setup analysis (Max timing check)
  → Longest delays, hardest to meet Fmax

Fast Corner (Best-Case): Process=Fast, Temperature=0°C (commercial) or -40°C (industrial)
  → Used for hold analysis (Min timing check)
  → Shortest delays, hold violations possible
```

```tcl
# Check which corners are being analyzed
report_timing_summary -check_timing_verbose

# The timing summary header shows the corner:
# "Timing constraints are met for the Slow Corner."
# "Timing constraints are NOT met for the Fast Corner (hold check)."
```

### 3.2 Quartus

TimeQuest supports multiple models:

```tcl
# After loading netlist, apply specific model
# Fast corner for hold
create_timing_netlist -model fast
update_timing_netlist
report_timing -hold -npaths 10

# Slow corner for setup
create_timing_netlist -model slow
update_timing_netlist
report_timing -setup -npaths 10
```

---

## 4. On-Chip Variation (OCV)

Even within a single die, local variations in transistor threshold voltage and oxide thickness cause different delays in different parts of the chip. **OCV derating** accounts for this:

```
Setup check (Max):
  Launch path delay × (1 + derate_factor)   [made slower]
  Capture path delay × (1 - derate_factor)  [made faster]

Hold check (Min):
  Launch path delay × (1 - derate_factor)   [made faster]
  Capture path delay × (1 + derate_factor)  [made slower]
```

Vivado applies OCV automatically based on device characterization. You can see the applied derating:

```tcl
report_timing -path_type full_clock_expanded
# Timing report will show: "clock pessimism: N ns"
```

### 4.1 Parametric OCV (POCV)

POCV is a more statistically rigorous OCV model using Gaussian distributions:

```
Total path delay = Σ(μ_i) ± k × √(Σ(σ²_i))
```

Where `k` is the sigma multiplier for the desired confidence level.

POCV provides **tighter, more accurate** derating than flat OCV:

```tcl
# Vivado: enable POCV (Vivado 2021.2+)
set_property POCVM_ENABLED TRUE [current_design]
```

Typical POCV timing improvement: 50–150 ps compared to flat OCV, allowing 5–10% higher Fmax.

---

## 5. Sign-Off Flow with Multiple Corners

For production designs, always sign off at all relevant corners:

```tcl
## multi_corner_signoff.tcl

set corners {
    {slow "Slow corner (setup)" post_route_slow.dcp}
    {fast "Fast corner (hold)"  post_route_fast.dcp}
}

foreach corner $corners {
    set name  [lindex $corner 0]
    set label [lindex $corner 1]
    set ckpt  [lindex $corner 2]
    
    if {![file exists $ckpt]} {
        puts "SKIP: $ckpt not found"
        continue
    }

    open_checkpoint $ckpt
    puts "\n>>> $label"

    if {$name eq "slow"} {
        report_timing -setup -nworst 10 -file reports/setup_${name}.rpt
        set wns [get_property SLACK [get_timing_paths -setup -max_paths 1]]
        puts "Setup WNS ($name) = $wns ns"
    } else {
        report_timing -hold -nworst 10 -file reports/hold_${name}.rpt
        set whs [get_property SLACK [get_timing_paths -hold -max_paths 1]]
        puts "Hold  WHS ($name) = $whs ns"
    }

    close_design
}
```

---

## 6. Corner Summary for FPGA Sign-Off

| Check | Corner | Criterion |
|-------|--------|-----------|
| Setup | Slow process, high temperature, low Vcc | WNS ≥ 0 |
| Hold | Fast process, low temperature, high Vcc | WHS ≥ 0 |
| Recovery | Slow process | Recovery slack ≥ 0 |
| Removal | Fast process | Removal slack ≥ 0 |
| Pulse width | Both corners | WPWS ≥ 0 |

Always perform **all** checks before tape-out or production deployment.

---

> **See also:** [Best Practices: Design Methodology](../Best-Practices/Design-Methodology.md) | [Resources: Checklists](../Resources/Checklists.md)
