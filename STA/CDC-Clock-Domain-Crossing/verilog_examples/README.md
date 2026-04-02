# CDC Verilog Examples

> **Navigation:** [← Synchronization Techniques](../Synchronization-Techniques.md) | [CDC README](../README.md)

| File | Module | Description |
|------|--------|-------------|
| [cdc_single_bit.v](cdc_single_bit.v) | `cdc_sync_2ff` | Parameterizable 2-FF synchronizer |
| [cdc_handshake.v](cdc_handshake.v) | `cdc_handshake` | Toggle-based pulse + handshake synchronizer |
| [gray_code_sync.v](gray_code_sync.v) | `gray_code_sync` | Gray-coded counter with cross-domain sync |
| [async_fifo.v](async_fifo.v) | `async_fifo` | Complete async FIFO with empty/full flags |

## Synthesis Notes

All modules are synthesizable. Key attributes used:

| Attribute | Tool | Purpose |
|-----------|------|---------|
| `(* ASYNC_REG = "TRUE" *)` | Vivado | Co-place sync FFs, mark for CDC tool |
| `(* dont_touch = "true" *)` | Vivado | Prevent optimization of sync registers |
| `altera_attribute "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS"` | Quartus | Mark as synchronizer |

## Instantiation Example

```verilog
// Single-bit CDC
cdc_sync_2ff #(.STAGES(2)) u_sync (
    .clk_dst  (clk_100),
    .data_in  (fast_ctrl),
    .data_out (slow_ctrl)
);

// Async FIFO
async_fifo #(.DATA_WIDTH(8), .FIFO_DEPTH(16)) u_fifo (
    .wr_clk   (clk_200),
    .rd_clk   (clk_50),
    .wr_en    (write_enable),
    .rd_en    (read_enable),
    .wr_data  (write_data),
    .rd_data  (read_data),
    .full     (fifo_full),
    .empty    (fifo_empty)
);
```
