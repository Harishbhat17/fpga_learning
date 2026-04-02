# CDC Fundamentals

> **Navigation:** [← CDC README](README.md) | [Next: Synchronization Techniques →](Synchronization-Techniques.md)

---

## 1. What Is a Clock Domain Crossing?

A **Clock Domain Crossing (CDC)** occurs when a digital signal transitions from logic clocked by one clock (`clk_src`) to logic clocked by a different clock (`clk_dst`). The two clocks may:

- Have **different frequencies** (e.g., 100 MHz → 50 MHz)
- Have **the same frequency but unknown phase** (two independent oscillators)
- Have **a known frequency ratio but no phase lock** (divided clocks from different PLLs)

Any of these situations can lead to **metastability** if the crossing is not handled correctly.

---

## 2. The Metastability Window

Every flip-flop has a **metastability window** `T_W` (typically 5–50 ps) centered around the active clock edge. If a data input changes within this window, the flip-flop may enter a metastable state:

```
       T_W
    ←──┤├──→
───────┬────────────  Data toggles inside window → metastability risk
  ____/                
─╱────╲──────────────  Clock edge at t=0
```

In a metastable state:
- The output is neither a clean 0 nor a clean 1
- It will eventually resolve, but the resolution time is random
- If the metastable output is sampled before resolving, errors propagate downstream

---

## 3. Metastability Resolution

After a metastability event, the output resolves exponentially toward a valid logic level:

```
V_out(t) = V_threshold + ΔV · e^((t - t_event) / τ)
```

Where:
- `t_event` = time of the violating clock edge
- `τ` = device-specific metastability resolution time constant
- `ΔV` = initial perturbation from threshold

For modern FPGAs, `τ` is typically 20–50 ps. This means that even 1 ns after the clock edge, the probability of still being metastable is:

```
P(still_meta at t=1ns) = exp(-1000ps / 50ps) = exp(-20) ≈ 2 × 10⁻⁹
```

With a full clock period available (e.g., 5 ns at 200 MHz):
```
P(still_meta at t=5ns) = exp(-5000ps / 50ps) = exp(-100) ≈ 3.7 × 10⁻⁴⁴
```

This is effectively zero — after one full clock period, metastability has resolved.

---

## 4. MTBF — Mean Time Between Failures

The probability of metastability causing an error determines the design's reliability:

```
MTBF = exp(T_resolve / τ) / (f_launch × f_capture × T_W)
```

Where:
- `T_resolve` = time from clock edge to when data is sampled (≈ one clock period minus routing overhead)
- `f_launch` = frequency at which data can change in the source domain
- `f_capture` = frequency of the destination clock
- `T_W` = metastability window

### Example: Single Synchronizer Stage

- `f_capture = 200 MHz` → `T = 5 ns`
- `f_launch = 100 MHz`
- `T_W = 20 ps`
- `τ = 40 ps`
- `T_resolve = 4.5 ns` (5 ns period minus 0.5 ns overhead)

```
MTBF = exp(4500/40) / (100×10⁶ × 200×10⁶ × 20×10⁻¹²)
     = exp(112.5) / (400 × 10⁻³)
     ≈ 10^{48.8} / 0.4
     ≈ 1.6 × 10^{48} seconds  (far exceeds the age of the universe)
```

Even a single synchronizer stage is astronomically safe at these frequencies. However, the MTBF degrades with:
- Very high frequencies (shorter T_resolve)
- Pathological τ due to process variation or temperature

A **double synchronizer** (2-stage 2-FF) doubles `T_resolve`, making:
```
MTBF_2stage ≈ exp(2 × 112.5 / 1) / same_denominator = 10^{97.6} seconds
```

---

## 5. Multi-Bit CDC Hazards

### 5.1 The Binary Counter Problem

Suppose you have a 4-bit binary counter in clk_src and you sample it in clk_dst:

```
Counter counts: ... 0111 → 1000 ...
                     ↑
                  Transition changes ALL 4 bits simultaneously!
```

If the destination FF samples during the transition, it may capture any of:
`0000, 0001, ..., 1111` — a completely random value, not just the old or new count.

### 5.2 Gray Code Solution

A **Gray code** counter changes **only one bit** per count transition:

```
Binary: 0111 → 1000  (4 bits change simultaneously — BAD for CDC)
Gray:   0100 → 1100  (only 1 bit changes — safe for 2-FF synchronization)
```

Gray code is used for async FIFO pointer crossing (see [Synchronization Techniques](Synchronization-Techniques.md)).

### 5.3 Combinational Output CDC

Never use combinational logic output directly in another clock domain:

```verilog
// DANGEROUS:
assign status = (state == ACTIVE) | input_flag;  // combinational
// Reading 'status' in another domain may catch glitches
```

**Always register before crossing:**
```verilog
always_ff @(posedge clk_src) begin
    status_r <= (state == ACTIVE) | input_flag;  // registered
end
// Then synchronize status_r with a 2-FF sync
```

---

## 6. Tool CDC Checking

Both Vivado and Quartus perform automated CDC checking:

### Vivado
```tcl
report_cdc -details -file cdc_report.rpt
```
Violations categories:
- `COMBO_LOGIC` — combinational logic in clock domain boundary
- `MULTI_BIT_COMBO` — multi-bit bus crossing without synchronizer
- `MISSING_CDC` — path crosses domains without any synchronizer

### Quartus
```tcl
report_cdc -panel_name "CDC Analysis"
```
Look for:
- `No synchronization` — path with no synchronizer
- `Potential metastability` — single FF synchronizer (not 2-stage)

---

## 7. Summary

| Concept | Key Point |
|---------|-----------|
| Metastability window | 5–50 ps window where FF can go metastable |
| Resolution time τ | ~20–50 ps; probability drops exponentially over time |
| MTBF | One synchronizer stage is sufficient; two stages is overkill-safe |
| Binary counter CDC | NEVER directly; causes random multi-bit errors |
| Gray code | Only 1 bit changes per count → safe for 2-FF sync |
| Combinational CDC | Always register before crossing |

---

> **Next:** [Synchronization Techniques](Synchronization-Techniques.md) — 2-FF synchronizer, pulse sync, handshake, Gray-code pointer, and async FIFO.
