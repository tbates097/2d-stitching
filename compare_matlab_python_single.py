#!/usr/bin/env python3
"""
Compare MATLAB/Octave single zone processing with Python equivalent
"""

import numpy as np
import pandas as pd
import sys
from pathlib import Path

# Add the parent directory to sys.path to import our modules
sys.path.append(str(Path(__file__).parent))

from stitch2d_pipeline import step1_parse_header, step2_load_data, step3_create_grid

def analyze_matlab_octave_output():
    """Analyze the output we got from MATLAB/Octave"""
    print("=== MATLAB/Octave Single Zone Analysis ===")
    print("Grid: 36x36 points")
    print("Coordinate range: -250 to 100 mm (both axes)")
    print("Ax1Err range: -0.717427 to 0.368657 μm")
    print("Ax2Err range: -3.874119 to 0.180000 μm") 
    print("Zero-referencing offsets: Ax1=0.000000, Ax2=0.000000")
    print("Slope coefficients: Ax1=[0.002845, 0.213403], Ax2=[-0.012465, -0.934883]")
    print("Orthogonality: -1.984213 arc-sec")
    print()

def process_python_single_zone():
    """Process the same single zone file with Python and compare"""
    print("=== Python Single Zone Processing ===")
    
    # Load the same zone file that MATLAB/Octave processed
    zone_file = "MATLAB Source/642583-1-1-CZ1.dat"
    if not Path(zone_file).exists():
        print(f"Zone file not found: {zone_file}")
        return None
        
    # Step 1: Parse header
    config = step1_parse_header(zone_file)
    
    # Print configuration info to match MATLAB debug output
    print(f"SN: {config['SN']}")
    print(f"Ax1Name: {config['Ax1Name']}, Ax1Num: {config['Ax1Num']}, Ax1Sign: {config['Ax1Sign']}")
    print(f"Ax2Name: {config['Ax2Name']}, Ax2Num: {config['Ax2Num']}, Ax2Sign: {config['Ax2Sign']}")
    print(f"UserUnit: {config['UserUnit']}, calDivisor: {config['calDivisor']}")
    print()
    
    # Step 2: Load data
    data_raw = step2_load_data(zone_file, config)
    
    # Print raw data info
    print("=== Raw Data Loading ===")
    print(f"Data points: {len(data_raw['Ax1RelErr'])}")
    print("First 5 data points:")
    for i in range(min(5, len(data_raw['Ax1RelErr']))):
        print(f"  {data_raw['Ax1TestLoc'][i]:.1f} {data_raw['Ax2TestLoc'][i]:.1f} {data_raw['Ax1PosCmd'][i]:.6f} {data_raw['Ax2PosCmd'][i]:.6f} {data_raw['Ax1RelErr'][i]:.6f} {data_raw['Ax2RelErr'][i]:.6f}")
    print()
    
    # Calculate error ranges
    ax1_err = data_raw['Ax1RelErr_um']
    ax2_err = data_raw['Ax2RelErr_um']
    
    print("=== Error Processing ===")
    print(f"Ax1RelErr range: {ax1_err.min():.6f} to {ax1_err.max():.6f} μm")
    print(f"Ax2RelErr range: {ax2_err.min():.6f} to {ax2_err.max():.6f} μm")
    
    # Step 3: Create grid data
    grid_data = step3_create_grid(data_raw)
    
    print(f"Grid: {grid_data['SizeGrid'][0]}x{grid_data['SizeGrid'][1]} points")
    print(f"Ax1 range: {grid_data['Y'].min():.1f} to {grid_data['Y'].max():.1f} mm")
    print(f"Ax2 range: {grid_data['X'].min():.1f} to {grid_data['X'].max():.1f} mm")
    
    # Check sampling distances
    ax1_dist = data_raw['Ax1SampDist']
    ax2_dist = data_raw['Ax2SampDist']
    print(f"Sample distances: Ax1={ax1_dist:.6f}, Ax2={ax2_dist:.6f}")
    print()
    
    # Print grid corners for comparison with MATLAB
    print("=== Grid Creation ===")
    print(f"Grid shape: {grid_data['SizeGrid'][0]}x{grid_data['SizeGrid'][1]}")
    
    # Extract corner values
    X = grid_data['X']
    Y = grid_data['Y']
    ax1_err_grid = grid_data['Ax1Err']
    ax2_err_grid = grid_data['Ax2Err']
    
    print(f"X corners: TL={X[0,0]:.1f}, TR={X[0,-1]:.1f}, BL={X[-1,0]:.1f}, BR={X[-1,-1]:.1f}")
    print(f"Y corners: TL={Y[0,0]:.1f}, TR={Y[0,-1]:.1f}, BL={Y[-1,0]:.1f}, BR={Y[-1,-1]:.1f}")
    print(f"Ax1Err corners: TL={ax1_err_grid[0,0]:.6f}, TR={ax1_err_grid[0,-1]:.6f}, BL={ax1_err_grid[-1,0]:.6f}, BR={ax1_err_grid[-1,-1]:.6f}")
    print(f"Ax2Err corners: TL={ax2_err_grid[0,0]:.6f}, TR={ax2_err_grid[0,-1]:.6f}, BL={ax2_err_grid[-1,0]:.6f}, BR={ax2_err_grid[-1,-1]:.6f}")
    print()
    
    # Calculate slope coefficients using Python pipeline method
    from stitch2d_pipeline import step4_calculate_slopes
    slope_data = step4_calculate_slopes(grid_data)
    
    print("=== Slope Calculation ===")
    print(f"Python Ax1Coef: [{slope_data['Ax1Coef'][1]:.6f} {slope_data['Ax1Coef'][0]:.6f}] (vs MATLAB: [0.002845 0.213403])")
    print(f"Python Ax2Coef: [{slope_data['Ax2Coef'][1]:.6f} {slope_data['Ax2Coef'][0]:.6f}] (vs MATLAB: [-0.012465 -0.934883])")
    print(f"Python Orthogonality: {slope_data['orthog']:.6f} arc-sec (vs MATLAB: -1.984213)")
    print()
    
    # Check if Python applies zero-referencing by default
    print("=== Zero-referencing Check ===")
    print("Python typically applies zero-referencing in multi-zone stitching")
    print("For single zone, Python error ranges:")
    print(f"Ax1Err range: {ax1_err_grid.min():.6f} to {ax1_err_grid.max():.6f} μm")
    print(f"Ax2Err range: {ax2_err_grid.min():.6f} to {ax2_err_grid.max():.6f} μm")
    print()
    
    return {
        'config': config,
        'data_raw': data_raw,
        'grid_data': grid_data,
        'slope_data': slope_data
    }

