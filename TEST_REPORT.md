# V1.5 Verification Report

Verification date: 2026-10-18  
Simulator: Verilator 5.020 on Ubuntu/WSL2  
Result: **ALL V1.5 TESTS PASSED**

## Summary

- Synthesizable RTL lint: passed.
- Testbenches: no `PROCASSINIT`, `UNUSEDSIGNAL`, `WIDTHEXPAND`, or
  `WIDTHTRUNC` warnings in strict checks.
- SVA: eight assertions enabled; no assertion failures.
- SVA cover directives: six protocol/phase cover properties.
- Functional coverage: 14/14 named bins (100%) in wrap mode and 14/14 (100%)
  in saturation mode.
- HDL regression: 14 configurations × 108 vectors = 1,512 transactions.
- Cycle-accurate schedule validation: passed for all 14 configurations.
- Python stress: 50,000 cases checked in both modes (100,000 mode evaluations).
- Parameter sweep: 36 configurations; CSV and two SVG charts generated.

## HDL configurations

| Mode | M | N | K | DATA_W | ACC_W | Vectors | Result |
|---|---:|---:|---:|---:|---:|---:|---|
| Wrap | 1 | 1 | 1 | 8 | 32 | 108 | PASS |
| Wrap | 1 | 5 | 3 | 8 | 32 | 108 | PASS |
| Wrap | 4 | 1 | 5 | 8 | 32 | 108 | PASS |
| Wrap | 2 | 3 | 4 | 8 | 32 | 108 | PASS |
| Wrap | 3 | 5 | 2 | 8 | 32 | 108 | PASS |
| Wrap | 4 | 4 | 4 | 8 | 32 | 108 | PASS |
| Wrap | 5 | 3 | 7 | 8 | 32 | 108 | PASS |
| Wrap | 8 | 8 | 8 | 8 | 32 | 108 | PASS |
| Wrap | 3 | 4 | 5 | 4 | 16 | 108 | PASS |
| Wrap | 2 | 2 | 3 | 12 | 32 | 108 | PASS |
| Saturate | 1 | 1 | 1 | 8 | 16 | 108 | PASS |
| Saturate | 2 | 3 | 4 | 8 | 16 | 108 | PASS |
| Saturate | 4 | 4 | 4 | 8 | 16 | 108 | PASS |
| Saturate | 3 | 4 | 5 | 4 | 16 | 108 | PASS |

Each set contains eight directed cases, including positive and negative
overflow, plus 100 deterministic random cases.

## Warning-clean note

The DUT uses asynchronous reset while SVA samples reset at the assertion clock.
Verilator labels this intentional combination `SYNCASYNCNET`; scripts suppress
only that diagnostic with `-Wno-SYNCASYNCNET`. All width, initialization and
unused-signal warnings observed in V1.4 were corrected in source.

GNU Make may print `Clock skew detected` on a Windows-mounted WSL filesystem
whose timestamps differ slightly. This is not an RTL/Testbench warning and did
not affect the completed builds.
