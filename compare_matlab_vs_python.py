#!/usr/bin/env python3
"""
Compare MATLAB MultiZone2DCal_test.m debug results with Python stitching pipeline results.

This script:
1. Loads MATLAB debug files (converted to v7 format)
2. Runs Python stitching pipeline on the same zone files
3. Compares key matrices and calibration tables
4. Reports differences, max/RMS errors, and first mismatches
"""

import os
import sys
import numpy as np
import scipy.io as sio
from pathlib import Path

# Import our Python pipeline
from stitch2d_pipeline import stitch_and_calibrate

def load_matlab_debug_results():
    """Load MATLAB debug results from converted v7 files"""
    print("="*60)
    print("LOADING MATLAB DEBUG RESULTS")
    print("="*60)
    
    # Load main multizone debug file
    matlab_file = 'matlab_multizone_debug_v7.mat'
    if not os.path.exists(matlab_file):
        raise FileNotFoundError(f"MATLAB debug file not found: {matlab_file}")
    
    print(f"Loading {matlab_file}...")
    matlab_data = sio.loadmat(matlab_file)
    
    # Extract key matrices
    matlab_results = {
        'X': matlab_data['X'],
        'Y': matlab_data['Y'],
        'Ax1Err': matlab_data['Ax1Err'],
        'Ax2Err': matlab_data['Ax2Err'],
        'Ax1cal': matlab_data.get('Ax1cal'),
        'Ax2cal': matlab_data.get('Ax2cal'),
        'Ax1Coef': matlab_data.get('Ax1Coef'),
        'Ax2Coef': matlab_data.get('Ax2Coef'),
        'NumAx1Points': matlab_data.get('NumAx1Points'),
        'NumAx2Points': matlab_data.get('NumAx2Points'),
        'UserUnit': matlab_data.get('UserUnit'),
        'calDivisor': matlab_data.get('calDivisor'),
    }
    
    # Print summary
    print(f"MATLAB Results Summary:")
    print(f"  Grid size: {matlab_results['X'].shape}")
    print(f"  X range: {matlab_results['X'].min():.3f} to {matlab_results['X'].max():.3f}")
    print(f"  Y range: {matlab_results['Y'].min():.3f} to {matlab_results['Y'].max():.3f}")
    print(f"  Ax1Err range: {matlab_results['Ax1Err'].min():.6f} to {matlab_results['Ax1Err'].max():.6f}")
    print(f"  Ax2Err range: {matlab_results['Ax2Err'].min():.6f} to {matlab_results['Ax2Err'].max():.6f}")
    
    if matlab_results['Ax1cal'] is not None:
        print(f"  Ax1cal shape: {matlab_results['Ax1cal'].shape}")
        print(f"  Ax2cal shape: {matlab_results['Ax2cal'].shape}")
    
    return matlab_results

def run_python_stitching():
    """Run Python stitching on the same zone files"""
    print("\n" + "="*60)
    print("RUNNING PYTHON STITCHING PIPELINE")
    print("="*60)
    
    # Find zone files (same ones used by MATLAB script)
    zone_files = []
    for i in range(1, 5):  # CZ1, CZ2, CZ3, CZ4
        zone_file = f'642583-1-1-CZ{i}.dat'
        if os.path.exists(zone_file):
            zone_files.append(zone_file)
        else:
            print(f"Warning: Zone file not found: {zone_file}")
    
    if len(zone_files) != 4:
        raise FileNotFoundError(f"Expected 4 zone files, found {len(zone_files)}: {zone_files}")
    
    print(f"Found zone files: {zone_files}")
    
    # Create temporary output directory for Python results
    python_dir = "python_debug_dump"
    os.makedirs(python_dir, exist_ok=True)
    
    # Run Python stitching
    result = stitch_and_calibrate(
        zone_files=zone_files,
        rows=2,
        cols=2,
        out_cal=os.path.join(python_dir, 'python_multizone.cal'),
        out_dat=os.path.join(python_dir, 'python_multizone.dat'),
        plot_path=os.path.join(python_dir, 'python_multizone_plot.png'),
        dump_cal_dir=python_dir
    )
    
    # Extract results
    grid_system = result['grid_system']
    python_results = {
        'X': grid_system['X'],
        'Y': grid_system['Y'], 
        'Ax1Err': grid_system['Ax1Err'],
        'Ax2Err': grid_system['Ax2Err'],
        'avgCount': grid_system['avgCount'],
    }
    
    # Load calibration tables from dumps
    try:
        python_results['Ax1cal'] = np.load(os.path.join(python_dir, 'Ax1cal.npy'))
        python_results['Ax2cal'] = np.load(os.path.join(python_dir, 'Ax2cal.npy'))
    except FileNotFoundError:
        print("Warning: Calibration table dumps not found")
        python_results['Ax1cal'] = None
        python_results['Ax2cal'] = None
    
    print(f"Python Results Summary:")
    print(f"  Grid size: {python_results['X'].shape}")
    print(f"  X range: {python_results['X'].min():.3f} to {python_results['X'].max():.3f}")
    print(f"  Y range: {python_results['Y'].min():.3f} to {python_results['Y'].max():.3f}")
    print(f"  Ax1Err range: {python_results['Ax1Err'].min():.6f} to {python_results['Ax1Err'].max():.6f}")
    print(f"  Ax2Err range: {python_results['Ax2Err'].min():.6f} to {python_results['Ax2Err'].max():.6f}")
    
    return python_results

