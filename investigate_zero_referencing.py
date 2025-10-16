#!/usr/bin/env python3
"""
Investigate the zero-referencing difference between MATLAB and Python
"""

import numpy as np
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).parent))

from stitch2d_pipeline import (step1_parse_header, step2_load_data, step3_create_grid, 
                               step4_calculate_slopes, step5_process_errors)

def main():
    zone_file = "MATLAB Source/642583-1-1-CZ1.dat"
    
    # Process with Python pipeline
    config = step1_parse_header(zone_file)
    data_raw = step2_load_data(zone_file, config)
    grid_data = step3_create_grid(data_raw)
    slope_data = step4_calculate_slopes(grid_data)
    processed_data = step5_process_errors(grid_data, slope_data)
    
    print("=== Investigating Zero-Referencing Differences ===")
    print()
    
    print("MATLAB Zero-referencing offsets: Ax1=0.000000, Ax2=0.000000")
    print("This suggests MATLAB does NOT apply zero-referencing to single zones")
    print()
    
    print("Python data processing:")
    print(f"Raw Ax1RelErr mean: {np.mean(data_raw['Ax1RelErr']):.6f}")
    print(f"Raw Ax2RelErr mean: {np.mean(data_raw['Ax2RelErr']):.6f}")
    print()
    
    print(f"After mean removal (step2) - Ax1RelErr_um mean: {np.mean(data_raw['Ax1RelErr_um']):.6f}")
    print(f"After mean removal (step2) - Ax2RelErr_um mean: {np.mean(data_raw['Ax2RelErr_um']):.6f}")
    print()
    
    print("Grid data ranges:")
    print(f"Grid Ax1Err mean: {np.mean(grid_data['Ax1Err']):.6f}")
    print(f"Grid Ax2Err mean: {np.mean(grid_data['Ax2Err']):.6f}")
    print(f"Grid Ax1Err range: {grid_data['Ax1Err'].min():.6f} to {grid_data['Ax1Err'].max():.6f}")
    print(f"Grid Ax2Err range: {grid_data['Ax2Err'].min():.6f} to {grid_data['Ax2Err'].max():.6f}")
    print()
    
    print("After slope removal and zero-referencing (step5):")
    print(f"Final Ax1Err mean: {np.mean(processed_data['Ax1Err']):.6f}")
    print(f"Final Ax2Err mean: {np.mean(processed_data['Ax2Err']):.6f}")
    print(f"Final Ax1Err range: {processed_data['Ax1Err'].min():.6f} to {processed_data['Ax1Err'].max():.6f}")
    print(f"Final Ax2Err range: {processed_data['Ax2Err'].min():.6f} to {processed_data['Ax2Err'].max():.6f}")
    print()
    
    print("Zero-reference point values:")
    print(f"Final Ax1Err[0,0] = {processed_data['Ax1Err'][0,0]:.6f}")
    print(f"Final Ax2Err[0,0] = {processed_data['Ax2Err'][0,0]:.6f}")
    print()
    
    print("=== Comparing with MATLAB final ranges ===")
    print("MATLAB after zero-ref: Ax1Err: -0.717427 to 0.368657, Ax2Err: -3.874119 to 0.180000")
    print(f"Python after zero-ref: Ax1Err: {processed_data['Ax1Err'].min():.6f} to {processed_data['Ax1Err'].max():.6f}, Ax2Err: {processed_data['Ax2Err'].min():.6f} to {processed_data['Ax2Err'].max():.6f}")
    print()
    
    # Let's create a version without the initial mean removal to match MATLAB
    print("=== Testing without initial mean removal (to match MATLAB) ===")
    
    # Reload raw data without mean centering
    with open(zone_file, 'r') as f:
        lines = f.readlines()

    data_start = 0
    for i, line in enumerate(lines):
        line = line.strip()
        if line and not line.startswith('%') and not line.startswith('#'):
            try:
                float(line.split()[0])
                data_start = i
                break
            except (ValueError, IndexError):
                continue

    s = np.loadtxt(zone_file, skiprows=data_start)
    sort_indices = np.lexsort((s[:, 0], s[:, 1]))
    s = s[sort_indices]
    
    # Create data structure without mean centering
    data_raw_nomean = {}
    data_raw_nomean['Ax1TestLoc'] = s[:, 0].astype(int)
    data_raw_nomean['Ax2TestLoc'] = s[:, 1].astype(int)
    data_raw_nomean['Ax1PosCmd'] = s[:, 2] / config['calDivisor']
    data_raw_nomean['Ax2PosCmd'] = s[:, 3] / config['calDivisor']
    data_raw_nomean['Ax1RelErr'] = s[:, 4] / config['calDivisor']
    data_raw_nomean['Ax2RelErr'] = s[:, 5] / config['calDivisor']

    # NO MEAN REMOVAL - use raw errors directly in microns
    data_raw_nomean['Ax1RelErr_um'] = data_raw_nomean['Ax1RelErr'] * 1000
    data_raw_nomean['Ax2RelErr_um'] = data_raw_nomean['Ax2RelErr'] * 1000

    data_raw_nomean['NumAx1Points'] = int(np.max(data_raw_nomean['Ax1TestLoc']))
    data_raw_nomean['NumAx2Points'] = int(np.max(data_raw_nomean['Ax2TestLoc']))
    data_raw_nomean['Ax1MoveDist'] = np.max(data_raw_nomean['Ax1PosCmd']) - np.min(data_raw_nomean['Ax1PosCmd'])
    data_raw_nomean['Ax2MoveDist'] = np.max(data_raw_nomean['Ax2PosCmd']) - np.min(data_raw_nomean['Ax2PosCmd'])

    if data_raw_nomean['NumAx1Points'] > 1:
        data_raw_nomean['Ax1SampDist'] = data_raw_nomean['Ax1PosCmd'][1] - data_raw_nomean['Ax1PosCmd'][0]
    else:
        data_raw_nomean['Ax1SampDist'] = 0.0

    if data_raw_nomean['NumAx2Points'] > 1:
        data_raw_nomean['Ax2SampDist'] = data_raw_nomean['Ax2PosCmd'][data_raw_nomean['NumAx1Points']] - data_raw_nomean['Ax2PosCmd'][0]
    else:
        data_raw_nomean['Ax2SampDist'] = 0.0

    data_raw_nomean['Ax1Pos'] = data_raw_nomean['Ax1PosCmd'][:data_raw_nomean['NumAx1Points']]
    data_raw_nomean['Ax2Pos'] = data_raw_nomean['Ax2PosCmd'][::data_raw_nomean['NumAx1Points']][:data_raw_nomean['NumAx2Points']]
    
    # Process without mean centering
    grid_data_nomean = step3_create_grid(data_raw_nomean)
    slope_data_nomean = step4_calculate_slopes(grid_data_nomean)
    processed_data_nomean = step5_process_errors(grid_data_nomean, slope_data_nomean)
    
    print("Without initial mean removal:")
    print(f"Raw errors mean: Ax1={np.mean(data_raw_nomean['Ax1RelErr_um']):.6f}, Ax2={np.mean(data_raw_nomean['Ax2RelErr_um']):.6f}")
    print(f"Grid errors range: Ax1={grid_data_nomean['Ax1Err'].min():.6f} to {grid_data_nomean['Ax1Err'].max():.6f}")
    print(f"Grid errors range: Ax2={grid_data_nomean['Ax2Err'].min():.6f} to {grid_data_nomean['Ax2Err'].max():.6f}")
    print(f"Final errors range: Ax1={processed_data_nomean['Ax1Err'].min():.6f} to {processed_data_nomean['Ax1Err'].max():.6f}")
    print(f"Final errors range: Ax2={processed_data_nomean['Ax2Err'].min():.6f} to {processed_data_nomean['Ax2Err'].max():.6f}")
    print()
    
    print("Comparison with MATLAB:")
    matlab_ax1_range = (-0.717427, 0.368657)
    matlab_ax2_range = (-3.874119, 0.180000)
    python_ax1_range = (processed_data_nomean['Ax1Err'].min(), processed_data_nomean['Ax1Err'].max())
    python_ax2_range = (processed_data_nomean['Ax2Err'].min(), processed_data_nomean['Ax2Err'].max())
    
    print(f"MATLAB Ax1Err: {matlab_ax1_range[0]:.6f} to {matlab_ax1_range[1]:.6f}")
    print(f"Python Ax1Err: {python_ax1_range[0]:.6f} to {python_ax1_range[1]:.6f}")
    print(f"Difference: {abs(matlab_ax1_range[0] - python_ax1_range[0]):.6f}, {abs(matlab_ax1_range[1] - python_ax1_range[1]):.6f}")
    print()
    print(f"MATLAB Ax2Err: {matlab_ax2_range[0]:.6f} to {matlab_ax2_range[1]:.6f}")
    print(f"Python Ax2Err: {python_ax2_range[0]:.6f} to {python_ax2_range[1]:.6f}")
    print(f"Difference: {abs(matlab_ax2_range[0] - python_ax2_range[0]):.6f}, {abs(matlab_ax2_range[1] - python_ax2_range[1]):.6f}")

if __name__ == "__main__":
    main()