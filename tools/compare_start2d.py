#!/usr/bin/env python3
import sys
import os
import math
from typing import Tuple

def parse_start2d(path: str) -> Tuple[list, list]:
    """Parse a START2D .cal file into Ax1 and Ax2 2D arrays (rows x cols).
    Returns (Ax1, Ax2) as lists of lists of floats.
    """
    with open(path, 'r', encoding='utf-8', errors='replace') as f:
        lines = f.read().splitlines()

    if len(lines) < 4 or not lines[0].lstrip().startswith(':START2D'):
        raise ValueError(f"{path}: Missing START2D header")

    # First header line: ... num_cols at the end
    try:
        hdr1_tokens = lines[0].split()
        num_cols = int(hdr1_tokens[-1])
    except Exception as e:
        raise ValueError(f"{path}: Could not parse number of columns from header: {e}")

    # Find the blank line after header line 2
    data_start = None
    for i in range(2, min(10, len(lines))):
        if lines[i].strip() == '':
            data_start = i + 1
            break
    if data_start is None:
        # Fallback: assume data begins at line 3 (0-indexed -> 3)
        data_start = 3

    ax1_rows = []
    ax2_rows = []

    for li in range(data_start, len(lines)):
        line = lines[li].strip()
        if not line:
            # allow blank lines inside (unlikely)
            continue
        if line.startswith(':END'):
            break
        # Split on any whitespace (tabs/spaces); START2D pairs are Ax1 Ax2 repeating across columns
        toks = line.split()
        if len(toks) == 0:
            continue
        if len(toks) % 2 != 0:
            raise ValueError(f"{path}: data line {li+1} has odd token count ({len(toks)})")
        if len(toks) != 2 * num_cols:
            # Some files might have trailing zeros or formatting quirks, but this should hold
            # Try to proceed if len is a multiple of 2 and infer cols
            inferred_cols = len(toks) // 2
            if inferred_cols != num_cols:
                raise ValueError(
                    f"{path}: data line {li+1} token count {len(toks)} != 2*num_cols ({2*num_cols})"
                )
        ax1_vals = []
        ax2_vals = []
        for j in range(num_cols):
            a1 = float(toks[2*j])
            a2 = float(toks[2*j+1])
            ax1_vals.append(a1)
            ax2_vals.append(a2)
        ax1_rows.append(ax1_vals)
        ax2_rows.append(ax2_vals)

    if not ax1_rows:
        raise ValueError(f"{path}: No data rows parsed")

    return ax1_rows, ax2_rows


def stats(diff_flat):
    n = len(diff_flat)
    if n == 0:
        return 0.0, 0.0, 0.0
    abs_vals = [abs(x) for x in diff_flat]
    max_abs = max(abs_vals)
    mean_sq = sum(x*x for x in diff_flat) / n
    rms = math.sqrt(mean_sq)
    mean_abs = sum(abs_vals) / n
    return max_abs, rms, mean_abs


def main(argv=None):
    if argv is None:
        argv = sys.argv[1:]
    if len(argv) != 2:
        print("Usage: python tools/compare_start2d.py <matlab.cal> <python.cal>")
        return 2
    ref_path, test_path = argv
    if not os.path.exists(ref_path):
        print(f"ERROR: Not found: {ref_path}")
        return 2
    if not os.path.exists(test_path):
        print(f"ERROR: Not found: {test_path}")
        return 2

    a1_ref, a2_ref = parse_start2d(ref_path)
    a1_test, a2_test = parse_start2d(test_path)

    rows_ref, cols_ref = len(a1_ref), len(a1_ref[0])
    rows_test, cols_test = len(a1_test), len(a1_test[0])

    if (rows_ref, cols_ref) != (rows_test, cols_test):
        print(f"ERROR: Shape mismatch: ref={rows_ref}x{cols_ref}, test={rows_test}x{cols_test}")
        return 2

    # Flatten and compute diffs
    diffs_a1 = []
    diffs_a2 = []
    mismatches = []  # (row,col, a1_ref,a1_test, a2_ref,a2_test)
    thr = 1e-4  # 0.0001 (um)

    for i in range(rows_ref):
        for j in range(cols_ref):
            d1 = a1_test[i][j] - a1_ref[i][j]
            d2 = a2_test[i][j] - a2_ref[i][j]
            diffs_a1.append(d1)
            diffs_a2.append(d2)
            if abs(d1) > thr or abs(d2) > thr:
                mismatches.append((i, j, a1_ref[i][j], a1_test[i][j], a2_ref[i][j], a2_test[i][j]))

    max_a1, rms_a1, meanabs_a1 = stats(diffs_a1)
    max_a2, rms_a2, meanabs_a2 = stats(diffs_a2)

    print("=== START2D CAL COMPARISON ===")
    print(f"Grid size: {rows_ref} x {cols_ref}")
    print(f"Tolerance for mismatch listing: {thr} um")
    print("-- Ax1 --")
    print(f"  Max abs diff: {max_a1:.6f} um")
    print(f"  RMS diff:     {rms_a1:.6f} um")
    print(f"  Mean abs diff:{meanabs_a1:.6f} um")
    print("-- Ax2 --")
    print(f"  Max abs diff: {max_a2:.6f} um")
    print(f"  RMS diff:     {rms_a2:.6f} um")
    print(f"  Mean abs diff:{meanabs_a2:.6f} um")

    over_1e3 = sum(1 for x in diffs_a1+diffs_a2 if abs(x) > 1e-3)
    over_1e4 = sum(1 for x in diffs_a1+diffs_a2 if abs(x) > 1e-4)
    total = len(diffs_a1) + len(diffs_a2)
    print("-- Counts over thresholds --")
    print(f"  >1e-3: {over_1e3}/{total}")
    print(f"  >1e-4: {over_1e4}/{total}")

    if mismatches:
        print("-- First 20 mismatches (0-indexed row,col) --")
        for (i, j, r1, t1, r2, t2) in mismatches[:20]:
            print(f"  (r={i}, c={j}) Ax1: ref={r1:.4f}, test={t1:.4f} | Ax2: ref={r2:.4f}, test={t2:.4f}")
    else:
        print("All values match within tolerance.")

    return 0

if __name__ == '__main__':
    raise SystemExit(main())