def compare_matrices(name, matlab_mat, python_mat, tolerance=1e-6):
    """Compare two matrices and report differences"""
    print(f"\n--- Comparing {name} ---")
    
    if matlab_mat is None or python_mat is None:
        print(f"  Warning: One matrix is None (MATLAB: {matlab_mat is not None}, Python: {python_mat is not None})")
        return
    
    if matlab_mat.shape != python_mat.shape:
        print(f"  ERROR: Shape mismatch - MATLAB: {matlab_mat.shape}, Python: {python_mat.shape}")
        return
    
    # Calculate differences
    diff = matlab_mat - python_mat
    abs_diff = np.abs(diff)
    
    # Statistics
    max_abs_diff = np.max(abs_diff)
    mean_abs_diff = np.mean(abs_diff) 
    rms_diff = np.sqrt(np.mean(diff**2))
    
    # Find first significant mismatch
    mismatch_mask = abs_diff > tolerance
    if np.any(mismatch_mask):
        mismatch_indices = np.where(mismatch_mask)
        first_idx = (mismatch_indices[0][0], mismatch_indices[1][0])
        matlab_val = matlab_mat[first_idx]
        python_val = python_mat[first_idx]
        diff_val = diff[first_idx]
    else:
        first_idx = None
        matlab_val = python_val = diff_val = None
    
    print(f"  Shape: {matlab_mat.shape}")
    print(f"  Max absolute difference: {max_abs_diff:.9f}")
    print(f"  Mean absolute difference: {mean_abs_diff:.9f}")
    print(f"  RMS difference: {rms_diff:.9f}")
    print(f"  Points exceeding tolerance ({tolerance}): {np.sum(mismatch_mask)}")
    
    if first_idx is not None:
        print(f"  First mismatch at [{first_idx[0]}, {first_idx[1]}]:")
        print(f"    MATLAB: {matlab_val:.9f}")
        print(f"    Python: {python_val:.9f}")
        print(f"    Difference: {diff_val:.9f}")
    else:
        print(f"  ✓ All values within tolerance ({tolerance})")
    
    # Overall assessment
    if max_abs_diff < tolerance:
        print(f"  ✓ PASS: Matrices match within tolerance")
    elif max_abs_diff < 0.001:
        print(f"  ~ CLOSE: Small differences (max {max_abs_diff:.6f})")
    else:
        print(f"  ✗ FAIL: Significant differences detected")

