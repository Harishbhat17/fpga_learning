# Glossary of STA Terms

> **Navigation:** [← STA Index](../README.md)

---

| Term | Definition |
|------|-----------|
| **ASYNC_REG** | Vivado attribute that marks flip-flops as synchronizers, preventing optimization and co-locating them |
| **Arrival Time (AT)** | The time at which a signal arrives at a node, computed by forward traversal of the timing graph |
| **Asynchronous Reset** | A reset signal that immediately forces FF output regardless of the clock edge |
| **BUFG / BUFGCE** | Xilinx global clock buffer / clock buffer with clock enable — provides balanced, low-skew clock distribution |
| **BUFR / BUFIO** | Xilinx regional/I/O clock buffers — for high-speed I/O, not for global distribution |
| **CARRY8** | Xilinx UltraScale+ fast carry chain primitive — 8-bit lookahead carry |
| **CDC (Clock Domain Crossing)** | A signal path from logic clocked by one clock to logic clocked by a different clock |
| **CTS (Clock Tree Synthesis)** | The process of distributing clock signals with balanced delays to all FFs (automated in FPGAs) |
| **DRC (Design Rule Check)** | Tool-generated checks for constraint correctness, I/O standards, and design configuration |
| **DSP Block** | Dedicated arithmetic block (DSP48E2 in Xilinx, DSP18 in Intel) for high-speed multiply-accumulate |
| **FDRE** | Xilinx flip-flop primitive: D flip-flop with synchronous reset, synchronous enable |
| **False Path** | A timing path that exists in the netlist but is not functionally realizable — excluded from STA |
| **Fmax** | Maximum operating frequency: `f = 1 / (T - WNS)` where WNS < 0 |
| **Gray Code** | A binary encoding where consecutive values differ by exactly one bit — used for safe CDC counter crossing |
| **Hold Slack** | `Data_arrival - (Clock_capture + t_hold)` — must be ≥ 0 |
| **Hold Time (t_hold)** | Minimum time data must remain stable after the active clock edge |
| **IDELAY / IDELAYE3** | Xilinx programmable I/O delay element — 2.5 ps per tap in UltraScale+ |
| **IDDR / ISERDESE3** | Xilinx input double-data-rate register / serializer-deserializer for high-speed I/O |
| **I/O Timing** | Timing between external signals and FPGA I/O pads, constrained with `set_input_delay` / `set_output_delay` |
| **jitter** | Random, cycle-to-cycle variation in the clock edge position |
| **LOC constraint** | Vivado constraint that specifies the exact physical location of a cell |
| **LogicLock** | Quartus placement region constraint (equivalent to Vivado Pblock) |
| **MMCM** | Mixed-Mode Clock Manager — Xilinx PLL-like resource for clock synthesis, phase adjustment |
| **MTBF** | Mean Time Between Failures — measure of synchronizer reliability against metastability |
| **Metastability** | A condition where a FF output is neither 0 nor 1 after a timing violation, lasting for a random duration |
| **MCP (Multi-Cycle Path)** | A path where the data is allowed more than one clock cycle to propagate |
| **MUX** | Multiplexer — logic selecting between multiple data inputs |
| **Net Delay** | RC propagation delay of a routed wire, extracted from placement/routing database |
| **OCV (On-Chip Variation)** | Random variations in transistor parameters within a single die |
| **Path Group** | A set of timing paths sharing the same capture clock — timing is reported per group |
| **Pblock** | Vivado placement block — constrains cells to a specified device region |
| **PCB trace delay** | Propagation delay of a signal along a printed circuit board trace (~6–8 ps/mm) |
| **Period** | Duration of one clock cycle: `T = 1/f` |
| **Physical Optimization** | Post-placement/routing optimization that re-places or re-routes cells to improve timing |
| **PLL** | Phase-Locked Loop — generates output clocks at multiples/fractions of an input frequency |
| **POCV** | Parametric OCV — statistical OCV model using Gaussian distributions (more accurate than flat OCV) |
| **PVT** | Process-Voltage-Temperature — the operating conditions that affect timing |
| **Recovery Time** | Minimum time an async reset must be deasserted before the next active clock edge |
| **Removal Time** | Minimum time an async reset must remain asserted after the active clock edge |
| **Required Arrival Time (RAT)** | The latest time a signal may arrive at a node without violating timing — computed by backward traversal |
| **Retiming** | Moving flip-flops across combinational logic boundaries to balance pipeline stage delays |
| **SDC** | Synopsys Design Constraints — industry-standard timing constraint format used by Quartus |
| **Setup Slack** | `Required_time - Arrival_time` — must be ≥ 0 |
| **Setup Time (t_setup)** | Minimum time data must be stable before the active clock edge |
| **Skew** | Spatial variation in clock arrival time between source and destination registers |
| **SLR** | Super Logic Region — one silicon die in a Xilinx SSI (multi-die) device |
| **STA** | Static Timing Analysis — exhaustive, simulation-free timing verification |
| **TNS** | Total Negative Slack — sum of all negative slack values across all endpoints |
| **TPWS** | Total Pulse Width Slack — aggregate slack for pulse width checks |
| **t_clk2q** | Clock-to-Q propagation delay — time from active clock edge to stable output |
| **Uncertainty** | Clock uncertainty added to account for jitter, noise, and tool pessimism |
| **Virtual Clock** | A timing clock defined without a physical source — used to constrain I/O to external clock domains |
| **WHS** | Worst Hold Slack — most negative hold slack in the design |
| **WNS** | Worst Negative Slack — most negative setup slack; determines Fmax |
| **WPWS** | Worst Pulse Width Slack |
| **XDC** | Xilinx Design Constraints — Vivado constraint format, superset of SDC |

---

> **See also:** [References](References.md) | [Tool Comparison](Tool-Comparison.md)
