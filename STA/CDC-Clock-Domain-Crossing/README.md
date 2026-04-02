# CDC — Clock Domain Crossing

> **Navigation:** [← STA Index](../README.md)

Clock Domain Crossing (CDC) is one of the most common sources of intermittent design failures in FPGAs. A seemingly working design can fail unpredictably hours, days, or weeks after deployment if CDC is not handled correctly. This section provides the theory, Verilog implementations, and timing constraints needed to make CDC designs robust.

---

## Contents

| File | Description |
|------|-------------|
| [CDC Fundamentals](CDC-Fundamentals.md) | Metastability theory, MTBF, combinatorial CDC hazards |
| [Synchronization Techniques](Synchronization-Techniques.md) | 2-FF sync, handshake, async FIFO, Gray code |
| [Verilog Examples](verilog_examples/README.md) | Synthesizable CDC modules |
| [Timing Constraints](timing_constraints/cdc_constraints.xdc) | XDC for Vivado |
| [Timing Constraints (SDC)](timing_constraints/cdc_constraints.sdc) | SDC for Quartus |

---

## Quick Summary of CDC Structures

| Signal Type | Recommended Structure | Safety |
|-------------|----------------------|--------|
| Single-bit control | 2-FF synchronizer | ✅ Safe |
| Single-bit pulse (short) | Pulse stretcher + 2-FF | ✅ Safe |
| Multi-bit control bus | Handshake + 2-FF per bit | ✅ Safe |
| Multi-bit data | Async FIFO | ✅ Safe |
| Gray-coded counter | 2-FF per bit | ✅ Safe |
| Binary counter | **Unsafe — never** | ❌ Danger |
| Combinational output | **Unsafe** | ❌ Danger |

---

## Key Rules

1. **Never** pass raw binary counters or buses directly across clock domains
2. **Always** use the `ASYNC_REG` attribute (Vivado) or mark synchronizers in Quartus to prevent optimization
3. **Always** constrain synchronizer paths with `set_max_delay -datapath_only`
4. **Prefer** async FIFOs over handshake for high-throughput data

---

> **Start here:** [CDC Fundamentals](CDC-Fundamentals.md)
