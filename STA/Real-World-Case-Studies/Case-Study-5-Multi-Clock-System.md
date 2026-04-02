# Case Study 5 — Multi-Clock SoC Timing Closure

> **Navigation:** [← Case Studies README](README.md) | [STA Index](../README.md)

---

## Design Specification

| Parameter | Value |
|-----------|-------|
| Device | Xilinx UltraScale+ xczu7ev |
| Design | 4-domain SoC (CPU interface, DSP, video, I/O) |
| Domains | clk_cpu (200 MHz), clk_dsp (300 MHz), clk_pixel (148.5 MHz), clk_io (100 MHz) |
| CDC crossings | 6 unique domain-pairs |
| Total registers | 95,000 |
| Challenge | Simultaneous timing closure in all domains + CDC |

---

## Initial Status

```
Domain          WNS (ns)    WHS (ns)    Status
clk_cpu (200M)   +0.241      +0.032     PASS
clk_dsp (300M)   -0.712      -0.031     FAIL (setup + hold)
clk_pixel        +0.087      +0.041     PASS
clk_io           +0.312      +0.021     PASS
CDC report       3 violations           FAIL
```

Two problems: clk_dsp setup AND hold violations, plus CDC violations.

---

## Diagnosis

### Problem 1: clk_dsp Setup Violations

```
Worst path (clk_dsp):
Slack: -0.712 ns
From: dsp_pipeline_reg[31] 
To:   dsp_output_reg[31]

Data:  3.712 ns (logic 1.947 ns = 52%, route 1.765 ns = 48%)
Levels: 8
(At 300 MHz: period = 3.333 ns, max logic ~2.8 ns with margin)
```

8 levels at 300 MHz is too deep — target is ≤ 6 levels.

### Problem 2: clk_dsp Hold Violations

```
Worst hold path:
Slack: -0.031 ns
From: dsp_pre_reg[7]
To:   dsp_pipeline_reg[7]

Hold violation! Very short path (0.156 ns data delay).
Clock skew: +0.187 ns (hurts hold).
```

The DSP clock tree has 187 ps of skew on this path — too much for the short data path to absorb.

### Problem 3: CDC Violations

```
report_cdc:
Violation 1 (MULTI_BIT_COMBO):
  From: clk_cpu
  To:   clk_dsp
  Net:  cpu_command_bus[7:0]
  8-bit binary bus crossing directly — no synchronizer

Violation 2 (COMBO_LOGIC):
  From: clk_cpu
  To:   clk_pixel
  Net:  frame_control — combinational, not registered before crossing

Violation 3 (MULTI_BIT_COMBO):
  From: clk_dsp to clk_io
  Net:  result_bus[15:0] — 16-bit binary bus
```

---

## Fixes

### Fix 1: DSP Domain Pipelining

The 8-level path was in the complex exponential calculation:

```verilog
// Before: one stage (8 levels)
always_ff @(posedge clk_dsp)
    dsp_output <= exp_re(a) * cos_table(b) + exp_im(a) * sin_table(c);

// After: two stages (4 levels each)
always_ff @(posedge clk_dsp) begin
    stage_re <= exp_re(a) * cos_table(b);  // stage N
    stage_im <= exp_im(a) * sin_table(c);  // stage N
end
always_ff @(posedge clk_dsp)
    dsp_output <= stage_re + stage_im;     // stage N+1
```

### Fix 2: Hold Fix — Pblock for DSP Domain

The 187 ps hold-hurting skew was caused by the short path registers being in different clock regions from the long path registers (different clock tree branches):

```tcl
# Co-locate all DSP domain registers in the same clock region
create_pblock pbl_dsp_domain
add_cells_to_pblock pbl_dsp_domain [get_cells -hierarchical {dsp_*}]
resize_pblock pbl_dsp_domain -add {CLOCKREGION_X2Y2:CLOCKREGION_X4Y4}
set_property IS_SOFT TRUE [get_pblocks pbl_dsp_domain]
```

After Pblock, the maximum skew within the domain dropped from 187 ps to 54 ps, resolving hold.

For any remaining hold violations, post-route phys_opt fixed them:
```tcl
phys_opt_design -hold_fix -directive AggressiveExplore
```

### Fix 3: CDC Violations

**Violation 1** (cpu_command_bus): Replace with async FIFO:

```verilog
async_fifo #(.DATA_WIDTH(8), .FIFO_DEPTH(8)) cmd_fifo (
    .wr_clk(clk_cpu), .rd_clk(clk_dsp),
    .wr_en(cmd_valid_cpu), .wr_data(cpu_command_bus),
    .rd_en(cmd_ready_dsp), .rd_data(dsp_command),
    .full(cmd_full), .empty(cmd_empty)
);
```

**Violation 2** (frame_control): Register before crossing + 2-FF sync:

```verilog
// Register in source domain
logic frame_ctrl_reg;
always_ff @(posedge clk_cpu) frame_ctrl_reg <= frame_control;

// 2-FF sync to clk_pixel
cdc_sync_2ff u_frame_sync (
    .clk_dst(clk_pixel), .data_in(frame_ctrl_reg),
    .data_out(frame_ctrl_synced)
);
```

**Violation 3** (result_bus[15:0]): Replace with handshake:

```verilog
cdc_handshake #(.DATA_WIDTH(16)) u_result_hs (
    .clk_src(clk_dsp), .send_req(result_valid_dsp), .data_src(result_bus),
    .send_ack(result_ack_dsp),
    .clk_dst(clk_io),  .data_valid(result_valid_io), .data_dst(result_io)
);
```

---

## Final Results

```
Domain          WNS (ns)    WHS (ns)    Status
clk_cpu (200M)   +0.241      +0.032     PASS
clk_dsp (300M)   +0.089      +0.014     PASS (fixed!)
clk_pixel        +0.087      +0.041     PASS
clk_io           +0.312      +0.021     PASS
CDC report       0 violations            PASS (fixed!)
```

---

## Key Multi-Domain Lessons

1. **Fix the most constrained domain first** — in this case clk_dsp at 300 MHz
2. **Hold violations in fast domains** → check clock skew, use Pblocks
3. **CDC violations always require RTL fixes** — async FIFO, 2-FF sync, handshake
4. **Pblocks reduce skew within a domain** — especially useful at 300+ MHz
5. **Never ignore CDC violations** — they cause random, hard-to-debug failures in the field

---

> **See also:** [CDC Fundamentals](../CDC-Clock-Domain-Crossing/CDC-Fundamentals.md) | [Best Practices](../Best-Practices/Design-Methodology.md)
