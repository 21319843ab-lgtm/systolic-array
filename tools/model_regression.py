#!/usr/bin/env python3
"""High-volume independent schedule/reference regression (no HDL simulator needed)."""

from __future__ import annotations

import argparse
import random
from gen_vectors import matmul_os, quantize_acc


def scheduled(a: list[int], b: list[int], c: list[int], m: int, n: int,
              k: int, acc_w: int, saturate: bool = False) -> tuple[list[int], list[int]]:
    acc = c.copy()
    active = []
    for t in range(k + m + n - 2):
        count = 0
        for i in range(m):
            for j in range(n):
                inner = t - i - j
                if 0 <= inner < k:
                    idx = i * n + j
                    acc[idx] = quantize_acc(
                        acc[idx] + a[i*k+inner] * b[inner*n+j], acc_w, saturate)
                    count += 1
        active.append(count)
    return acc, active


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--count", type=int, default=10000)
    ap.add_argument("--seed", type=int, default=42)
    args = ap.parse_args()
    rng = random.Random(args.seed)
    shapes = [(1, 1, 1), (1, 7, 3), (6, 1, 5), (2, 3, 4),
              (3, 5, 2), (4, 4, 4), (5, 3, 7), (8, 8, 8)]
    widths = [(8, 16), (8, 32), (4, 16), (12, 32)]
    for case in range(args.count):
        m, n, k = shapes[case % len(shapes)]
        data_w, acc_w = widths[(case // len(shapes)) % len(widths)]
        lo, hi = -(1 << (data_w-1)), (1 << (data_w-1))-1
        clo, chi = -(1 << (acc_w-1)), (1 << (acc_w-1))-1
        a = [rng.randint(lo, hi) for _ in range(m*k)]
        b = [rng.randint(lo, hi) for _ in range(k*n)]
        c = [rng.randint(clo, chi) for _ in range(m*n)]
        for saturate in (False, True):
            got, active = scheduled(a, b, c, m, n, k, acc_w, saturate)
            expected = matmul_os(a, b, c, m, n, k, acc_w, saturate)
            assert got == expected, (case, m, n, k, data_w, acc_w, saturate)
            assert sum(active) == m*n*k
    print(f"[PASS] Python schedule/model regression modes=wrap+saturate "
          f"cases={args.count} seed={args.seed}")


if __name__ == "__main__":
    main()
