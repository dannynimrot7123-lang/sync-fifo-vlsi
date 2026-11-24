# Synchronous FIFO — CLA-2 VLSI Design Project
**Course:** 21ECC303TA – VLSI Design and Technology | **Problem 12:** Synchronous FIFO

Parameterized single-clock FIFO with `full`, `empty`, `almost_full`, `almost_empty` flags,
plus overflow/underflow pulses and a live occupancy `count`.

## Files
| Path | Purpose |
|------|---------|
| `rtl/sync_fifo.v` | Synthesizable RTL (DATA_WIDTH, DEPTH, AF_MARGIN, AE_MARGIN) |
| `tb/sync_fifo_tb.v` | Self-checking testbench with reference model (10 tests, 2100+ checks) |
| `synth/yosys_report.txt` | Generic synthesis stats (DEPTH=16, WIDTH=8) |
| `sim_out/sim_log.txt`, `sim_out/sync_fifo.vcd` | Simulation log and waveform (open with GTKWave) |
| `index.html` | Browser demo: open directly, or host with GitHub Pages |

## Flags
- `empty`: count == 0 | `full`: count == DEPTH
- `almost_empty`: count <= AE_MARGIN | `almost_full`: count >= DEPTH - AF_MARGIN
- Write when full / read when empty is ignored and raises a 1-cycle `overflow` / `underflow`.
- Simultaneous read+write keeps count unchanged. `rd_data` is registered (valid one cycle after `rd_en`).

## Run
```bash
iverilog -g2012 -o fifo_sim rtl/sync_fifo.v tb/sync_fifo_tb.v
vvp fifo_sim
gtkwave sync_fifo.vcd
yosys -p "read_verilog rtl/sync_fifo.v; synth -top sync_fifo; stat"
```

## Results
Simulation: ALL TESTS PASSED. Synthesis (Yosys generic, DEPTH=16, WIDTH=8): 381 cells, 151 flip-flops.
