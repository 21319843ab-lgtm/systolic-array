#!/usr/bin/env python3
"""Architecture-level resource/performance sweep (not synthesis results)."""

from __future__ import annotations

import argparse
import csv
import itertools
import math
from pathlib import Path


def parse_list(text: str) -> list[int]:
    values = [int(item.strip()) for item in text.split(",") if item.strip()]
    if not values or min(values) < 1:
        raise argparse.ArgumentTypeError("expected comma-separated positive integers")
    return values


def metrics(m: int, n: int, k: int, data_w: int, acc_w: int) -> dict[str, float | int | str]:
    pes = m * n
    run_cycles = k + m + n - 2
    macs = m * n * k
    peak = sum(1 for i in range(m) for j in range(n) if 0 <= (run_cycles//2)-i-j < k)
    capture_bits = (m*k + k*n) * data_w + m*n*acc_w
    pe_forward_bits = pes * (2*data_w + 2)  # A/B plus two valid bits
    accumulator_bits = pes * acc_w
    control_bits = max(1, math.ceil(math.log2(run_cycles))) + 2
    register_proxy = capture_bits + pe_forward_bits + accumulator_bits + control_bits
    return {
        "configuration": f"{m}x{n}x{k}", "M": m, "N": n, "K": k,
        "DATA_W": data_w, "ACC_W": acc_w, "PEs": pes,
        "multipliers": pes, "accumulators": pes,
        "capture_bits": capture_bits, "pe_forward_bits": pe_forward_bits,
        "accumulator_bits": accumulator_bits, "control_bits": control_bits,
        "register_bit_proxy": register_proxy, "run_cycles": run_cycles,
        "start_to_done_cycles": run_cycles + 1, "useful_macs": macs,
        "peak_active_macs": peak, "macs_per_run_cycle": macs/run_cycles,
        "utilization_percent": 100.0*k/run_cycles,
    }


def svg_bars(rows: list[dict[str, float | int | str]], key: str, title: str,
             ylabel: str, path: Path) -> None:
    width = max(960, 58*len(rows)+100)
    height, left, right, top, bottom = 520, 80, 30, 60, 130
    pw, ph = width-left-right, height-top-bottom
    vals = [float(row[key]) for row in rows]
    vmax = max(vals) if vals else 1.0
    bar_w = pw/len(rows)
    bars, labels = [], []
    for idx, (row, value) in enumerate(zip(rows, vals)):
        h = ph*value/vmax if vmax else 0
        x, y = left+idx*bar_w+2, top+ph-h
        bars.append(f'<rect x="{x:.2f}" y="{y:.2f}" width="{max(1,bar_w-4):.2f}" height="{h:.2f}" fill="#2563eb"><title>{row["configuration"]}: {value:.2f}</title></rect>')
        labels.append(f'<text x="{x+bar_w/2:.2f}" y="{top+ph+12}" transform="rotate(60 {x+bar_w/2:.2f} {top+ph+12})" text-anchor="start">{row["configuration"]}</text>')
    grid = []
    for q in range(5):
        value = vmax*q/4
        y = top+ph*(1-q/4)
        grid.append(f'<line x1="{left}" y1="{y:.2f}" x2="{width-right}" y2="{y:.2f}" stroke="#d1d5db"/>')
        grid.append(f'<text x="{left-8}" y="{y+5:.2f}" text-anchor="end">{value:.1f}</text>')
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">
<rect width="100%" height="100%" fill="white"/><style>text{{font-family:Arial,sans-serif;fill:#1f2937;font-size:12px}}.title{{font-size:21px;font-weight:700}}</style>
<text class="title" x="{width/2}" y="30" text-anchor="middle">{title}</text>{''.join(grid)}
<line x1="{left}" y1="{top+ph}" x2="{width-right}" y2="{top+ph}" stroke="#111827"/>
{''.join(bars)}{''.join(labels)}
<text x="20" y="{height/2}" text-anchor="middle" transform="rotate(-90 20 {height/2})">{ylabel}</text>
</svg>'''
    path.write_text(svg, encoding="utf-8")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--m", type=parse_list, default=parse_list("2,4,8"))
    ap.add_argument("--n", type=parse_list, default=parse_list("2,4,8"))
    ap.add_argument("--k", type=parse_list, default=parse_list("2,4,8,16"))
    ap.add_argument("--data-w", type=int, default=8)
    ap.add_argument("--acc-w", type=int, default=32)
    ap.add_argument("--output-prefix", type=Path,
                    default=Path("analysis/results/parameter_sweep"))
    args = ap.parse_args()
    if args.data_w < 1 or args.acc_w < 2*args.data_w:
        ap.error("require DATA_W >= 1 and ACC_W >= 2*DATA_W")
    rows = [metrics(m, n, k, args.data_w, args.acc_w)
            for m, n, k in itertools.product(args.m, args.n, args.k)]
    prefix = args.output_prefix
    prefix.parent.mkdir(parents=True, exist_ok=True)
    csv_path = prefix.with_suffix(".csv")
    with csv_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)
    resource_svg = prefix.with_name(prefix.name+"_resources.svg")
    performance_svg = prefix.with_name(prefix.name+"_performance.svg")
    svg_bars(rows, "register_bit_proxy", "Architectural Register-Bit Proxy",
             "Estimated stored bits", resource_svg)
    svg_bars(rows, "utilization_percent", "Output-Stationary Average Utilization",
             "Utilization (%)", performance_svg)
    print(f"[PASS] parameter sweep configurations={len(rows)}")
    print(f"CSV: {csv_path}")
    print(f"resource chart: {resource_svg}")
    print(f"performance chart: {performance_svg}")
    print("NOTE: resource counts are architecture estimates, not synthesis results.")


if __name__ == "__main__":
    main()
