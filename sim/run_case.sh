#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
M="${M:-${1:-4}}"
N="${N:-${2:-4}}"
K="${K:-${3:-4}}"
DATA_W="${DATA_W:-${4:-8}}"
ACC_W="${ACC_W:-${5:-32}}"
COUNT="${COUNT:-${6:-100}}"
SEED="${SEED:-${7:-1}}"
SATURATE="${SATURATE:-${8:-0}}"

if (( M < 1 || N < 1 || K < 1 || DATA_W < 1 || ACC_W < 2*DATA_W )); then
  echo "invalid parameters: require M,N,K,DATA_W >= 1 and ACC_W >= 2*DATA_W" >&2
  exit 2
fi
if [[ "$SATURATE" != "0" && "$SATURATE" != "1" ]]; then
  echo "invalid SATURATE=$SATURATE: expected 0 or 1" >&2
  exit 2
fi

BUILD="$ROOT/sim/build/m${M}_n${N}_k${K}_d${DATA_W}_a${ACC_W}_s${SATURATE}"
mkdir -p "$BUILD"
GEN_ARGS=(--m "$M" --n "$N" --k "$K" --data-w "$DATA_W" --acc-w "$ACC_W"
          --count "$COUNT" --seed "$SEED" --output "$BUILD/vectors.txt")
if [[ "$SATURATE" == "1" ]]; then GEN_ARGS+=(--saturate); fi
python3 "$ROOT/tools/gen_vectors.py" \
  "${GEN_ARGS[@]}"

RTL=("$ROOT/rtl/os_pe.sv" "$ROOT/rtl/os_systolic_array.sv" \
     "$ROOT/rtl/os_controller.sv" "$ROOT/rtl/systolic_array_top.sv")
PARAMS=(-GM="$M" -GN="$N" -GK="$K" -GDATA_W="$DATA_W" -GACC_W="$ACC_W"
        -GSATURATE="$SATURATE")
SVA="$ROOT/tb/systolic_array_sva.sv"

verilator --binary --timing --assert -Wall -Wno-fatal -Wno-SYNCASYNCNET --top-module matmul_tb \
  "${PARAMS[@]}" --Mdir "$BUILD/obj_matmul" -o Vmatmul \
  "${RTL[@]}" "$SVA" "$ROOT/tb/matmul_tb.sv"
"$BUILD/obj_matmul/Vmatmul" +VECTOR_FILE="$BUILD/vectors.txt"

verilator --binary --timing --assert -Wall -Wno-fatal -Wno-SYNCASYNCNET --top-module array_timing_tb \
  "${PARAMS[@]}" --Mdir "$BUILD/obj_timing" -o Vtiming \
  "${RTL[@]}" "$SVA" "$ROOT/tb/array_timing_tb.sv"
"$BUILD/obj_timing/Vtiming"

python3 "$ROOT/analysis/schedule.py" --m "$M" --n "$N" --k "$K" \
  --output "$ROOT/analysis/results/m${M}_n${N}_k${K}.csv"
python3 "$ROOT/analysis/plot_utilization.py" --m "$M" --n "$N" --k "$K" \
  --output "$ROOT/analysis/results/m${M}_n${N}_k${K}.svg"
