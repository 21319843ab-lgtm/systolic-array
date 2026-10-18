# Parameterized Output-Stationary Systolic Array V1.5

Synthesizable SystemVerilog implementation of signed
`A[M×K] × B[K×N] + C[M×N]`. `M`, `N`, `K`, `DATA_W`, `ACC_W`, and the
overflow policy are compile-time parameters. Defaults are INT8/INT32 with
two's-complement wraparound.

## V1.5 additions

- Warning-clean Testbenches for Verilator 5.x. The intentional combination of
  asynchronous DUT reset and synchronous SVA sampling is suppressed only with
  the targeted `-Wno-SYNCASYNCNET` option.
- Eight executable SystemVerilog Assertions covering handshake, phase order,
  cycle progression, captured-input stability, and physical MAC bounds.
- Six SVA cover properties plus a portable named-bin functional coverage TB.
- Optional signed saturating accumulation controlled by `SATURATE`.
- Architecture-level resource/performance parameter sweep with CSV and SVG.

## Architecture and timing

- `M×N` output-stationary PEs; each PE owns one accumulator/output.
- The controller captures A, B and C when an idle `start` is accepted.
- One cycle loads C, followed by `K + M + N - 2` wavefront run cycles.
- `A[i,k]` enters row `i` at run cycle `k+i`; `B[k,j]` enters column `j`
  at `k+j`; their useful MAC occurs in PE `(i,j)` at `k+i+j`.
- `done` is one cycle. `start` while busy or during done is ignored.

The packed ports are row-major, least-significant element first. For example,
`A[i,k]` occupies `a_matrix_flat[(i*K+k)*DATA_W +: DATA_W]`.

## Overflow modes

| `SATURATE` | Accumulator behavior |
|---:|---|
| 0 | Normal fixed-width two's-complement wraparound |
| 1 | Clamp positive overflow to `2^(ACC_W-1)-1` and negative overflow to `-2^(ACC_W-1)` |

Saturation is applied after every MAC, matching the hardware PE behavior. Both
the Python golden model and directed overflow vectors implement the same rule.
`ACC_W` must be at least `2*DATA_W`.

## Ubuntu prerequisites

```bash
sudo apt update
sudo apt install -y verilator python3 make
```

Verilator 5.x is recommended. No third-party Python package is required.

## Full regression

```bash
cd systolic_array_v1_5
COUNT=100 SEED=42 MODEL_COUNT=10000 bash sim/run_all.sh
```

Eight directed vectors are added to `COUNT` random vectors. The full suite runs
10 wraparound configurations, four saturation configurations, the assertion
checker, both functional-coverage modes, cycle checks, the Python model stress
test, and a 36-configuration architectural sweep.

## Run one arbitrary configuration

Positional arguments are `M N K DATA_W ACC_W random_count seed SATURATE`:

```bash
# INT8/INT32 wraparound
bash sim/run_case.sh 3 5 7 8 32 1000 123 0

# INT8/INT16 saturation
bash sim/run_case.sh 4 4 8 8 16 1000 123 1

# Equivalent environment-variable form
M=6 N=10 K=9 DATA_W=8 ACC_W=32 SATURATE=1 COUNT=500 SEED=42 \
  bash sim/run_case.sh
```

Every run checks all result elements, the active-MAC schedule, total MAC count,
run-cycle count, and all enabled assertions.

## Assertions and functional coverage

`tb/systolic_array_sva.sv` checks:

1. `done` is exactly one cycle.
2. `done` and `busy` never overlap.
3. An accepted `start` enters the C-load phase.
4. C-load is followed by run.
5. The last run cycle is followed by `done`.
6. `run_cycle` increments exactly once per run cycle.
7. Captured A/B/C remain stable throughout a transaction.
8. `active_macs` never exceeds `M×N`.

`tb/functional_coverage_tb.sv` reports 14 portable named bins for accepted and
busy starts, done behavior, reset abort/restart, sign/extreme data, wavefront
fill/peak/drain, and both overflow policies. Run it independently with:

```bash
bash sim/run_coverage.sh
```

## Resource/performance sweep

```bash
python3 analysis/parameter_sweep.py \
  --m 2,4,8 --n 2,4,8 --k 2,4,8,16 \
  --data-w 8 --acc-w 32 \
  --output-prefix analysis/results/parameter_sweep
```

Outputs include a CSV with PEs, multiplier/accumulator counts, stored-bit
estimates, latency, useful MACs, peak activity, throughput and utilization,
plus resource and performance SVG charts. These are pre-synthesis architecture
estimates, not FPGA/ASIC synthesis data. Analytical average utilization is
`K / (K+M+N-2)`.

## Other utilities

```bash
bash sim/run_lint.sh
python3 analysis/schedule.py --m 4 --n 4 --k 4 \
  --output analysis/results/m4_n4_k4.csv
python3 analysis/plot_utilization.py --m 4 --n 4 --k 4 \
  --output analysis/results/m4_n4_k4.svg
python3 tools/model_regression.py --count 100000 --seed 42
```

## Source layout

- `rtl/os_pe.sv`: signed forwarding MAC PE with wrap/saturation selection.
- `rtl/os_systolic_array.sv`: generated `M×N` PE mesh.
- `rtl/os_controller.sv`: capture, C-load, skew scheduling and handshake FSM.
- `rtl/systolic_array_top.sv`: integrated top level.
- `tb/systolic_array_sva.sv`: reusable assertion and cover-property checker.
- `tb/functional_coverage_tb.sv`: portable functional coverage regression.
- `tb/`: PE, controller, matrix and cycle-accurate tests.
- `tools/`: vector generator and independent golden model.
- `analysis/`: schedule, chart and parameter-sweep tools.
- `sim/`: lint, single-case, coverage and full-regression launchers.

## Practical limits

The RTL has no fixed matrix-size ceiling; elaboration size, packed-port width
and simulator/synthesis resources provide practical limits. Hardware grows
mainly with `M*N`, while transaction capture storage grows with
`M*K + K*N + M*N`. The supplied text-vector TB supports the delivered widths
up to 32-bit accumulators; the synthesizable RTL itself is not restricted to
that TB limit.
