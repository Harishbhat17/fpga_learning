# Static Timing Analysis (STA) — Master Index

Static Timing Analysis (STA) is the cornerstone of digital FPGA design closure. It mathematically verifies that every signal path in your design meets its timing requirements without running a single simulation vector. This repository contains comprehensive, tool-specific documentation, worked examples, synthesizable Verilog, ready-to-run scripts, and real-world case studies for both Xilinx Vivado and Intel/Altera Quartus Prime flows.

---

## 📚 Repository Structure

```
STA/
├── learning/               # Core STA theory and concepts
├── Vivado/                 # Xilinx Vivado-specific workflows
├── Quartus/                # Intel Quartus Prime-specific workflows
├── CDC-Clock-Domain-Crossing/  # CDC fundamentals, Verilog, constraints
├── Advanced-Topics/        # Retiming, pipelining, multi-corner analysis
├── Real-World-Case-Studies/# End-to-end design closure walkthroughs
├── Best-Practices/         # Constraint writing, checklists, methodology
└── Resources/              # Glossary, references, tool comparison
```

---

## 1 · Learning — STA Fundamentals

| # | Document | Description |
|---|----------|-------------|
| 1 | [STA Fundamentals](learning/01-STA-Fundamentals.md) | What STA is, why it matters, and how the timing graph is built |
| 2 | [Key Timing Concepts](learning/02-Key-Timing-Concepts.md) | Slack, TNS, WNS, clock period, propagation delay |
| 3 | [Setup & Hold Analysis](learning/03-Setup-Hold-Analysis.md) | Deriving setup/hold equations, metastability, margins |
| 4 | [Clock Skew Management](learning/04-Clock-Skew-Management.md) | Skew, jitter, uncertainty, clock tree synthesis |

---

## 2 · Vivado (Xilinx)

| Document | Description |
|----------|-------------|
| [Vivado README](Vivado/README.md) | Section overview and quick-start |
| [01 — Project Setup](Vivado/01-Project-Setup.md) | Creating projects, synthesis/implementation settings |
| [02 — XDC Constraints](Vivado/02-XDC-Constraints.md) | Writing and applying XDC files in Vivado |
| [03 — Timing Reports](Vivado/03-Timing-Reports.md) | Reading and interpreting `report_timing_summary` |
| [04 — Debugging](Vivado/04-Debugging.md) | Fixing negative slack, false paths, multi-cycle paths |
| [Scripts](Vivado/scripts/README.md) | TCL automation scripts |
| [Examples](Vivado/examples/README.md) | XDC constraint examples |
| [Case Studies](Vivado/case_studies/Case-Study-1-Image-Processing.md) | Image processing pipeline closure |

---

## 3 · Quartus Prime (Intel)

| Document | Description |
|----------|-------------|
| [Quartus README](Quartus/README.md) | Section overview and quick-start |
| [01 — Project Setup](Quartus/01-Project-Setup.md) | Creating projects, fitter settings |
| [02 — SDC Constraints](Quartus/02-SDC-Constraints.md) | Writing and applying SDC files |
| [03 — TimeQuest Analyzer](Quartus/03-TimeQuest-Analyzer.md) | Using the TimeQuest GUI and TCL console |
| [04 — Timing Reports](Quartus/04-Timing-Reports.md) | Interpreting Fmax, slack, and path reports |
| [Scripts](Quartus/scripts/README.md) | TCL automation scripts |
| [Examples](Quartus/examples/README.md) | SDC constraint examples |
| [Case Studies](Quartus/case_studies/Case-Study-1-DSP-Design.md) | DSP chain timing closure |

---

## 4 · CDC — Clock Domain Crossing

| Document | Description |
|----------|-------------|
| [CDC README](CDC-Clock-Domain-Crossing/README.md) | Overview and navigation |
| [CDC Fundamentals](CDC-Clock-Domain-Crossing/CDC-Fundamentals.md) | Metastability theory, MTBF calculations |
| [Synchronization Techniques](CDC-Clock-Domain-Crossing/Synchronization-Techniques.md) | 2FF, handshake, async FIFO, Gray code |
| [Verilog Examples](CDC-Clock-Domain-Crossing/verilog_examples/README.md) | Synthesizable CDC modules |
| [Timing Constraints](CDC-Clock-Domain-Crossing/timing_constraints/cdc_constraints.xdc) | XDC/SDC for CDC paths |

---

## 5 · Advanced Topics

| Document | Description |
|----------|-------------|
| [Retiming & Optimization](Advanced-Topics/Retiming-Optimization.md) | Automated register retiming techniques |
| [Pipelining Strategies](Advanced-Topics/Pipelining-Strategies.md) | Manual and tool-assisted pipelining |
| [Register Balancing](Advanced-Topics/Register-Balancing.md) | Carry-chain balancing, DSP packing |
| [Physical Optimization](Advanced-Topics/Physical-Optimization.md) | Placement directives, Pblock constraints |
| [Multi-Corner Analysis](Advanced-Topics/Multi-Corner-Analysis.md) | Slow/fast corners, OCV, POCV |

---

## 6 · Real-World Case Studies

| # | Document | Design |
|---|----------|--------|
| 1 | [Image Processing Pipeline](Real-World-Case-Studies/Case-Study-1-Image-Processing-Pipeline.md) | Video pipeline at 150 MHz |
| 2 | [DSP Chain](Real-World-Case-Studies/Case-Study-2-DSP-Chain.md) | FIR filter chain at 200 MHz |
| 3 | [Memory Controller](Real-World-Case-Studies/Case-Study-3-Memory-Controller.md) | DDR3 interface constraints |
| 4 | [High-Speed I/O](Real-World-Case-Studies/Case-Study-4-High-Speed-IO.md) | LVDS/GTX link closure |
| 5 | [Multi-Clock System](Real-World-Case-Studies/Case-Study-5-Multi-Clock-System.md) | Four-domain SoC |

---

## 7 · Best Practices

| Document | Description |
|----------|-------------|
| [Constraint Writing](Best-Practices/Constraint-Writing.md) | Golden rules for SDC/XDC |
| [Design Methodology](Best-Practices/Design-Methodology.md) | Timing-driven design flow |
| [Optimization Checklist](Best-Practices/Optimization-Checklist.md) | Step-by-step closure checklist |
| [Common Mistakes](Best-Practices/Common-Mistakes.md) | Top-10 pitfalls and how to avoid them |

---

## 8 · Resources

| Document | Description |
|----------|-------------|
| [Glossary](Resources/Glossary.md) | All STA terms defined |
| [References](Resources/References.md) | Books, app notes, datasheets |
| [Checklists](Resources/Checklists.md) | Quick-reference pre-sign-off checklists |
| [Tool Comparison](Resources/Tool-Comparison.md) | Vivado vs Quartus feature matrix |

---

## Quick-Start

New to STA? Follow this reading order:

1. [STA Fundamentals](learning/01-STA-Fundamentals.md)
2. [Key Timing Concepts](learning/02-Key-Timing-Concepts.md)
3. [Setup & Hold Analysis](learning/03-Setup-Hold-Analysis.md)
4. Choose your tool: [Vivado](Vivado/README.md) or [Quartus](Quartus/README.md)
5. Study a [Real-World Case Study](Real-World-Case-Studies/README.md)
6. Review the [Best Practices](Best-Practices/Constraint-Writing.md)

---

*All content is original educational material. Equations, timing reports, and code examples are illustrative and tool-version-accurate as of Vivado 2023.x and Quartus Prime 23.x.*