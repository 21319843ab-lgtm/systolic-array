#!/usr/bin/env python3
"""Create a dependency-free SVG utilization chart from schedule parameters."""

from __future__ import annotations

import argparse
from pathlib import Path
from schedule import profile


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--m", type=int, default=4)
    ap.add_argument("--n", type=int, default=4)
    ap.add_argument("--k", type=int, default=4)
    ap.add_argument("--output", type=Path, required=True)
    args = ap.parse_args()
    if min(args.m, args.n, args.k) < 1:
        ap.error("M, N and K must be positive")
    values = profile(args.m, args.n, args.k)
    capacity = args.m * args.n
    width, height = 900, 480
    left, right, top, bottom = 70, 30, 55, 70
    pw, ph = width-left-right, height-top-bottom
    bar_w = pw / len(values)
    bars = []
    for i, value in enumerate(values):
        h = ph * value / capacity
        x = left + i * bar_w + 1
        y = top + ph - h
        bars.append(f'<rect x="{x:.2f}" y="{y:.2f}" width="{max(1,bar_w-2):.2f}" '
                    f'height="{h:.2f}" fill="#2563eb"><title>cycle {i}: {value}/{capacity}</title></rect>')
    ticks = []
    for q in range(5):
        frac = q/4
        y = top + ph*(1-frac)
        ticks.append(f'<line x1="{left}" y1="{y:.2f}" x2="{width-right}" y2="{y:.2f}" stroke="#d1d5db"/>')
        ticks.append(f'<text x="{left-10}" y="{y+5:.2f}" text-anchor="end">{capacity*frac:.0f}</text>')
    util = 100 * sum(values) / (capacity * len(values))
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">
<rect width="100%" height="100%" fill="white"/>
<style>text{{font-family:Arial,sans-serif;fill:#1f2937;font-size:13px}} .title{{font-size:22px;font-weight:700}}</style>
<text class="title" x="{width/2}" y="30" text-anchor="middle">Output-Stationary Utilization: {args.m}×{args.n}, K={args.k}</text>
{''.join(ticks)}
<line x1="{left}" y1="{top+ph}" x2="{width-right}" y2="{top+ph}" stroke="#111827"/>
<line x1="{left}" y1="{top}" x2="{left}" y2="{top+ph}" stroke="#111827"/>
{''.join(bars)}
<text x="{width/2}" y="{height-30}" text-anchor="middle">Run cycle (0…{len(values)-1})</text>
<text x="18" y="{height/2}" text-anchor="middle" transform="rotate(-90 18 {height/2})">Active MACs</text>
<text x="{width-right}" y="{height-10}" text-anchor="end">Average utilization: {util:.2f}% · useful MACs: {sum(values)}</text>
</svg>'''
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(svg, encoding="utf-8")
    print(f"saved: {args.output}")


if __name__ == "__main__":
    main()