def compare_calibration_performance(matlab_data, python_data):
    """Compare overall calibration performance metrics"""
    print("\n" + "="*60)
    print("CALIBRATION PERFORMANCE COMPARISON")
    print("="*60)
    
    # Calculate RMS errors for both
    matlab_ax1_rms = np.sqrt(np.mean(matlab_data['Ax1Err']**2))
    matlab_ax2_rms = np.sqrt(np.mean(matlab_data['Ax2Err']**2))
    
    python_ax1_rms = np.sqrt(np.mean(python_data['Ax1Err']**2))
    python_ax2_rms = np.sqrt(np.mean(python_data['Ax2Err']**2))
    
    print(f"RMS Error Comparison:")
    print(f"  Ax1 RMS - MATLAB: {matlab_ax1_rms:.6f}, Python: {python_ax1_rms:.6f}, Diff: {abs(matlab_ax1_rms - python_ax1_rms):.6f}")
    print(f"  Ax2 RMS - MATLAB: {matlab_ax2_rms:.6f}, Python: {python_ax2_rms:.6f}, Diff: {abs(matlab_ax2_rms - python_ax2_rms):.6f}")
    
    # Peak-to-peak errors
    matlab_ax1_pk = np.max(matlab_data['Ax1Err']) - np.min(matlab_data['Ax1Err'])
    matlab_ax2_pk = np.max(matlab_data['Ax2Err']) - np.min(matlab_data['Ax2Err'])
    
    python_ax1_pk = np.max(python_data['Ax1Err']) - np.min(python_data['Ax1Err'])
    python_ax2_pk = np.max(python_data['Ax2Err']) - np.min(python_data['Ax2Err'])
    
    print(f"Peak-to-Peak Error Comparison:")
    print(f"  Ax1 P-P - MATLAB: {matlab_ax1_pk:.6f}, Python: {python_ax1_pk:.6f}, Diff: {abs(matlab_ax1_pk - python_ax1_pk):.6f}")
    print(f"  Ax2 P-P - MATLAB: {matlab_ax2_pk:.6f}, Python: {python_ax2_pk:.6f}, Diff: {abs(matlab_ax2_pk - python_ax2_pk):.6f}")

def load_zone_debug_files():
    """Load individual zone debug files for detailed comparison"""
    print("\n" + "="*60)
    print("LOADING INDIVIDUAL ZONE DEBUG FILES")
    print("="*60)
    
    zone_debug_data = {}
    for i in range(1, 5):
        zone_file = f'642583-1-1-CZ{i}_zone_debug_v7.mat'
        if os.path.exists(zone_file):
            print(f"Loading {zone_file}...")
            data = sio.loadmat(zone_file)
            zone_debug_data[f'CZ{i}'] = {
                'X': data['X'],
                'Y': data['Y'],
                'Ax1Err': data['Ax1Err'],
                'Ax2Err': data['Ax2Err'],
            }
            print(f"  Grid size: {data['X'].shape}")
        else:
            print(f"Warning: Zone debug file not found: {zone_file}")
    
    return zone_debug_data

def main():
    """Main comparison function"""
    print("MATLAB vs Python Multi-Zone Stitching Comparison")
    print("Current directory:", os.getcwd())
    
    try:
        # Load MATLAB results
        matlab_results = load_matlab_debug_results()
        
        # Run Python stitching
        python_results = run_python_stitching()
        
        # Compare main results
        print("\n" + "="*60)
        print("MATRIX COMPARISON RESULTS")
        print("="*60)
        
        compare_matrices("Position X", matlab_results['X'], python_results['X'], tolerance=1e-6)
        compare_matrices("Position Y", matlab_results['Y'], python_results['Y'], tolerance=1e-6)
        compare_matrices("Axis 1 Error", matlab_results['Ax1Err'], python_results['Ax1Err'], tolerance=1e-6)
        compare_matrices("Axis 2 Error", matlab_results['Ax2Err'], python_results['Ax2Err'], tolerance=1e-6)
        
        if matlab_results['Ax1cal'] is not None and python_results['Ax1cal'] is not None:
            compare_matrices("Axis 1 Calibration", matlab_results['Ax1cal'], python_results['Ax1cal'], tolerance=1e-4)
            compare_matrices("Axis 2 Calibration", matlab_results['Ax2cal'], python_results['Ax2cal'], tolerance=1e-4)
        
        # Performance comparison
        compare_calibration_performance(matlab_results, python_results)
        
        # Optional: Load and compare individual zones
        # zone_debug = load_zone_debug_files()
        
        print("\n" + "="*60)
        print("COMPARISON COMPLETE")
        print("="*60)
        print("Check the results above to verify your Python implementation matches MATLAB.")
        
    except Exception as e:
        print(f"ERROR: {e}")
        import traceback
        traceback.print_exc()
        return 1
    
    return 0

if __name__ == "__main__":
    sys.exit(main())