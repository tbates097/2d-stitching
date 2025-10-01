#!/usr/bin/env python3
import sys
import os
import numpy as np
from typing import Tuple

# Reuse parser from compare_start2d by embedding a minimal version here

def parse_start2d(path: str) -> Tuple[np.ndarray, np.ndarray]:
    with open(path, 'r', encoding='utf-8', errors='replace') as f:
        lines = f.read().splitlines()
    if len(lines) < 4 or not lines[0].lstrip().startswith(':START2D'):
        raise ValueError(f"{path}: Missing START2D header")
    # num_cols at end of line 1
    toks = lines[0].split()
    num_cols = int(toks[-1])
    # find blank line after header line 2
    data_start = None
    for i in range(2, min(10, len(lines))):
        if lines[i].strip() == '':
            data_start = i + 1
            break
    if data_start is None:
        data_start = 3
    ax1, ax2 = [], []
    for li in range(data_start, len(lines)):
        line = lines[li].strip()
        if not line:
            continue
        if line.startswith(':END'):
            break
        parts = line.split()
        if len(parts) % 2 != 0:
            raise ValueError(f"{path}: Odd token count at line {li+1}")
        row1, row2 = [], []
        for j in range(0, len(parts), 2):
            row1.append(float(parts[j]))
            row2.append(float(parts[j+1]))
        ax1.append(row1)
        ax2.append(row2)
    return np.array(ax1, dtype=float), np.array(ax2, dtype=float)


def load_dump_pair(dir_path: str) -> Tuple[np.ndarray, np.ndarray]:
    p1 = os.path.join(dir_path, 'Ax1cal.txt')
    p2 = os.path.join(dir_path, 'Ax2cal.txt')
    if not (os.path.exists(p1) and os.path.exists(p2)):
        raise FileNotFoundError(f"Expected Ax1cal.txt/Ax2cal.txt under {dir_path}")
    a1 = np.loadtxt(p1)
    a2 = np.loadtxt(p2)
    return a1, a2


def summarize(a: np.ndarray) -> str:
    return f"shape={a.shape}, min={np.min(a):.4f}, max={np.max(a):.4f}"


def main(argv=None):
    if argv is None:
        argv = sys.argv[1:]
    if len(argv) != 2:
        print("Usage: python tools/compare_dump_to_cal.py <dump_dir> <matlab_cal>")
        return 2
    dump_dir, matlab_cal = argv
    if not os.path.isdir(dump_dir):
        print(f"ERROR: dump dir not found: {dump_dir}")
        return 2
    if not os.path.exists(matlab_cal):
        print(f"ERROR: matlab cal not found: {matlab_cal}")
        return 2

    a1_dump, a2_dump = load_dump_pair(dump_dir)
    a1_ref, a2_ref = parse_start2d(matlab_cal)

    if a1_dump.shape != a1_ref.shape:
        print(f"ERROR: Shape mismatch: dump={a1_dump.shape}, cal={a1_ref.shape}")
        return 2

    d1 = a1_dump - a1_ref
    d2 = a2_dump - a2_ref

    def stats(arr):
        arr_abs = np.abs(arr)
        return float(np.max(arr_abs)), float(np.sqrt(np.mean(arr**2))), float(np.mean(arr_abs))

    max1, rms1, mean1 = stats(d1)
    max2, rms2, mean2 = stats(d2)

    print("=== DUMP VS MATLAB CAL (Ax1cal/Ax2cal) ===")
    print(f"Dump Ax1: {summarize(a1_dump)}")
    print(f"Ref  Ax1: {summarize(a1_ref)}")
    print(f"Dump Ax2: {summarize(a2_dump)}")
    print(f"Ref  Ax2: {summarize(a2_ref)}")
    print("-- Ax1 --")
    print(f"  Max abs diff: {max1:.6f} um  |  RMS: {rms1:.6f} um  |  Mean abs: {mean1:.6f} um")
    print("-- Ax2 --")
    print(f"  Max abs diff: {max2:.6f} um  |  RMS: {rms2:.6f} um  |  Mean abs: {mean2:.6f} um")

    thr = 1e-4
    idx = np.argwhere((np.abs(d1) > thr) | (np.abs(d2) > thr))
    print(f"Mismatches over {thr}: {idx.shape[0]} cells")
    if idx.size > 0:
        print("First 20 mismatches (0-indexed):")
        for (r, c) in idx[:20]:
            print(
                f"  (r={r}, c={c}) Ax1: dump={a1_dump[r,c]:.4f}, ref={a1_ref[r,c]:.4f}; "
                f"Ax2: dump={a2_dump[r,c]:.4f}, ref={a2_ref[r,c]:.4f}"
            )
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
