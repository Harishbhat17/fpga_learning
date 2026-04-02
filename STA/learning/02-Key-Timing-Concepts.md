# 02 — Key Timing Concepts

> **Navigation:** [← 01 STA Fundamentals](01-STA-Fundamentals.md) | [STA Index](../README.md) | [Next: Setup & Hold Analysis →](03-Setup-Hold-Analysis.md)

---

## 1. Clock Period and Frequency

The **clock period** `T` is the reciprocal of the clock frequency `f`:

```
T = 1/f
```

For a 200 MHz clock: `T = 5 ns`. The STA tool uses the period to derive the required arrival time at every register data input:

```
Required Arrival Time (setup) = Launch_edge + T - Setup_Time_FF
```

Every register-to-register path must satisfy:

```
T ≥ t_clk2q + t_logic + t_net + t_setup - t_skew
```

Where:
- `t_clk2q` — flip-flop clock-to-Q propagation delay
- `t_logic` — combinational logic delay on the data path
- `t_net` — interconnect routing delay
- `t_setup` — flip-flop setup time requirement
- `t_skew` — clock skew (destination clock arrives later → positive skew helps setup)

---

## 2. Slack

**Slack** is the timing margin on a path:

```
Setup Slack = T_required - T_arrival
           = (Capture_clock_arrival + T - t_setup) - (Launch_clock_arrival + t_clk2q + t_logic + t_net)
```

**Hold Slack** for the same path:

```
Hold Slack = T_arrival - T_required_hold
           = (Launch_clock_arrival + t_clk2q + t_logic + t_net) - (Capture_clock_arrival + t_hold)
```

### Sign Convention

| Slack Value | Meaning |
|-------------|---------|
| `> 0` | Path passes — margin available |
| `= 0` | Path exactly meets requirement |
| `< 0` | **Violation** — path fails timing |

---

## 3. WNS — Worst Negative Slack

**WNS** is the most negative slack value across *all* paths in a timing group (or the entire design):

```
WNS = min(Slack_i)  over all paths i
```

- If WNS ≥ 0, the design meets timing.
- WNS is the **first number to check** in any timing report.
- A WNS of −0.1 ns at 200 MHz means the critical path is 0.1 ns too slow.

---

## 4. TNS — Total Negative Slack

**TNS** is the sum of all negative slack values:

```
TNS = Σ min(Slack_i, 0)  over all endpoints i
```

TNS is a measure of **how much total work** needs to be done to close timing:

| Scenario | WNS | TNS | Interpretation |
|----------|-----|-----|----------------|
| Timing closed | ≥ 0 ns | 0 ns | Design is clean |
| One bad path | −2.0 ns | −2.0 ns | Fix one path |
| Many small violations | −0.1 ns | −50.0 ns | Systemic issue |
| Few large violations | −5.0 ns | −15.0 ns | Architecture problem |

---

## 5. WHS — Worst Hold Slack

**WHS** is the worst (most negative) hold slack:

```
WHS = min(Hold_Slack_i)  over all paths i
```

Hold violations are **not frequency-dependent** — they cannot be fixed by slowing the clock. They must be fixed by:
- Adding delay buffers on the data path
- Timing exceptions (`set_multicycle_path`, `set_false_path` if appropriate)
- Physical constraint changes (if caused by excessive clock skew)

---

## 6. TPWS — Total Pulse Width Slack

Some tools also report **TPWS** — the total pulse-width slack, which measures whether the minimum clock pulse width meets the flip-flop's minimum high/low time requirements. This becomes important at very high frequencies (> 500 MHz) where the pulse width approaches the FF's minimum pulse width specification.

---

## 7. Multi-Cycle Paths (MCP)

By default, STA assumes all register-to-register paths have a **single-cycle relationship**: the data launched on edge `N` must be captured on edge `N+1`.

When the logic between two registers cannot fit in one clock cycle (for example, a multi-stage multiplier), you can declare a **multi-cycle path**:

