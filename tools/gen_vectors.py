#!/usr/bin/env python3
"""Generate signed matrix vectors for wrapping or saturating accumulation."""

from __future__ import annotations

import argparse
import random
from pathlib import Path


def wrap_signed(value: int, width: int) -> int:
    mask = (1 << width) - 1
    value &= mask
    return value - (1 << width) if value & (1 << (width - 1)) else value


def quantize_acc(value: int, width: int, saturate: bool) -> int:
    if not saturate:
        return wrap_signed(value, width)
    lo = -(1 << (width - 1))
    hi = (1 << (width - 1)) - 1
    return min(hi, max(lo, value))


def matmul_os(a: list[int], b: list[int], c: list[int], m: int, n: int,
              k: int, acc_w: int, saturate: bool = False) -> list[int]:
    result = c.copy()
    for row in range(m):
        for col in range(n):
            idx = row * n + col
            acc = quantize_acc(result[idx], acc_w, saturate)
            for inner in range(k):
                acc = quantize_acc(
                    acc + a[row * k + inner] * b[inner * n + col],
                    acc_w, saturate)
            result[idx] = acc
    return result


def edge_values(width: int) -> list[int]:
    lo = -(1 << (width - 1))
    hi = (1 << (width - 1)) - 1
    return [lo, lo + 1, -1, 0, 1, hi - 1, hi]


def build_cases(m: int, n: int, k: int, data_w: int, acc_w: int,
                count: int, seed: int,
                saturate: bool = False) -> list[tuple[list[int], ...]]:
    rng = random.Random(seed)
    dlo, dhi = -(1 << (data_w - 1)), (1 << (data_w - 1)) - 1
    clo, chi = -(1 << (acc_w - 1)), (1 << (acc_w - 1)) - 1
    cases: list[tuple[list[int], ...]] = []

    directed = [
        ([0] * (m * k), [0] * (k * n), [0] * (m * n)),
        ([1] * (m * k), [1] * (k * n), [0] * (m * n)),
        ([-1] * (m * k), [1] * (k * n), [1] * (m * n)),
        ([dhi] * (m * k), [dhi] * (k * n), [0] * (m * n)),
        ([dlo] * (m * k), [dlo] * (k * n), [0] * (m * n)),
        ([1] * (m * k), [1] * (k * n), [chi] * (m * n)),
        ([-1] * (m * k), [1] * (k * n), [clo] * (m * n)),
        ([dlo if i % 2 else dhi for i in range(m * k)],
         [dhi if i % 2 else dlo for i in range(k * n)],
         [clo if i % 2 else chi for i in range(m * n)]),
    ]
    for a, b, c in directed:
        cases.append((a, b, c, matmul_os(a, b, c, m, n, k, acc_w, saturate)))

    edges = edge_values(data_w)
    for _ in range(count):
        a = [rng.choice(edges) if rng.random() < 0.2 else rng.randint(dlo, dhi) for _ in range(m * k)]
        b = [rng.choice(edges) if rng.random() < 0.2 else rng.randint(dlo, dhi) for _ in range(k * n)]
        # Keep most C values moderate, but inject full-width values to verify wrap behavior.
        c = [rng.randint(clo, chi) if rng.random() < 0.15 else rng.randint(-1024, 1024)
             for _ in range(m * n)]
        cases.append((a, b, c, matmul_os(a, b, c, m, n, k, acc_w, saturate)))
    return cases


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--m", type=int, required=True)
    ap.add_argument("--n", type=int, required=True)
    ap.add_argument("--k", type=int, required=True)
    ap.add_argument("--data-w", type=int, default=8)
    ap.add_argument("--acc-w", type=int, default=32)
    ap.add_argument("--count", type=int, default=100)
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--saturate", action="store_true",
                    help="use signed saturation instead of two's-complement wrap")
    ap.add_argument("--output", type=Path, required=True)
    args = ap.parse_args()
    if min(args.m, args.n, args.k, args.data_w) < 1:
        ap.error("M, N, K and DATA_W must be positive")
    if args.acc_w < 2 * args.data_w:
        ap.error("ACC_W must be at least 2*DATA_W")
    if args.count < 0:
        ap.error("count must be non-negative")

    cases = build_cases(args.m, args.n, args.k, args.data_w, args.acc_w,
                        args.count, args.seed, args.saturate)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="ascii") as f:
        f.write(f"{len(cases)}\n")
        for a, b, c, expected in cases:
            f.write(" ".join(map(str, a + b + c + expected)) + "\n")
    mode = "saturate" if args.saturate else "wrap"
    print(f"Generated {len(cases)} vectors ({mode}): {args.output}")


if __name__ == "__main__":
    main()
