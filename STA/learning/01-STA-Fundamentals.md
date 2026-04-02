# 01 — Static Timing Analysis Fundamentals

> **Navigation:** [← STA Index](../README.md) | [Next: Key Timing Concepts →](02-Key-Timing-Concepts.md)

---

## 1. What Is Static Timing Analysis?

Static Timing Analysis (STA) is a formal, exhaustive method of verifying that a digital circuit meets its timing requirements across **all possible data patterns** and without running a single simulation vector. The word *static* means the analysis is purely mathematical: the tool traverses the timing graph of the netlist and computes the worst-case delay along every path.

### Why Not Just Simulate?

| Approach | Coverage | Speed | Setup/Hold Checking |
|----------|----------|-------|---------------------|
| Full gate-level simulation | Pattern-dependent (never exhaustive) | Very slow for large designs | Requires specific test vectors |
| Static Timing Analysis | **100% path coverage** | Fast (minutes on million-gate designs) | Automatic, exhaustive |

STA guarantees that if all timing paths pass, the design will work at the target frequency for any data input.

---

## 2. The Timing Graph

The STA tool models the design as a **directed acyclic graph (DAG)**:

```
Primary Input / Clock Pin
        │
        ▼
   [Combinational Logic Gates]
        │
        ▼
   Register (FF) D-pin  ───────  Register (FF) Q-pin
        │                               │
        ▼                               ▼
   [More Logic]                  [Output Logic]
        │                               │
        ▼                               ▼
   Register (FF) D-pin         Primary Output
```

- **Nodes** represent logic elements (gates, flip-flops, I/O pads).
- **Edges** represent interconnect wires, annotated with propagation delay.
- **Source nodes** are either primary inputs or flip-flop clock-to-Q outputs.
- **Sink nodes** are either primary outputs or flip-flop data inputs.

### Path Types

| Type | Start Point | End Point |
|------|-------------|-----------|
| Register-to-register (reg2reg) | FF clock pin | FF data (D) pin |
| Input-to-register (in2reg) | Primary input port | FF data pin |
| Register-to-output (reg2out) | FF clock pin | Primary output port |
| Input-to-output (in2out) | Primary input | Primary output |

---

## 3. How the Tool Builds the Model

### 3.1 Netlist Parsing

After synthesis or place-and-route, the tool reads:
- Gate-level netlist (EDIF, netlist checkpoint `.dcp` in Vivado, `.qxp` in Quartus)
- Liberty timing libraries (`.lib`/`.lef`) describing cell delays as a function of input transition and output load
- Interconnect parasitics extracted from the placed-and-routed database

### 3.2 Annotating Delays

Each arc from pin A to pin B in a cell has a delay table indexed by:

```
d(A→B) = f(input_transition_time, output_capacitive_load)
```

For example, a 2-input AND gate may have:

| Input Transition (ps) | Load (fF) | Rise Delay (ps) | Fall Delay (ps) |
|----------------------|-----------|-----------------|-----------------|
| 50 | 5 | 82 | 74 |
| 50 | 20 | 145 | 131 |
| 200 | 20 | 167 | 152 |

The tool interpolates between table entries for actual operating conditions.

### 3.3 Clock Propagation

The tool traces every clock definition through buffers, PLLs, and clock muxes to every register clock pin. Along the way it accumulates:
- **Clock source latency**: delay from the clock definition point to the chip pin
- **Clock network latency (insertion delay)**: delay inside the chip from the clock pin to the register clock pin
- **Clock skew**: difference in arrival times between source and destination registers

---

## 4. The STA Flow

```
Synthesized/Implemented Netlist
         │
         ▼
   Read Timing Libraries
         │
         ▼
   Apply Constraints (XDC / SDC)
         │
         ▼
   Build Timing Graph
         │
         ▼
   Propagate Arrival Times (forward)
         │
         ▼
   Propagate Required Times (backward)
         │
         ▼
   Compute Slack = Required − Arrival
         │
         ▼
   Report (TNS, WNS, paths)
```

### 4.1 Forward Propagation (Arrival Time)

Starting from every source, the tool computes the **arrival time (AT)** at every node:

```
AT(sink) = max[ AT(source) + delay(source→sink) ]  for all driving sources
```

The maximum is taken because we must satisfy the constraint for the **slowest** path that can reach the sink.

### 4.2 Backward Propagation (Required Arrival Time)

From every constrained endpoint the tool works backward to compute the **required arrival time (RAT)**:

```
RAT(source) = min[ RAT(sink) - delay(source→sink) ]  for all driven sinks
```

### 4.3 Slack

```
Slack = RAT - AT
```

- **Positive slack (≥ 0):** path meets timing — the signal arrives before it is required.
- **Negative slack (< 0):** **timing violation** — the signal arrives too late.

---

## 5. Timing Arcs and Checks

### 5.1 Cell Timing Arcs

Every combinational cell has **combinational arcs** (input pin → output pin). Flip-flops have:
- **Setup arc:** data must arrive *before* the clock edge by the setup time
- **Hold arc:** data must remain stable *after* the clock edge by the hold time
- **Clock-to-Q arc:** propagation delay from active clock edge to Q output

### 5.2 Net Delays

Net delay is the RC delay of the routed interconnect. After placement and routing, the tool extracts:

```
Net_delay = R_driver × C_wire + Σ(R_segment × C_downstream)
```

In practice, the router provides a parasitic netlist (SPEF or similar) that the STA tool uses directly.

---

## 6. Operating Conditions and Derating

STA is performed at specific **process-voltage-temperature (PVT)** corners:

| Corner | Purpose |
|--------|---------|
| Slow (worst-case) | Setup analysis (longest delays) |
| Fast (best-case) | Hold analysis (shortest delays) |
| Typical | Functional characterization |

**On-chip variation (OCV)** applies additional derating to account for random variation within a single die:
- Launch path: derated **slower** (multiply delay by `1 + derate_factor`)
- Capture path: derated **faster** (multiply delay by `1 - derate_factor`)

Modern tools (Vivado, Quartus) support **POCV (Parametric OCV)** which applies statistical distributions rather than flat derating.

---

## 7. What STA Does NOT Check

| Limitation | Explanation |
|------------|-------------|
| Functional correctness | STA only checks timing, not logic function |
| Glitch energy | Dynamic power due to logic hazards is not reported |
| True/false paths | The tool checks all paths unless explicitly constrained as false |
| Reset/set recovery/removal | Covered separately by recovery/removal checks |

---

## 8. Summary

| Concept | Key Point |
|---------|-----------|
| Timing graph | DAG of cells and nets with delay-annotated edges |
| Arrival time | Worst-case signal arrival at a node (forward traversal) |
| Required time | Latest a signal may arrive without violation (backward traversal) |
| Slack | Required − Arrival; must be ≥ 0 for a passing design |
| OCV | Derating applied to model within-die process variation |

---

> **Next:** [02 — Key Timing Concepts](02-Key-Timing-Concepts.md) — Slack metrics (WNS, TNS, WHS), clock period budgeting, and multi-cycle paths.
