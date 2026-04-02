# Pipelining Strategies

> **Navigation:** [← STA Index](../README.md) | [← Retiming](Retiming-Optimization.md)

---

## 1. Why Pipeline?

The fundamental timing equation for any register-to-register path:

```
T_period ≥ t_clk2q + t_logic + t_net + t_setup - t_skew
```

Pipelining reduces `t_logic` by breaking a long combinational chain into shorter segments separated by registers. This allows:
- Higher clock frequency (shorter combinational depth per stage)
- Higher throughput (new inputs accepted every clock cycle)
- At the cost of **latency** (result available after N clock cycles instead of 1)

---

## 2. Identifying Pipeline Opportunities

### 2.1 Logic Level Analysis

```tcl
# Vivado
report_design_analysis -logic_level_distribution

# Quartus  
report_timing -setup -npaths 100 -detail summary | grep "logic levels"
```

**Rule of thumb for Xilinx UltraScale+ at various frequencies:**

| Target Freq | Max Recommended Logic Levels |
|-------------|------------------------------|
| 100 MHz | 12–16 |
| 150 MHz | 8–12 |
| 200 MHz | 6–8 |
| 250 MHz | 5–6 |
| 300 MHz | 4–5 |
| 500 MHz | 2–3 |

### 2.2 Common High-Level Patterns

| Operation | Logic Levels | Pipeline Stage Count |
|-----------|-------------|---------------------|
| 8-bit add | 2–3 | 1 |
| 16-bit add | 3–4 | 1 |
| 32-bit add | 4–6 | 1–2 |
| 8×8 multiply | 4–6 | 1–2 |
| 16×16 multiply | 8–12 | 2–3 (or use DSP) |
| 32-bit divide | 32+ | 6–8 (iterative) |
| 5×5 convolve | 12–18 | 3–4 |

---

## 3. Pipeline Design Patterns

### 3.1 Simple Linear Pipeline

```verilog
// 4-stage pipeline for a complex expression
module pipeline_example #(parameter W = 16) (
    input  logic         clk,
    input  logic [W-1:0] a, b, c, d,
    output logic [W-1:0] result
);
    logic [W-1:0] s1, s2, s3;

    // Stage 1: multiply a×b, c×d in parallel (use DSP blocks)
    logic [2*W-1:0] ab, cd;
    always_ff @(posedge clk) begin
        ab <= a * b;
        cd <= c * d;
    end

    // Stage 2: add partial products
    logic [2*W:0] sum_ab_cd;
    always_ff @(posedge clk)
        sum_ab_cd <= ab + cd;

    // Stage 3: accumulate with previous result
    // (previous result also needs to be delayed to align with this stage)
    always_ff @(posedge clk)
        result <= sum_ab_cd[W-1:0];

endmodule
```

### 3.2 Pipeline with Flow Control (Valid/Ready)

```verilog
module pipeline_handshake #(parameter W = 8, STAGES = 4) (
    input  logic         clk, rst_n,
    input  logic [W-1:0] data_in,
    input  logic         valid_in,
    output logic         ready_out,    // Can accept new data
    output logic [W-1:0] data_out,
    output logic         valid_out
);
    // Pipeline valid signals — one per stage
    logic [STAGES-1:0] valid_pipe;
    logic [W-1:0]      data_pipe [STAGES-1:0];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_pipe <= '0;
        end else begin
            valid_pipe[0] <= valid_in;
            for (int i = 1; i < STAGES; i++)
                valid_pipe[i] <= valid_pipe[i-1];
        end
    end

    always_ff @(posedge clk) begin
        if (valid_in) data_pipe[0] <= process_stage0(data_in);
        for (int i = 1; i < STAGES; i++)
            if (valid_pipe[i-1]) data_pipe[i] <= process_stageN(data_pipe[i-1], i);
    end

    assign data_out  = data_pipe[STAGES-1];
    assign valid_out = valid_pipe[STAGES-1];
    assign ready_out = 1'b1;  // Simple pipeline always accepts (no stall)

endmodule
```

### 3.3 Bubble Pipeline (with Stall)

For pipelines that must support stalls (e.g., cache miss, memory wait):

```verilog
module bubble_pipeline (
    input  logic clk, rst_n,
    input  logic stall,      // Freeze all stages when high
    // ... ports
);
    logic [STAGES-1:0] valid;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid <= '0;
        end else if (!stall) begin
            valid[0] <= valid_in;
            for (int i = 1; i < STAGES; i++)
                valid[i] <= valid[i-1];
            // Insert bubble (invalid stage) when stall deasserts
        end
    end

    // Each pipeline stage register only updates when not stalled
    always_ff @(posedge clk) begin
        if (!stall) begin
            stage_reg[0] <= input_data;
            for (int i = 1; i < STAGES; i++)
                stage_reg[i] <= stage_reg[i-1];
        end
    end

endmodule
```

---

## 4. Pipeline Balancing

When adding pipeline registers, maintain the **correct alignment** of dependent signals:

```verilog
// Example: 3-stage pipeline where addr and data must arrive together at stage 3
module aligned_pipeline (
    input logic clk,
    input logic [15:0] addr,
    input logic [31:0] data
);
    // addr goes through 3 register stages (aligns with 3-stage data path)
    logic [15:0] addr_p1, addr_p2, addr_p3;
    always_ff @(posedge clk) begin
        addr_p1 <= addr;    // stage 1
        addr_p2 <= addr_p1; // stage 2
        addr_p3 <= addr_p2; // stage 3 ← arrives same time as processed data
    end

    // Data takes 3 cycles to process
    logic [31:0] data_s1, data_s2, data_s3;
    always_ff @(posedge clk) data_s1 <= process1(data);
    always_ff @(posedge clk) data_s2 <= process2(data_s1);
    always_ff @(posedge clk) data_s3 <= process3(data_s2);

    // Both addr_p3 and data_s3 are now aligned at stage 3
endmodule
```

---

## 5. Timing Constraints for Pipelined Designs

When a path spans multiple pipeline stages (e.g., a 3-cycle multiply):

```tcl
# Vivado: tell STA that these registers have a 3-cycle relationship
set_multicycle_path -setup 3 \
    -from [get_cells -hierarchical mul_input_reg*] \
    -to   [get_cells -hierarchical mul_result_reg*]

set_multicycle_path -hold 2 \
    -from [get_cells -hierarchical mul_input_reg*] \
    -to   [get_cells -hierarchical mul_result_reg*]
```

---

## 6. Trade-off Summary

| Aspect | 1-Stage | 2-Stage | 4-Stage |
|--------|---------|---------|---------|
| Max frequency | Low | Medium | High |
| Latency | 1 cycle | 2 cycles | 4 cycles |
| Throughput | Low | Medium | High (1/cycle) |
| Resources | Low | Medium | High (more FFs) |
| Design complexity | Simple | Moderate | Complex |

---

> **See also:** [Register Balancing](Register-Balancing.md) | [Vivado Case Study 1](../Vivado/case_studies/Case-Study-1-Image-Processing.md)