```tcl
# Vivado / SDC syntax
set_multicycle_path -setup 2 -from [get_cells slow_mult_reg*] -to [get_cells result_reg*]
set_multicycle_path -hold  1 -from [get_cells slow_mult_reg*] -to [get_cells result_reg*]
```

This relaxes the setup check to 2 clock cycles while keeping the hold check one cycle before the (now-relaxed) capture edge.

**Warning:** The `-hold` adjustment is **mandatory** when using `-setup N`. Without it, the hold check becomes excessively tight (hold is checked N-1 cycles before the setup check edge by default).

### MCP Timeline

```
Clock:   ─┬──┬──┬──┬──┬──┬──
           0  1  2  3  4  5  (cycle numbers)

Launch:  FF launches data at edge 0
Capture: FF must capture data at edge 2 (2-cycle MCP setup)
Hold:    Data must remain stable through edge 1 (hold check moved to cycle 1)
```

---

## 8. False Paths

A **false path** is a timing path that exists in the netlist but is **functionally impossible** or **irrelevant** to the design's operation. Declaring it prevents the tool from trying to optimize it:

```tcl
# Example: async reset tree never carries data — ignore it
set_false_path -from [get_ports rst_n]

# Between unrelated clock domains that are not functionally related
set_false_path -from [get_clocks clk_a] -to [get_clocks clk_b]
```

**Caution:** Incorrectly declaring false paths can hide real timing problems. Always document why a path is false.

---

## 9. Clock Uncertainty

The STA tool models uncertainty in clock arrival time to account for:

| Source | Typical Value | Notes |
|--------|--------------|-------|
| PLL/MMCM jitter | 50–200 ps | From device characterization |
| Board-level noise | 20–100 ps | PCB trace impedance mismatch |
| Crosstalk | 10–50 ps | Adjacent signal aggression |
| Safety margin | User-specified | Additional guardband |

```tcl
# Apply additional uncertainty beyond what the tool models automatically
set_clock_uncertainty -setup 0.1 [get_clocks clk_sys]
set_clock_uncertainty -hold  0.05 [get_clocks clk_sys]
```

Total setup margin consumed by uncertainty:

```
Effective_margin = T - WNS - clock_uncertainty
```

---

## 10. Input/Output Delay Constraints

For register-to-output and input-to-register paths, you must specify the external timing relationship:

```tcl
# Input: data arrives 2 ns after the rising clock edge at the FPGA input
set_input_delay -clock clk_sys -max 2.0 [get_ports data_in[*]]
set_input_delay -clock clk_sys -min 0.5 [get_ports data_in[*]]

# Output: downstream device requires data 1.5 ns before the rising edge
set_output_delay -clock clk_sys -max 1.5 [get_ports data_out[*]]
set_output_delay -clock clk_sys -min -0.5 [get_ports data_out[*]]
```

These constraints complete the timing graph at the chip boundary.

---

## 11. Path Groups

The STA tool organizes paths into **path groups**, one per clock domain. Reports are generated per group. Common groups:

| Group | Contents |
|-------|---------|
| `clk_sys` | All paths clocked by `clk_sys` |
| `clk_ddr` | DDR memory interface paths |
| `async_default` | Input-to-output combinational paths (no register) |
| `**default**` | Unconstrained paths (should be empty in a clean design) |

---

## 12. Summary Reference

| Term | Symbol | Formula |
|------|--------|---------|
| Setup slack | `S_su` | `T - (t_clk2q + t_logic + t_net + t_su) + t_skew` |
| Hold slack | `S_h` | `(t_clk2q + t_logic + t_net) - (t_skew + t_h)` |
| WNS | — | `min(S_su)` over all paths |
| TNS | — | `Σ min(S_su, 0)` over all endpoints |
| WHS | — | `min(S_h)` over all paths |
| Frequency | `f` | `1 / (T - WNS)` if WNS < 0 |

---

> **Next:** [03 — Setup & Hold Analysis](03-Setup-Hold-Analysis.md) — Deriving timing equations for flip-flops, metastability window, and guard-banding techniques.
