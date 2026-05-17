# Architecture Notes — K-Means Hardware Accelerator

## Fixed-Point Representation

All data values use **Q8.8** signed fixed-point format (16-bit total):
- Bits [15:8] → integer part (signed, 2's complement)
- Bits [7:0]  → fractional part

| Real Value | Q8.8 Hex | Binary |
|-----------|----------|--------|
| 1.0       | 0x0100   | 0000_0001 . 0000_0000 |
| 1.5       | 0x0180   | 0000_0001 . 1000_0000 |
| -1.0      | 0xFF00   | 1111_1111 . 0000_0000 |
| 0.5       | 0x0080   | 0000_0000 . 1000_0000 |

### Multiplication (fixed_mult)
Full-precision product is `2*WIDTH = 32` bits. The correctly-scaled output is:
```
product[15:0] = full[23:8]   (bits WIDTH+FRAC_W-1 downto FRAC_W)
```

---

## Why Squared Euclidean Distance?

Standard Euclidean: `d = sqrt((px-cx)² + (py-cy)²)`

Hardware cost of a square-root unit is high (typically 10–20+ clock cycles for iterative methods, large LUT count). Since K-Means only needs to **compare** distances (find the minimum), and `sqrt` is monotonically increasing:

```
d₁ < d₂  ⟺  d₁² < d₂²
```

So we can skip the sqrt entirely — comparing squared distances is equivalent for argmin.

---

## FSM Timing Diagram (conceptual)

```
Clock:     __|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_
State:     IDLE  LOAD      ASSIGN     UPDATE CHECK
do_load:        ‾‾‾‾‾‾‾‾‾‾
do_assign:                  ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
do_update:                                   ‾‾‾
```

---

## Area/Power Target

| Metric | Target | Basis |
|--------|--------|-------|
| Technology | Sky130 (1.8V) | Same PDK as ALU project |
| Clock frequency | ≥ 10 MHz | Relaxed for area-first |
| LUT reduction vs FP | ~30% | Fixed-point vs IEEE 754 |
| Power mode | Low-power | Edge AI use case |

---

## Known Limitations / TODOs

1. **Centroid updater**: Division currently uses Verilog `/` operator (non-synthesizable for general denominators). Will be replaced with a sequential restoring divider.
2. **Data loading**: Points are loaded via a flat register bus. Plan to add an AXI-Stream interface for FPGA integration.
3. **Parallelism**: Distance units are currently fully unrolled across N points (area-expensive). A time-multiplexed design iterating over points sequentially would significantly reduce area at the cost of throughput.
4. **K generalization**: `convergence_check` uses hardcoded K=4 AND reduction. Need to generate this with a for loop or a reduction tree.
