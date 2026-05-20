 # RTL Design of K-Means Clustering Hardware Accelerator

> **Status: In Progress** — RTL architecture finalized; datapath modules under implementation.

A hardware accelerator for the K-Means clustering algorithm designed in Verilog, targeting both FPGA and ASIC implementation. The design replaces floating-point computation with fixed-point arithmetic to minimize area and power while preserving clustering accuracy.

---

## Motivation

K-Means is computationally intensive when run in software — especially for edge AI applications where energy budgets are tight. This project explores a dedicated RTL implementation that offloads the distance-computation and centroid-update loop to hardware, achieving faster throughput and lower energy per inference compared to a software-only approach.

---

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────┐
│                    K-Means Accelerator Top                   │
│                                                              │
│  ┌─────────────┐    ┌──────────────────┐    ┌─────────────┐ │
│  │ Data Input  │───▶│  Distance Unit   │───▶│  Min-Dist   │ │
│  │ Interface   │    │  (Fixed-Point    │    │  Comparator │ │
│  │             │    │   Euclidean)     │    │             │ │
│  └─────────────┘    └──────────────────┘    └──────┬──────┘ │
│                                                     │        │
│  ┌─────────────┐    ┌──────────────────┐           │        │
│  │  Centroid   │◀───│  Centroid Update │◀──────────┘        │
│  │  Registers  │    │  Accumulator     │                    │
│  └─────────────┘    └──────────────────┘                    │
│                                                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │           5-State Control FSM                           │ │
│  │  IDLE → LOAD → ASSIGN → UPDATE → CHECK_CONV            │ │
│  └─────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

---

## Design Parameters

| Parameter | Value |
|-----------|-------|
| Data width | 16-bit fixed-point (Q8.8) |
| Number of clusters (K) | Configurable (default: 4) |
| Feature dimensions | 2D (extendable) |
| Distance metric | Euclidean (squared, avoids sqrt) |
| Target platform | FPGA (Xilinx) / ASIC (Sky130) |
| Design entry | Verilog HDL |

---

## FSM — Control Flow

```
         ┌────────┐
    ──▶  │  IDLE  │ ◀─── reset
         └───┬────┘
             │ start
         ┌───▼────┐
         │  LOAD  │  ← Load data points and initial centroids
         └───┬────┘
             │ load_done
         ┌───▼──────┐
    ┌───▶ │  ASSIGN  │  ← Compute distances, assign each point to nearest centroid
    │    └───┬──────┘
    │        │ assign_done
    │    ┌───▼──────┐
    │    │  UPDATE  │  ← Recompute centroids from cluster sums
    │    └───┬──────┘
    │        │ update_done
    │    ┌───▼────────┐
    │    │ CHECK_CONV │  ← Compare old vs new centroids
    │    └─┬────────┬─┘
    │      │ no     │ yes
    └──────┘        └──▶ done
```

---

## Module Hierarchy

```
kmeans_top.v
├── data_loader.v          # Streams data points into on-chip registers
├── distance_unit.v        # Fixed-point squared Euclidean distance
│   └── fixed_mult.v       # Parameterized fixed-point multiplier
├── min_comparator.v       # Finds nearest centroid (argmin)
├── centroid_accumulator.v # Accumulates sum and count per cluster
├── centroid_updater.v     # Divides accumulated sums → new centroids
├── convergence_check.v    # Detects when centroids stop moving
└── fsm_controller.v       # 5-state FSM coordinating all units
```

---

## Fixed-Point Strategy

Instead of IEEE 754 floating-point (resource-expensive on FPGA), this design uses **Q8.8 fixed-point** format:
- 8 integer bits + 8 fractional bits → 16-bit total word width
- Squared Euclidean distance avoids the need for a hardware square-root unit
- Expected benefit: **~30% reduction** in LUT utilization vs floating-point equivalent

---

## Implementation Plan

- [x] Architecture definition and FSM design
- [x] Fixed-point arithmetic strategy finalized
- [ ] `fixed_mult.v` — parameterized fixed-point multiplier
- [ ] `distance_unit.v` — Euclidean distance compute unit
- [ ] `min_comparator.v` — argmin across K centroids
- [ ] `centroid_accumulator.v` — cluster sum accumulator
- [ ] `fsm_controller.v` — top-level control FSM
- [ ] `kmeans_top.v` — top-level integration
- [ ] Self-checking testbench with known-cluster datasets
- [ ] Waveform verification in GTKWave
- [ ] FPGA synthesis report (Xilinx Vivado)
- [ ] OpenLane ASIC flow (targeting Sky130)

---

## Tools

| Purpose | Tool |
|---------|------|
| RTL Simulation | Icarus Verilog (`iverilog`) |
| Waveform Analysis | GTKWave |
| FPGA Synthesis | Xilinx Vivado (planned) |
| ASIC Flow | OpenLane + Sky130 PDK (planned) |

---

## Directory Structure

```
├── rtl/
│   ├── kmeans_top.v
│   ├── fsm_controller.v
│   ├── distance_unit.v
│   ├── fixed_mult.v
│   ├── min_comparator.v
│   ├── centroid_accumulator.v
│   └── centroid_updater.v
├── tb/
│   └── tb_kmeans_top.v
├── sim/
│   └── waveforms/
├── docs/
│   └── architecture_notes.md
└── README.md
```

---

## Related Work

This accelerator connects to two prior projects:

**Research:** Co-authored a paper analyzing energy-accuracy trade-offs for MobileNet-V2 inference on Jetson-class edge hardware across FP32, FP16, and INT8 precision modes — establishing the motivation for hardware-level efficiency solutions like this accelerator. Published in the IEEE SB JIIT Research Forum Proceedings, 2026. → [Repository](https://github.com/SIDDYISBACK/IEEE-SB-JIIT-Research-Forum-2026)

**Implementation:** The ASIC backend methodology builds on a completed RTL-to-GDSII implementation of an 8-bit ALU using OpenLane and Sky130 PDK — 115 standard cells, 998 µm², 60.8 µW, zero DRC/LVS violations. → [Repository](https://github.com/quarky-1/RTL-to-GDS-ALU)

---

## Author

**Sarthak Tripathi**  
B.Tech — Electronics Engineering (VLSI Design & Technology)  
Jaypee Institute of Information Technology, Noida  
contact.sarthaktripathi@gmail.com  
[GitHub](https://github.com/quarky-1) | [LinkedIn](https://www.linkedin.com/in/sarthak-tripathi-0b925b1b7/)
