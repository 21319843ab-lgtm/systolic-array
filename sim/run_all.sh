#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COUNT="${COUNT:-100}"
SEED="${SEED:-42}"
RTL=("$ROOT/rtl/os_pe.sv" "$ROOT/rtl/os_systolic_array.sv" \
     "$ROOT/rtl/os_controller.sv" "$ROOT/rtl/systolic_array_top.sv")
BUILD="$ROOT/sim/build/unit"
SVA="$ROOT/tb/systolic_array_sva.sv"
mkdir -p "$BUILD"

verilator --binary --timing --assert -Wall -Wno-fatal -Wno-SYNCASYNCNET --top-module pe_tb \
  --Mdir "$BUILD/obj_pe" -o Vpe "${RTL[@]}" "$ROOT/tb/pe_tb.sv"
"$BUILD/obj_pe/Vpe"

verilator --binary --timing --assert -Wall -Wno-fatal -Wno-SYNCASYNCNET --top-module controller_regression_tb \
  --Mdir "$BUILD/obj_controller" -o Vcontroller "${RTL[@]}" \
  "$SVA" "$ROOT/tb/controller_regression_tb.sv"
"$BUILD/obj_controller/Vcontroller"

for sat in 0 1; do
  verilator --binary --timing --assert -Wall -Wno-fatal -Wno-SYNCASYNCNET \
    --top-module functional_coverage_tb -GSATURATE="$sat" \
    --Mdir "$BUILD/obj_coverage_s${sat}" -o Vcoverage \
    "${RTL[@]}" "$SVA" "$ROOT/tb/functional_coverage_tb.sv"
  "$BUILD/obj_coverage_s${sat}/Vcoverage"
done

# Shape coverage: scalar, row/column, rectangular, square, and wider K.
CASES=(
  "1 1 1 8 32"
  "1 5 3 8 32"
  "4 1 5 8 32"
  "2 3 4 8 32"
  "3 5 2 8 32"
  "4 4 4 8 32"
  "5 3 7 8 32"
  "8 8 8 8 32"
  "3 4 5 4 16"
  "2 2 3 12 32"
)

case_seed="$SEED"
for cfg in "${CASES[@]}"; do
  read -r m n k dw aw <<<"$cfg"
  M="$m" N="$n" K="$k" DATA_W="$dw" ACC_W="$aw" \
    COUNT="$COUNT" SEED="$case_seed" bash "$ROOT/sim/run_case.sh"
  case_seed=$((case_seed + 1))
done

# Saturation mode is additionally exercised across boundary and rectangular shapes.
SAT_CASES=(
  "1 1 1 8 16"
  "2 3 4 8 16"
  "4 4 4 8 16"
  "3 4 5 4 16"
)
for cfg in "${SAT_CASES[@]}"; do
  read -r m n k dw aw <<<"$cfg"
  M="$m" N="$n" K="$k" DATA_W="$dw" ACC_W="$aw" SATURATE=1 \
    COUNT="$COUNT" SEED="$case_seed" bash "$ROOT/sim/run_case.sh"
  case_seed=$((case_seed + 1))
done

python3 "$ROOT/tools/model_regression.py" --count "${MODEL_COUNT:-10000}" --seed "$SEED"
python3 "$ROOT/analysis/parameter_sweep.py" \
  --output-prefix "$ROOT/analysis/results/parameter_sweep"
echo "ALL V1.5 TESTS PASSED"
