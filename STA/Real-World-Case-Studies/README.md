# Real-World Case Studies

> **Navigation:** [← STA Index](../README.md)

These case studies follow complete, realistic timing closure scenarios from initial failing design through systematic diagnosis and closure. Each study uses realistic (but representative) timing numbers.

| # | Case Study | Design | Target | Key Challenge |
|---|-----------|--------|--------|---------------|
| 1 | [Image Processing Pipeline](Case-Study-1-Image-Processing-Pipeline.md) | RGB video sharpening | 150 MHz | Logic depth, carry chains |
| 2 | [DSP Chain](Case-Study-2-DSP-Chain.md) | 32-tap FIR filter | 250 MHz | DSP packing, pipelining |
| 3 | [Memory Controller](Case-Study-3-Memory-Controller.md) | DDR4 SDRAM interface | 533 MHz DDR | Source-synchronous I/O |
| 4 | [High-Speed I/O](Case-Study-4-High-Speed-IO.md) | 10G LVDS link | 625 MHz | IDELAY, skew |
| 5 | [Multi-Clock SoC](Case-Study-5-Multi-Clock-System.md) | 4-domain SoC | 200/300 MHz | CDC, inter-domain |

---

## Common Themes Across Case Studies

1. **Logic depth analysis** is always the first step
2. **RTL fixes** (pipelining, restructuring) always yield more benefit than constraints
3. **Placement constraints** (Pblocks) help routing-dominated violations
4. **CDC problems** require synchronizer insertion, not timing exceptions
5. **I/O timing** requires accurate PCB measurement data

---

> **Reading order:** Start with Case Study 1 (simplest) and work toward Case Study 5 (most complex).
