# Synchronization Techniques for CDC

> **Navigation:** [← CDC Fundamentals](CDC-Fundamentals.md) | [CDC README](README.md) | [Verilog Examples →](verilog_examples/README.md)

---

## 1. The 2-FF Synchronizer

The **two flip-flop synchronizer** is the fundamental building block for all single-bit CDC:

```
clk_src domain          │  clk_dst domain
                         │
     ┌──────────┐        │   ┌──────────┐    ┌──────────┐
D ───►  FF_src  ├────────────► FF_meta  ├────► FF_sync   ├──► Q
     └────┬─────┘        │   └────┬─────┘    └────┬─────┘
          │ clk_src       │        │ clk_dst        │ clk_dst
                         │  (metastable here)  (resolved here)
```

**FF_meta** may go metastable when it samples data that changed close to its clock edge. With a full `clk_dst` period available for resolution, **FF_sync** samples a stable value.

### Timing Constraints Required

```tcl
# Vivado XDC:
set_max_delay -datapath_only \
    -from [get_cells FF_src] \
    -to   [get_cells FF_meta] \
    [expr {0.9 * [get_property PERIOD [get_clocks clk_dst]]}]

# Also mark as ASYNC_REG to prevent optimization and co-placement:
set_property ASYNC_REG TRUE [get_cells {FF_meta FF_sync}]
```

### Verilog Implementation

See [cdc_single_bit.v](verilog_examples/cdc_single_bit.v)

---

## 2. Pulse Synchronizer

A single-cycle pulse in `clk_src` may be too short to be reliably captured in `clk_dst` (if `clk_dst` is slower or has a different phase). The solution is to stretch the pulse using a **toggle-based synchronizer**:

```
clk_src:    ─┬──┬──┬──┬──
              │
pulse_in:    ─┘ (1 cycle)

toggle_ff:   toggles → stays at new level → 2-FF sync → edge-detect in dst → pulse_out
```

**How it works:**
1. A pulse in `clk_src` toggles a flip-flop (`toggle_ff`)
2. The toggled level is synchronized to `clk_dst` via a 2-FF synchronizer
3. An edge detector in `clk_dst` converts the level transition back to a pulse

This guarantees the pulse is captured regardless of the frequency relationship.

See [cdc_handshake.v](verilog_examples/cdc_handshake.v) for a complete implementation.

---

## 3. Handshake Synchronizer

For transferring a multi-bit data value (not just a control signal), a **four-phase handshake** ensures data integrity:

```
Phase 1: Source asserts REQ, presents DATA
Phase 2: Destination captures DATA when it sees synchronized REQ
Phase 3: Destination asserts ACK
Phase 4: Source deasserts REQ when it sees synchronized ACK; destination deasserts ACK
```

```
clk_src:   REQ ──────────────────────┐
              │                       │ (synchronized ACK detected)
clk_dst:       └──(sync)──── capture DATA, assert ACK ──(sync)──► source sees ACK
```

**Performance:** Each handshake takes approximately:
```
T_handshake ≈ 2 × T_src + 2 × T_dst + 4 × (2-FF sync latency)
            ≈ 2/f_src + 2/f_dst + 4 × 2/f_dst
```

For `f_src = f_dst = 100 MHz`: `T_handshake ≈ 10 + 10 + 40 = 60 ns` (1 transfer per 60 ns = 16.7 Mtransfers/s)

This is much slower than a FIFO for high-bandwidth applications but is very simple and uses few resources.

---

## 4. Gray-Code Counter Synchronization

For passing a counter value (e.g., an address pointer) across clock domains:

**Binary counter:** Changes multiple bits simultaneously → **unsafe**  
**Gray code counter:** Changes exactly 1 bit per count → can use 2-FF per bit

```
Binary  Gray
  0     000    → 000
  1     001    → 001
  2     010    → 011
  3     011    → 010
  4     100    → 110
  5     101    → 111
  6     110    → 101
  7     111    → 100
```

Each row differs from the next by exactly one bit.

### Binary-to-Gray Conversion

```verilog
assign gray = (binary >> 1) ^ binary;
```

### Gray-to-Binary Conversion

```verilog
always_comb begin
    binary[N-1] = gray[N-1];
    for (int i = N-2; i >= 0; i--)
        binary[i] = binary[i+1] ^ gray[i];
end
```

See [gray_code_sync.v](verilog_examples/gray_code_sync.v) and [async_fifo.v](verilog_examples/async_fifo.v).

---

## 5. Asynchronous FIFO

An **async FIFO** is the gold standard for multi-bit data transfer across asynchronous clock domains. It provides:
- Full bandwidth utilization (no handshake stalls)
- Flow control (full/empty flags)
- Reliable data transfer using Gray-coded pointers

### Architecture

```
clk_wr domain               FIFO Memory               clk_rd domain
                           (shared RAM/registers)
wr_ptr ──────────────────────────────────────────── wr_ptr_sync → compare → empty
rd_ptr_sync ──────── compare → full                  rd_ptr ──────────────────────

Write Logic:               ┌──────────┐               Read Logic:
  if (!full):              │  2D Reg  │               if (!empty):
    mem[wr_ptr] = din;     │  Array   │                 dout = mem[rd_ptr]
    wr_ptr++;              └──────────┘                 rd_ptr++
```

**Pointer crossing:** Both `wr_ptr` and `rd_ptr` are converted to Gray code before synchronization:

```verilog
// Convert write pointer to Gray, sync to read domain
assign wr_ptr_gray = (wr_ptr >> 1) ^ wr_ptr;
// ... 2-FF sync wr_ptr_gray to clk_rd ...

// Empty flag: all bits of Gray-coded pointers match
assign empty = (rd_ptr_gray == wr_ptr_gray_sync);
```

See [async_fifo.v](verilog_examples/async_fifo.v) for the complete synthesizable implementation.

---

## 6. Choosing the Right CDC Technique

| Use Case | Technique | Latency | Throughput |
|----------|-----------|---------|-----------|
| Single control bit | 2-FF synchronizer | 2 dst cycles | 1 bit per src cycle |
| Short pulse (1 src cycle) | Toggle sync | 4–6 dst cycles | 1 pulse per several cycles |
| Multi-bit config (written rarely) | Handshake | ~6 cycles each domain | Low |
| High-speed data stream | Async FIFO | 2 cycles read latency | Near-full bandwidth |
| Counter pointer | Gray-code + 2-FF | 2 dst cycles | 1 count per src cycle |

---

> **See also:** [Verilog Examples](verilog_examples/README.md) | [Timing Constraints](timing_constraints/cdc_constraints.xdc)
