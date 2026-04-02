# 03 — Setup and Hold Analysis

> **Navigation:** [← 02 Key Timing Concepts](02-Key-Timing-Concepts.md) | [STA Index](../README.md) | [Next: Clock Skew Management →](04-Clock-Skew-Management.md)

---

## 1. The Setup Constraint — Full Derivation

Consider two positive-edge-triggered flip-flops connected through combinational logic:

```
         clk_launch ─────────────────────────────────
                │                                    │
                │ (launch clock delay = T_clk_src)   │ (capture clock delay = T_clk_dst)
                ▼                                    ▼
         ┌─────────┐   t_clk2q    ┌──────────┐     ┌─────────┐
clk ─────►  FF_src  ├─────────────► Comb. Logic├────► FF_dst  │
         └─────────┘              │ t_logic   │     │ t_setup │
                                  └──────────┘     └─────────┘
```

### 1.1 Launch and Capture Edges

The STA tool identifies:
- **Launch edge** (`L`): the active clock edge that launches data from `FF_src`
- **Capture edge** (`C`): the next active edge that captures data at `FF_dst`

For a single-cycle path with period `T`:

```
C = L + T
```

### 1.2 Data Arrival Time at FF_dst

```
T_arrival = L + T_clk_src + t_clk2q + t_logic + t_net
```

Where `T_clk_src` is the total clock delay from the clock definition to `FF_src`'s clock pin.

### 1.3 Required Arrival Time (Setup)

```
T_required = C + T_clk_dst - t_setup
           = (L + T) + T_clk_dst - t_setup
```

### 1.4 Setup Slack Equation

```
Setup_Slack = T_required - T_arrival
            = (L + T + T_clk_dst - t_setup) - (L + T_clk_src + t_clk2q + t_logic + t_net)
            = T + (T_clk_dst - T_clk_src) - t_setup - t_clk2q - t_logic - t_net
            = T + t_skew_helpful - t_setup - t_clk2q - t_logic - t_net
```

**Key insight:** Clock skew (`T_clk_dst - T_clk_src`) is **positive** (helpful for setup) when the destination clock arrives *later* than the source clock.

---

## 2. The Hold Constraint — Full Derivation

The hold check verifies that data from the **current** launch edge does not arrive so quickly that it corrupts the capture of the **previous** cycle's data.

### 2.1 Hold Data Arrival Time

Same as setup:

```
T_arrival = L + T_clk_src + t_clk2q + t_logic + t_net
```

But now we use the **same capture edge** as the launch edge (one cycle window):

```
T_required_hold = L + T_clk_dst + t_hold
```

### 2.2 Hold Slack Equation

```
Hold_Slack = T_arrival - T_required_hold
           = (L + T_clk_src + t_clk2q + t_logic + t_net) - (L + T_clk_dst + t_hold)
           = (T_clk_src - T_clk_dst) + t_clk2q + t_logic + t_net - t_hold
           = -t_skew_helpful + t_clk2q + t_logic + t_net - t_hold
```

**Key insight:** The skew direction that helps setup **hurts** hold. When the destination clock arrives later than the source (positive skew), hold slack decreases.

---

## 3. Typical Flip-Flop Timing Parameters (Example: Xilinx FDRE in UltraScale+)

| Parameter | Typical Value | Description |
|-----------|--------------|-------------|
| t_setup | 50 ps | Data must arrive 50 ps before clock edge |
| t_hold | 30 ps | Data must remain stable 30 ps after clock edge |
| t_clk2q (rising) | 120 ps | Output valid 120 ps after rising clock edge |
| t_clk2q (falling) | 140 ps | Output valid 140 ps after falling clock edge |
| Minimum pulse width | 900 ps | Minimum clock HIGH or LOW time |

*Values are illustrative; refer to device datasheets for production sign-off.*

---

## 4. Metastability

### 4.1 What Is Metastability?

When a flip-flop's setup or hold time is violated, the output can enter a **metastable** state — neither a clean logic 0 nor a clean logic 1. It eventually resolves, but the resolution time is random and unbounded in theory.

The probability that a FF remains metastable beyond time `t` after the clock edge:

```
P(metastable at time t) = f_data × f_clk × T_W × exp(-t / τ)
```

Where:
- `f_data` — data toggle frequency
- `f_clk` — capture clock frequency
- `T_W` — metastability window width (ps) — the time window around the clock edge where violations can occur
- `τ` — technology-specific metastability resolution time constant (ps)

### 4.2 Mean Time Between Failures (MTBF)

The MTBF for a single synchronizer stage:

```
MTBF = exp(t_res / τ) / (f_data × f_clk × T_W)
```

Where `t_res` is the time available for resolution (typically one full clock period minus routing delays).

#### Example Calculation

