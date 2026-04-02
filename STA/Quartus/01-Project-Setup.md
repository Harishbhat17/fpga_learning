# 01 — Quartus Project Setup for Timing Analysis

> **Navigation:** [← Quartus README](README.md) | [Next: SDC Constraints →](02-SDC-Constraints.md)

---

## 1. Creating a New Project

### 1.1 GUI Flow

1. Open Quartus Prime → **File → New Project Wizard**
2. Set project directory, name, and top-level entity
3. Add HDL source files
4. Select target device (e.g., `5CSEBA6U23I7` for Cyclone V SoC)
5. Add existing SDC files in the **EDA Tool Settings** step or add them after project creation

### 1.2 TCL Batch Flow

```tcl
# create_project.tcl
package require ::quartus::project

project_new my_design -revision my_design -overwrite

# Set device
set_global_assignment -name FAMILY "Cyclone V"
set_global_assignment -name DEVICE 5CSEBA6U23I7

# Set top-level entity
set_global_assignment -name TOP_LEVEL_ENTITY top

# Add source files
set_global_assignment -name VERILOG_FILE src/top.v
set_global_assignment -name VERILOG_FILE src/pipeline.v
set_global_assignment -name VERILOG_FILE src/datapath.v

# Add SDC constraint file
set_global_assignment -name SDC_FILE constraints/top.sdc

project_close
```

---

## 2. Synthesis Settings

### 2.1 Key Settings for Timing Closure

```tcl
# In .qsf project file or via Assignments → Settings:

# Enable register retiming (moves registers across logic)
set_global_assignment -name PHYSICAL_SYNTHESIS_REGISTER_RETIMING ON

# Enable register duplication (fanout optimization)
set_global_assignment -name PHYSICAL_SYNTHESIS_REGISTER_DUPLICATION ON

# Synthesis effort
set_global_assignment -name SYNTHESIS_EFFORT HIGH

# Enable combinational logic optimization
set_global_assignment -name PHYSICAL_SYNTHESIS_COMBO_LOGIC_DUPLICATION ON

# Seed for placement (change if timing not closing)
set_global_assignment -name SEED 1
```

### 2.2 Fitter Settings

```tcl
# Fitter effort
set_global_assignment -name FITTER_EFFORT "STANDARD FIT"
# Options: STANDARD FIT, FAST FIT (less thorough), AUTO FIT

# Optimize for speed
set_global_assignment -name OPTIMIZE_TIMING "NORMAL COMPILATION"
# Options: NORMAL COMPILATION, AGGRESSIVE HOLD TNS, NEVER ALLOW NEGATIVE HOLD TNS

# I/O timing optimization
set_global_assignment -name OPTIMIZE_IOC_REGISTER_PLACEMENT_FOR_TIMING ON
```

---

## 3. Running the Full Compilation

### 3.1 GUI

In the **Task** panel:
1. Double-click **Compile Design** — runs Analysis & Synthesis, Fitter, Assembler, EDA Netlist Writer, and Timing Analysis

Or run individual steps:
1. **Analysis & Synthesis**
2. **Fitter (Place & Route)**
3. **TimeQuest Timing Analysis**
4. **Assembler** (generates .sof bitstream)

### 3.2 Command-Line Batch

```bash
# Full compilation
quartus_sh --flow compile my_design

# Or step-by-step:
quartus_map --read_settings_files=on my_design      # synthesis
quartus_fit --read_settings_files=on my_design      # fitter
quartus_sta my_design --do_report_timing             # timing analysis
quartus_asm my_design                                # assembler (bitstream)
```

### 3.3 TCL Script (from quartus_sh)

```tcl
# compile_and_check.tcl
load_package flow

project_open my_design

# Run full compilation
execute_flow -compile

# Check for timing violations
load_package report
load_report my_design

# Get WNS
set wns [get_fitter_info -status "Worst-case setup slack"]
puts "WNS = $wns ns"

if {[expr {$wns < 0}]} {
    puts "ERROR: Timing not met! WNS = $wns"
    exit 1
} else {
    puts "PASS: Timing closed. WNS = $wns"
}

project_close
```

---

## 4. Incremental Compilation

Quartus supports **partition-based incremental compilation** for large designs:

```tcl
# Define partitions in .qsf
set_global_assignment -name INCREMENTAL_COMPILATION_TYPE FULL_INCREMENTAL_COMPILATION

# Assign a module to a partition
set_instance_assignment -name PARTITION_HIERARCHY ROOT_PARTITION \
    -to "|top|my_module" -section_id my_partition

# Export a previous compilation result
set_global_assignment -name INCREMENTAL_COMPILATION_EXPORT_FILE my_module.qxp \
    -section_id my_partition
```

This allows re-using placement/routing of unchanged modules while only re-compiling changed sections.

---

## 5. Multiple Compilation Seeds

If timing is not closing with the default seed, try different seeds (changes the initial placement randomization):

```bash
for seed in 1 2 3 4 5; do
    quartus_fit --seed=$seed my_design
    quartus_sta my_design --do_report_timing
    # parse WNS from timing report and keep best result
done
```

The Quartus **Design Space Explorer (DSE)** automates this:
```bash
quartus_dse my_design --exploration-space "Fitter Seed Sweep" --seeds 5
```

---

## 6. Analysis at Different Design Stages

| Stage | Tool | Command | Accuracy |
|-------|------|---------|---------|
| Post-synthesis | `quartus_sta` | `report_timing -post_map` | Estimate (no routing) |
| Post-fitting | `quartus_sta` | `report_timing` | **Final (sign-off)** |
| With back-annotation | Timing with parasitics | Same | Highest accuracy |

---

> **Next:** [02 — SDC Constraints](02-SDC-Constraints.md)
