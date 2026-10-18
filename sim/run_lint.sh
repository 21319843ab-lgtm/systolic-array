#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
verilator --lint-only --timing -Wall -Wno-fatal \
  "$ROOT/rtl/os_pe.sv" "$ROOT/rtl/os_systolic_array.sv" \
  "$ROOT/rtl/os_controller.sv" "$ROOT/rtl/systolic_array_top.sv"
echo "[PASS] Verilator lint"