- `f_clk = 200 MHz` → `T = 5 ns`
- `f_data = 100 MHz` (toggle frequency)
- `T_W = 10 ps` (metastability window)
- `τ = 30 ps` (characteristic resolution time constant)
- `t_res = 4.5 ns` (period minus FF overhead)

```
MTBF = exp(4500/30) / (100×10⁶ × 200×10⁶ × 10×10⁻¹²)
     = exp(150) / (0.2)
     ≈ 10^65 / 0.2
     ≈ 5 × 10^65 seconds  (astronomically safe)
```

Adding a second synchronizer stage doubles `t_res` (two full periods) and makes MTBF essentially infinite.

---

## 5. Guard-Banding and Margin Strategies

### 5.1 Timing Margin Hierarchy

```
Clock Period (T)
├── Setup Time (t_setup)
├── Clock-to-Q (t_clk2q)
├── Logic + Net delay (t_logic + t_net)
├── Clock Uncertainty (t_jitter + t_noise)
└── Remaining Slack  ← this is what you optimize
```

### 5.2 Common Guard-Band Recommendations

| Source | Guard-Band | How to Apply |
|--------|-----------|--------------|
| PLL output jitter | 100–150 ps | `set_clock_uncertainty -setup` |
| Board-level noise | 50–100 ps | Included in `set_input_delay` margin |
| OCV derating | 3–5% | Tool-applied automatically |
| Safety sign-off margin | 0.1 × T | Constrain to 0.9 × `target_period` |

### 5.3 Timing Closure Sign-Off Criteria

A design is considered timing-clean when:
1. WNS ≥ 0 ns (all setup paths pass)
2. WHS ≥ 0 ns (all hold paths pass)
3. TPWS ≥ 0 ns (clock pulse width meets FF minimums)
4. All recovery/removal checks pass

---

## 6. Recovery and Removal Checks

Asynchronous reset/set signals have their own timing checks analogous to setup/hold:

- **Recovery time:** An asynchronous reset must be deasserted *at least* `t_recovery` before the next active clock edge to guarantee the FF comes out of reset cleanly.
- **Removal time:** An asynchronous reset must remain asserted *at least* `t_removal` after the active clock edge.

```tcl
# Constrain async reset de-assertion
set_false_path -from [get_ports rst_n] -to [get_cells -hierarchical -filter {IS_SEQUENTIAL}]
# OR, properly constrain the recovery time:
create_clock -period 10 [get_ports clk]
set_input_delay -clock clk -max 2.0 [get_ports rst_n]  # recovery constraint
```

---

## 7. Worked Example: Finding the Critical Path

Given the following post-route timing report excerpt:

```
Path Group:    clk_sys
Path Type:     Setup
WNS:           -0.285 ns

Source:        pipeline_reg[15]/C  (rising edge-triggered FF)
Destination:   output_reg[15]/D    (rising edge-triggered FF)

Clock path skew: -0.032 ns  (destination arrives earlier → hurts setup)

Data Path:
  pipeline_reg[15]/C → pipeline_reg[15]/Q   0.141 ns  (clk2q)
  Q → LUT6/I0 (net)                         0.312 ns  (routing)
  LUT6/I0 → LUT6/O (cell)                  0.201 ns  (combinational)
  LUT6/O → CARRY8/S[3] (net)               0.089 ns  (routing)
  CARRY8/S[3] → CARRY8/CO[7] (cell)        0.456 ns  (carry chain)
  CARRY8/CO[7] → output_reg[15]/D (net)    0.223 ns  (routing)

  Total data path:                          1.422 ns
  Clock period:                             5.000 ns
  Required time:                            4.968 ns  (5.000 - 0.032 skew - 0.050 setup)
  Arrival time:                             5.253 ns  (0.285 launch delay + 1.422 data + 3.546 launch clk)
  Slack:                                   -0.285 ns  VIOLATED
```

**Diagnosis:** The 8-bit carry chain through `CARRY8` is consuming 0.456 ns — nearly a third of the data path. The fix is to pipeline the carry result.

---

## 8. Summary

| Check | Equation | When Violated |
|-------|----------|---------------|
| Setup | `T + skew ≥ t_clk2q + t_logic + t_net + t_setup + t_uncertainty` | Data path too slow |
| Hold | `t_clk2q + t_logic + t_net ≥ t_hold + t_skew + t_uncertainty` | Data path too fast |
| Recovery | `t_reset_deassert_to_clk ≥ t_recovery` | Async reset deasserted too close to clock edge |
| Removal | `t_reset_assert_after_clk ≥ t_removal` | Async reset asserted too close to clock edge |

---

> **Next:** [04 — Clock Skew Management](04-Clock-Skew-Management.md) — Clock trees, MMCM/PLL configuration, and skew optimization strategies.
