#!/usr/bin/env python3
"""
COMPARE_MULTIZONE_STEP2 - Compare multi-zone Step 2 outputs between MATLAB and Python
"""

import os
import numpy as np


def compare_multizone_step2():
    """Compare multi-zone Step 2 output files"""
    
    print("=" * 60)
    print("MULTI-ZONE STEP 2: MATLAB vs PYTHON COMPARISON")
    print("=" * 60)
    
    octave_file = "multizone_step2_output_octave.txt"
    python_file = "multizone_step2_output_python.txt"
    
    # Check if both files exist
    if not os.path.exists(octave_file):
        print(f"❌ MATLAB output file missing: {octave_file}")
        print("Please run: test_multizone_step2_octave")
        return False
    
    if not os.path.exists(python_file):
        print(f"❌ Python output file missing: {python_file}")
        print("Please run: python multizone_step2_initialize_grid.py")
        return False
    
    # Parse both files
    def parse_config_file(filename):
        config = {}
        with open(filename, 'r') as f:
            for line in f:
                line = line.strip()
                if ':' in line and not line.startswith('==='):
                    key, value = line.split(':', 1)
                    config[key.strip()] = value.strip()
        return config
    
    octave_config = parse_config_file(octave_file)
    python_config = parse_config_file(python_file)
    
    # Get all keys
    all_keys = set(octave_config.keys()) | set(python_config.keys())
    
    print(f"\nFound {len(all_keys)} parameters to compare\n")
    
    matches = 0
    differences = []
    
    # Group parameters for better organization
    system_params = ['SN', 'Ax1Name', 'Ax2Name', 'model', 'operator']
    grid_params = ['incAx1', 'incAx2', 'fullGridSize_rows', 'fullGridSize_cols', 
                   'Ax1size_rows', 'Ax1size_cols', 'zoneCount', 'nonZeroPoints']
    data_params = ['Ax1Master_min', 'Ax1Master_max', 'Ax2Master_min', 'Ax2Master_max',
                   'Ax1MasErr_min', 'Ax1MasErr_max', 'Ax2MasErr_min', 'Ax2MasErr_max']
    env_params = ['airTemp_zone1', 'matTemp_zone1']
    
    def compare_group(group_name, param_list):
        print(f"\n{group_name}:")
        group_matches = 0
        group_diffs = []
        
        for key in param_list:
            if key in all_keys:
                octave_val = octave_config.get(key, "MISSING")
                python_val = python_config.get(key, "MISSING")
                
                if octave_val == "MISSING":
                    print(f"  ✗ {key:20}: Missing in MATLAB")
                    group_diffs.append(f"{key}: Missing in MATLAB")
                elif python_val == "MISSING":
                    print(f"  ✗ {key:20}: Missing in Python")
                    group_diffs.append(f"{key}: Missing in Python")
                else:
                    # Try numerical comparison first
                    try:
                        oct_num = float(octave_val)
                        py_num = float(python_val)
                        
                        # Check for exact match or very small difference
                        if oct_num == py_num:
                            print(f"  ✓ {key:20}: {octave_val} (exact)")
                            group_matches += 1
                        else:
                            diff = abs(oct_num - py_num)
                            rel_diff = diff / max(abs(oct_num), abs(py_num)) if max(abs(oct_num), abs(py_num)) > 0 else 0
                            
                            if diff < 1e-10 or rel_diff < 1e-10:
                                print(f"  ✓ {key:20}: {octave_val} (tiny diff: {diff:.2e})")
                                group_matches += 1
                            else:
                                print(f"  ✗ {key:20}: MATLAB={octave_val}, Python={python_val} (diff: {diff:.2e})")
                                group_diffs.append(f"{key}: MATLAB={octave_val} vs Python={python_val}")
                    
                    except ValueError:
                        # String comparison
                        if octave_val == python_val:
                            print(f"  ✓ {key:20}: '{octave_val}'")
                            group_matches += 1
                        else:
                            print(f"  ✗ {key:20}: MATLAB='{octave_val}', Python='{python_val}'")
                            group_diffs.append(f"{key}: MATLAB='{octave_val}' vs Python='{python_val}'")
        
        return group_matches, group_diffs
    
    # Compare each group
    sys_matches, sys_diffs = compare_group("SYSTEM PARAMETERS", system_params)
    grid_matches, grid_diffs = compare_group("GRID PARAMETERS", grid_params)  
    data_matches, data_diffs = compare_group("DATA STATISTICS", data_params)
    env_matches, env_diffs = compare_group("ENVIRONMENT DATA", env_params)
    
    # Collect all results
    matches = sys_matches + grid_matches + data_matches + env_matches
    differences = sys_diffs + grid_diffs + data_diffs + env_diffs
    
    # Summary
    total = len(system_params + grid_params + data_params + env_params)
    available_total = len([k for k in system_params + grid_params + data_params + env_params if k in all_keys])
    
    print("\n" + "=" * 60)
    print(f"COMPARISON SUMMARY: {matches}/{available_total} available parameters match")
    
    if differences:
        print(f"\nDIFFERENCES FOUND ({len(differences)}):")
        for diff in differences:
            print(f"  - {diff}")
    
    success = (matches == available_total)
    if success:
        print("\n🎉 PERFECT MATCH! Multi-zone Step 2 implementations are identical.")
    else:
        print(f"\n❌ {len(differences)} differences found. Need investigation.")
    
    # Check for any extra parameters not in our groups
    known_params = set(system_params + grid_params + data_params + env_params)
    extra_params = all_keys - known_params
    if extra_params:
        print(f"\nEXTRA PARAMETERS ({len(extra_params)}):")
        for param in sorted(extra_params):
            oct_val = octave_config.get(param, "MISSING")
            py_val = python_config.get(param, "MISSING")
            if oct_val == py_val:
                print(f"  ✓ {param}: {oct_val}")
                matches += 1
            else:
                print(f"  ✗ {param}: MATLAB={oct_val}, Python={py_val}")
                differences.append(f"{param}: MATLAB={oct_val} vs Python={py_val}")
        total += len(extra_params)
        available_total += len(extra_params)
    
    # Save detailed report
    with open('multizone_step2_comparison_report.txt', 'w') as f:
        f.write("MULTI-ZONE STEP 2 COMPARISON REPORT\n")
        f.write("=" * 40 + "\n\n")
        f.write(f"Result: {matches}/{available_total} parameters match\n\n")
        
        if differences:
            f.write("DIFFERENCES:\n")
            for diff in differences:
                f.write(f"  - {diff}\n")
        else:
            f.write("All parameters match perfectly!\n")
    
    print(f"\nDetailed report saved to: multizone_step2_comparison_report.txt")
    print("=" * 60)
    
    return success


if __name__ == "__main__":
    success = compare_multizone_step2()
    exit(0 if success else 1)
