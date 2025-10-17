#!/usr/bin/env python3
"""
Python multizone debug script to match MATLAB/Octave analysis
"""

import numpy as np
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).parent))

from stitch2d_pipeline import (step1_parse_header, step2_load_data, step3_create_grid, 
                               step4_calculate_slopes, step5_process_errors)

def process_single_zone_debug(zone_file, zone_num):
    """Process a single zone with debug output to match MATLAB format"""
    print(f"\n=== PYTHON ZONE {zone_num}: {zone_file} ===")
    
    # Process with Python pipeline
    config = step1_parse_header(zone_file)
    data_raw = step2_load_data(zone_file, config)
    grid_data = step3_create_grid(data_raw)
    slope_data = step4_calculate_slopes(grid_data)
    processed_data = step5_process_errors(grid_data, slope_data)
    
    # Match MATLAB debug format
    print("=== DEBUG: Header Parsing ===")
    print(f"SN: {config['SN']}")
    print(f"Ax1Name: {config['Ax1Name']}, Ax1Num: {config['Ax1Num']}, Ax1Sign: {config['Ax1Sign']}, Ax1Gantry: {config['Ax1Gantry']}")
    print(f"Ax2Name: {config['Ax2Name']}, Ax2Num: {config['Ax2Num']}, Ax2Sign: {config['Ax2Sign']}, Ax2Gantry: {config['Ax2Gantry']}")
    print(f"UserUnit: {config['UserUnit']}, calDivisor: {config['calDivisor']}")
    
    print("\n=== DEBUG: Raw Data Loading ===")
    print(f"Data shape: {len(data_raw['Ax1RelErr'])} x 6")
    print("First 5 data points:")
    for i in range(min(5, len(data_raw['Ax1RelErr']))):
        print(f"  {data_raw['Ax1TestLoc'][i]:.1f} {data_raw['Ax2TestLoc'][i]:.1f} {data_raw['Ax1PosCmd'][i]:.6f} {data_raw['Ax2PosCmd'][i]:.6f} {data_raw['Ax1RelErr'][i]:.6f} {data_raw['Ax2RelErr'][i]:.6f}")

    print("\n=== DEBUG: Error Processing ===")
    print(f"Ax1RelErr range: {data_raw['Ax1RelErr_um'].min():.6f} to {data_raw['Ax1RelErr_um'].max():.6f} um")
    print(f"Ax2RelErr range: {data_raw['Ax2RelErr_um'].min():.6f} to {data_raw['Ax2RelErr_um'].max():.6f} um")
    print(f"Grid: {data_raw['NumAx1Points']}x{data_raw['NumAx2Points']} points")
    print(f"Ax1 range: {grid_data['Y'].min():.1f} to {grid_data['Y'].max():.1f} mm (dist: {data_raw['Ax1MoveDist']:.1f})")
    print(f"Ax2 range: {grid_data['X'].min():.1f} to {grid_data['X'].max():.1f} mm (dist: {data_raw['Ax2MoveDist']:.1f})")
    print(f"Sample distances: Ax1={data_raw['Ax1SampDist']:.6f}, Ax2={data_raw['Ax2SampDist']:.6f}")

    print("\n=== DEBUG: Grid Creation ===")
    X, Y = grid_data['X'], grid_data['Y']
    print(f"Grid shape: {X.shape[0]}x{X.shape[1]}")
    print(f"X corners: TL={X[0,0]:.1f}, TR={X[0,-1]:.1f}, BL={X[-1,0]:.1f}, BR={X[-1,-1]:.1f}")
    print(f"Y corners: TL={Y[0,0]:.1f}, TR={Y[0,-1]:.1f}, BL={Y[-1,0]:.1f}, BR={Y[-1,-1]:.1f}")
    
    Ax1Err, Ax2Err = grid_data['Ax1Err'], grid_data['Ax2Err']
    print(f"Ax1Err corners: TL={Ax1Err[0,0]:.6f}, TR={Ax1Err[0,-1]:.6f}, BL={Ax1Err[-1,0]:.6f}, BR={Ax1Err[-1,-1]:.6f}")
    print(f"Ax2Err corners: TL={Ax2Err[0,0]:.6f}, TR={Ax2Err[0,-1]:.6f}, BL={Ax2Err[-1,0]:.6f}, BR={Ax2Err[-1,-1]:.6f}")

    print("\n=== DEBUG: Slope Calculation ===")
    ax1_coef = slope_data['Ax1Coef']
    ax2_coef = slope_data['Ax2Coef']
    print(f"Ax1Coef: [{ax1_coef[1]:.6f} {ax1_coef[0]:.6f}]")  # Note: polyfit returns [slope, intercept]
    print(f"Ax2Coef: [{ax2_coef[1]:.6f} {ax2_coef[0]:.6f}]")
    print(f"Orthogonality: {slope_data['orthog']:.6f} arc-sec")
    
    ax1_line_range = f"{slope_data['Ax1Line'].min():.6f} to {slope_data['Ax1Line'].max():.6f}"
    ax2_line_range = f"{slope_data['Ax2Line'].min():.6f} to {slope_data['Ax2Line'].max():.6f}"
    print(f"Ax1Line range: {ax1_line_range}")
    print(f"Ax2Line range: {ax2_line_range}")

    print("\n=== DEBUG: Final Error Processing ===")
    # Python applies zero-referencing at [0,0]
    zero_ref_ax1 = processed_data['Ax1Err'][0,0]
    zero_ref_ax2 = processed_data['Ax2Err'][0,0]
    print(f"Zero-referencing offsets: Ax1={zero_ref_ax1:.6f}, Ax2={zero_ref_ax2:.6f}")
    print(f"After zero-ref, Ax1Err range: {processed_data['Ax1Err'].min():.6f} to {processed_data['Ax1Err'].max():.6f}")
    print(f"After zero-ref, Ax2Err range: {processed_data['Ax2Err'].min():.6f} to {processed_data['Ax2Err'].max():.6f}")
    print(f"VectorErr range: {processed_data['VectorErr'].min():.6f} to {processed_data['VectorErr'].max():.6f}")

    print("\n=== DEBUG: Final Data Structure ===")
    print(f"data.X shape: {processed_data['X'].shape[0]}x{processed_data['X'].shape[1]}")
    print(f"data.Y shape: {processed_data['Y'].shape[0]}x{processed_data['Y'].shape[1]}")
    print(f"data.Ax1Err shape: {processed_data['Ax1Err'].shape[0]}x{processed_data['Ax1Err'].shape[1]}")
    print(f"data.Ax2Err shape: {processed_data['Ax2Err'].shape[0]}x{processed_data['Ax2Err'].shape[1]}")

    # Summary matching MATLAB format
    print(f"Zone {zone_num} summary:")
    print(f"  Grid size: {X.shape[0]}x{X.shape[1]}")
    print(f"  X range: {X.min():.1f} to {X.max():.1f} mm")
    print(f"  Y range: {Y.min():.1f} to {Y.max():.1f} mm")
    print(f"  Ax1Err range: {processed_data['Ax1Err'].min():.6f} to {processed_data['Ax1Err'].max():.6f} μm")
    print(f"  Ax2Err range: {processed_data['Ax2Err'].min():.6f} to {processed_data['Ax2Err'].max():.6f} μm")
    
    print("  Corner positions:")
    print(f"    TL: ({X[0,0]:.1f}, {Y[0,0]:.1f}), TR: ({X[0,-1]:.1f}, {Y[0,-1]:.1f})")
    print(f"    BL: ({X[-1,0]:.1f}, {Y[-1,0]:.1f}), BR: ({X[-1,-1]:.1f}, {Y[-1,-1]:.1f})")
    
    print("  Corner errors:")
    final_ax1 = processed_data['Ax1Err']
    final_ax2 = processed_data['Ax2Err'] 
    print(f"    Ax1Err: TL={final_ax1[0,0]:.6f}, TR={final_ax1[0,-1]:.6f}, BL={final_ax1[-1,0]:.6f}, BR={final_ax1[-1,-1]:.6f}")
    print(f"    Ax2Err: TL={final_ax2[0,0]:.6f}, TR={final_ax2[0,-1]:.6f}, BL={final_ax2[-1,0]:.6f}, BR={final_ax2[-1,-1]:.6f}")
    
    return {
        'config': config,
        'data_raw': data_raw,
        'grid_data': grid_data,
        'slope_data': slope_data,
        'processed_data': processed_data,
        'X': X, 'Y': Y,
        'final_ax1_err': final_ax1,
        'final_ax2_err': final_ax2
    }

