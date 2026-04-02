# Design Methodology for Timing Closure

> **Navigation:** [← STA Index](../README.md)

---

## 1. Timing-Driven Design Philosophy

**Principle:** Never treat timing as an afterthought. Timing closure decisions start at the architecture stage and are validated at every design step.

---

## 2. The Timing-Driven Design Flow

```
Architecture Design
    │
    ├── Estimate critical path depth (logic levels × cell delay)
    ├── Choose pipeline depth to meet Fmax
    └── Identify clock domains, plan CDC structures

    ↓
RTL Coding
    │
    ├── Write timing-aware RTL (pipeline, register boundaries)
    ├── Add CDC synchronizers where needed
    └── Add timing attributes (ASYNC_REG, dont_retime)

    ↓
Constraints (XDC/SDC)
    │
    ├── Define all clocks
    ├── Set I/O delays
    └── Declare exceptions (false paths, MCPs)

    ↓
Synthesis
    │
    ├── Check post-synthesis timing estimate
    ├── Verify logic level distribution
    └── Fix obvious deep paths (> 2× target)

    ↓
Implementation (Place & Route)
    │
    ├── Check post-placement timing
    ├── Check post-route timing
    └── Apply physical optimization if needed

    ↓
Sign-Off Analysis
    │
    ├── Multi-corner analysis (slow + fast)
    ├── CDC clean (report_cdc: no violations)
    ├── DRC clean
    └── WNS ≥ 0, WHS ≥ 0, TPWS ≥ 0
```

---

## 3. Architecture-Level Guidelines

### 3.1 Frequency-Depth Budget

Before writing RTL, plan the pipeline depth:

```
Maximum logic levels = Target_Period / (t_cell_avg + t_net_avg) - t_setup - t_clk2q

At 200 MHz (5 ns period), UltraScale+:
  t_cell_avg = 0.3 ns, t_net_avg = 0.4 ns per level
  5 ns / (0.3 + 0.4) = 7.1 levels → use ≤ 7 levels as target
```

### 3.2 DSP Pre-Planning

Identify operations that should be mapped to DSPs:
- Multiplications ≥ 8×8 bits → Use DSP
- Multiply-accumulate → Use DSP with PREG+MREG

```verilog
// Signal to synthesis tool to use DSP
(* use_dsp = "yes" *) logic [31:0] mac_result;
```

### 3.3 Clock Domain Planning

Draw a clock domain diagram before coding:

```
     ┌────────────────────────────────────┐
     │                clk_sys (100 MHz)    │
     │  [CPU IF] ──async_fifo──► [DMA]    │
     └─────────────────┬──────────────────┘
                       │  (FIFO)
     ┌─────────────────▼──────────────────┐
     │                clk_dsp (250 MHz)    │
     │  [Filter] → [FFT] → [Accumulator]  │
     └─────────────────┬──────────────────┘
                       │  (handshake)
     ┌─────────────────▼──────────────────┐
     │                clk_io (50 MHz)      │
     │  [UART TX] ◄── [Format]            │
     └────────────────────────────────────┘
```

---

## 4. RTL Coding for Timing

### 4.1 Preferred Register Patterns

```verilog
// ✅ Clean synchronous reset (preferred — allows Vivado FDRE inference)
always_ff @(posedge clk) begin
    if (!rst_n) q <= '0;
    else        q <= d;
end

// ⚠️ Async reset (use only when reset must be immediate)
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) q <= '0;
    else        q <= d;
end
```

### 4.2 Avoid Long Chains

```verilog
// ❌ AVOID: shifts as long chains (poor timing, hard to retime)
always_ff @(posedge clk)
    shift_reg <= {shift_reg[62:0], data_in};  // 64-bit shift

// ✅ PREFER: BRAM-based or indexed approach for long delays
```

### 4.3 Parameter for Pipeline Depth

Make pipeline depth a parameter for easy adjustment:

```verilog
module filter #(parameter STAGES = 4) (
    input  logic clk,
    input  logic [15:0] data_in,
    output logic [15:0] data_out
);
    logic [15:0] pipe [STAGES-1:0];
    
    always_ff @(posedge clk) begin
        pipe[0] <= process(data_in);
        for (int i = 1; i < STAGES; i++)
            pipe[i] <= pipe[i-1];
    end
    
    assign data_out = pipe[STAGES-1];
endmodule
```

---

## 5. Iterative Timing Closure Process

```
Iteration 1:
  → Synthesize with PerformanceOptimized
  → Check logic levels; fix obvious deep paths in RTL
  → Re-synthesize

Iteration 2:
  → Run implementation (default strategy)
  → Check WNS; if < -0.5 ns, RTL changes needed
  → If -0.5 < WNS < 0, try aggressive strategy

Iteration 3:
  → Performance_ExplorePostRoutePhysOpt strategy
  → phys_opt_design AggressiveExplore
  → Pblocks for routing-dominated paths

Iteration 4:
  → If still failing, check if constraint issue
  → Run check_timing; verify all paths are constrained
  → Consider: is target Fmax achievable with current architecture?
```

---

## 6. When to Stop and Rearchitect

Signs that timing closure is an **architecture problem**, not an optimization problem:

| Symptom | Implication |
|---------|------------|
| WNS > −2 ns after aggressive opt | RTL changes needed |
| TNS > −50 ns with 100+ violations | Systemic logic depth issue |
| Logic levels consistently 12–16 | Pipeline stages missing |
| Vivado reports "Timing cannot be met" even with maximum effort | Frequency target too high for architecture |

In these cases, revisit the RTL design rather than spending more time on implementation strategies.

---

> **See also:** [Optimization Checklist](Optimization-Checklist.md) | [Common Mistakes](Common-Mistakes.md)
