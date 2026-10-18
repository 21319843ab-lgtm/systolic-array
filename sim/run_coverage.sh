#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="$ROOT/sim/build/coverage"
RTL=("$ROOT/rtl/os_pe.sv" "$ROOT/rtl/os_systolic_array.sv" \
     "$ROOT/rtl/os_controller.sv" "$ROOT/rtl/systolic_array_top.sv")
mkdir -p "$BUILD"
for sat in 0 1; do
  verilator --binary --timing --assert -Wall -Wno-fatal -Wno-SYNCASYNCNET \
    --top-module functional_coverage_tb -GSATURATE="$sat" \
    --Mdir "$BUILD/obj_s${sat}" -o Vcoverage \
    "${RTL[@]}" "$ROOT/tb/systolic_array_sva.sv" \
    "$ROOT/tb/functional_coverage_tb.sv"
  "$BUILD/obj_s${sat}/Vcoverage"
done