def main():
    print("=== PYTHON MULTIZONE 2D CALIBRATION - DEBUG COMPARISON ===")
    print("Processing 4 zones in 2x2 grid to match MATLAB/Octave output")
    
    zone_files = [
        "MATLAB Source/642583-1-1-CZ1.dat",
        "MATLAB Source/642583-1-1-CZ2.dat", 
        "MATLAB Source/642583-1-1-CZ3.dat",
        "MATLAB Source/642583-1-1-CZ4.dat"
    ]
    
    all_zones = []
    
    # Process each zone
    for i, zone_file in enumerate(zone_files, 1):
        zone_result = process_single_zone_debug(zone_file, i)
        all_zones.append(zone_result)
    
    print("\n=== PYTHON ZONE LAYOUT ANALYSIS ===")
    print("Expected 2x2 zone layout:")
    print("  CZ1 (top-left)    | CZ2 (top-right)")
    print("  CZ3 (bottom-left) | CZ4 (bottom-right)")
    
    print("\n=== PYTHON OVERLAP ANALYSIS ===")
    
    # Check horizontal overlaps
    for row in range(2):  # 2 rows
        left_idx = row * 2  # 0 or 2
        right_idx = left_idx + 1  # 1 or 3
        
        if right_idx < len(all_zones):
            left_zone = all_zones[left_idx]
            right_zone = all_zones[right_idx]
            
            left_x_max = left_zone['X'].max()
            right_x_min = right_zone['X'].min()
            h_overlap = left_x_max - right_x_min
            
            print(f"Row {row+1} horizontal overlap (CZ{left_idx+1}-CZ{right_idx+1}): {h_overlap:.3f} mm")
            print(f"  Left zone X max: {left_x_max:.1f}, Right zone X min: {right_x_min:.1f}")
    
    # Check vertical overlaps  
    for col in range(2):  # 2 columns
        top_idx = col  # 0 or 1
        bottom_idx = col + 2  # 2 or 3
        
        if bottom_idx < len(all_zones):
            top_zone = all_zones[top_idx]
            bottom_zone = all_zones[bottom_idx]
            
            top_y_min = top_zone['Y'].min()
            bottom_y_max = bottom_zone['Y'].max()
            v_overlap = bottom_y_max - top_y_min
            
            print(f"Col {col+1} vertical overlap (CZ{top_idx+1}-CZ{bottom_idx+1}): {v_overlap:.3f} mm")
            print(f"  Top zone Y min: {top_y_min:.1f}, Bottom zone Y max: {bottom_y_max:.1f}")
    
    print("\n=== PYTHON COMBINED RANGE ESTIMATE ===")
    
    # Calculate combined ranges
    all_x = np.concatenate([zone['X'].flatten() for zone in all_zones])
    all_y = np.concatenate([zone['Y'].flatten() for zone in all_zones])
    all_ax1_err = np.concatenate([zone['final_ax1_err'].flatten() for zone in all_zones])
    all_ax2_err = np.concatenate([zone['final_ax2_err'].flatten() for zone in all_zones])
    
    print("Combined coordinate ranges:")
    print(f"  X: {all_x.min():.1f} to {all_x.max():.1f} mm (span: {all_x.max()-all_x.min():.1f} mm)")
    print(f"  Y: {all_y.min():.1f} to {all_y.max():.1f} mm (span: {all_y.max()-all_y.min():.1f} mm)")
    
    print("Combined error ranges (individual zones, zero-referenced):")
    print(f"  Ax1Err: {all_ax1_err.min():.6f} to {all_ax1_err.max():.6f} μm")
    print(f"  Ax2Err: {all_ax2_err.min():.6f} to {all_ax2_err.max():.6f} μm")
    
    print("\n=== COMPARISON WITH MATLAB/OCTAVE RESULTS ===")
    print("MATLAB/Octave combined ranges:")
    print("  X: -250.0 to 250.0 mm (span: 500.0 mm)")
    print("  Y: -250.0 to 250.0 mm (span: 500.0 mm)")
    print("  Ax1Err: -1.040121 to 0.747130 μm")
    print("  Ax2Err: -5.392326 to 0.350000 μm")
    print()
    print("Python combined ranges:")
    print(f"  X: {all_x.min():.1f} to {all_x.max():.1f} mm (span: {all_x.max()-all_x.min():.1f} mm)")
    print(f"  Y: {all_y.min():.1f} to {all_y.max():.1f} mm (span: {all_y.max()-all_y.min():.1f} mm)")
    print(f"  Ax1Err: {all_ax1_err.min():.6f} to {all_ax1_err.max():.6f} μm")
    print(f"  Ax2Err: {all_ax2_err.min():.6f} to {all_ax2_err.max():.6f} μm")
    print()
    
    # Calculate differences
    x_range_diff = abs((all_x.max()-all_x.min()) - 500.0)
    y_range_diff = abs((all_y.max()-all_y.min()) - 500.0)
    ax1_min_diff = abs(all_ax1_err.min() - (-1.040121))
    ax1_max_diff = abs(all_ax1_err.max() - 0.747130)
    ax2_min_diff = abs(all_ax2_err.min() - (-5.392326))
    ax2_max_diff = abs(all_ax2_err.max() - 0.350000)
    
    print("Differences:")
    print(f"  X span difference: {x_range_diff:.1f} mm")
    print(f"  Y span difference: {y_range_diff:.1f} mm")
    print(f"  Ax1Err range differences: {ax1_min_diff:.6f} μm (min), {ax1_max_diff:.6f} μm (max)")
    print(f"  Ax2Err range differences: {ax2_min_diff:.6f} μm (min), {ax2_max_diff:.6f} μm (max)")
    
    if x_range_diff < 0.1 and y_range_diff < 0.1:
        print("\n✓ Coordinate ranges match MATLAB/Octave!")
    else:
        print("\n✗ Coordinate ranges differ from MATLAB/Octave")
        
    if ax1_min_diff < 0.01 and ax1_max_diff < 0.01 and ax2_min_diff < 0.01 and ax2_max_diff < 0.01:
        print("✓ Error ranges match MATLAB/Octave!")
    else:
        print("✗ Error ranges differ from MATLAB/Octave")
        print("This confirms that the issue is in multi-zone stitching, not individual zone processing")

if __name__ == "__main__":
    main()