def compare_coordinate_systems():
    """Compare coordinate system interpretation"""
    print("=== Coordinate System Comparison ===")
    print("MATLAB/Octave interpretation:")
    print("  - Ax1Name: Y (vertical axis)")
    print("  - Ax2Name: X (horizontal axis)")  
    print("  - Grid indexing: Y varies with row, X varies with column")
    print()
    print("Python interpretation:")
    print("  - Should match MATLAB naming convention")
    print("  - Need to verify grid creation and indexing")
    print()

def main():
    print("Comparing MATLAB/Octave vs Python Single Zone Processing")
    print("=" * 60)
    
    # Show MATLAB results
    analyze_matlab_octave_output()
    
    # Process with Python
    python_results = process_python_single_zone()
    
    # Compare coordinate systems
    compare_coordinate_systems()
    
    # Summary
    print("=== Key Differences to Investigate ===")
    print("1. Zero-referencing: MATLAB shows 0.0 offsets, Python may apply different logic")
    print("2. Slope calculation: Different algorithms may produce different coefficients") 
    print("3. Grid indexing: Coordinate system interpretation differences")
    print("4. Error scaling: Unit conversion and scaling factors")
    print("5. Data processing order: Raw data -> grid -> slopes -> corrections")
    print()
    print("Next steps:")
    print("- Check if Python single-zone processing matches MATLAB exactly")
    print("- Verify coordinate system conventions")
    print("- Compare intermediate processing steps")

if __name__ == "__main__":
    main()