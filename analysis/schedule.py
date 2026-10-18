#!/usr/bin/env python3
"""Analyze the wavefront schedule of an MxN output-stationary array."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path


def profile(m: int, n: int, k: int) -> list[int]:
    cycles = k + m + n - 2
    return [sum(1 for i in range(m) for j in range(n) if 0 <= t - i - j < k)
            for t in range(cycles)]


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--m", type=int, default=4)
    ap.add_argument("--n", type=int, default=4)
    ap.add_argument("--k", type=int, default=4)
    ap.add_argument("--output", type=Path)
    args = ap.parse_args()
    if min(args.m, args.n, args.k) < 1:
        ap.error("M, N and K must be positive")
    active = profile(args.m, args.n, args.k)
    useful = args.m * args.n * args.k
    capacity = args.m * args.n * len(active)
    utilization = 100.0 * useful / capacity
    print(f"[PASS] schedule {args.m}x{args.n} K={args.k}: "
          f"MAC={useful} RUN={len(active)} utilization={utilization:.2f}%")
    print(f"active MAC/cycle: {active}")
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        with args.output.open("w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(["cycle", "active_macs", "array_capacity", "utilization_percent"])
            for cycle, macs in enumerate(active):
                writer.writerow([cycle, macs, args.m * args.n,
                                 f"{100.0 * macs / (args.m * args.n):.6f}"])
        print(f"report: {args.output}")


if __name__ == "__main__":
    main()
