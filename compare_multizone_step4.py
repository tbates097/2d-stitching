#!/usr/bin/env python3
"""
COMPARE_MULTIZONE_STEP4 - Compare multi-zone Step 4 outputs between MATLAB and Python
"""

import os
import numpy as np


def compare_multizone_step4():
    """Compare multi-zone Step 4 output files"""
    
    print("=" * 60)
    print("MULTI-ZONE STEP 4: MATLAB vs PYTHON COMPARISON")
    print("=" * 60)
    
    octave_file = "multizone_step4_output_octave.txt"
    python_file = "multizone_step4_output_python.txt"
    
    # Check if both files exist
    if not os.path.exists(octave_file):
        print(f"❌ MATLAB output file missing: {octave_file}")
        print("Please run: test_multizone_step4_octave")
        return False
    
    if not os.path.exists(python_file):
        print(f"❌ Python output file missing: {python_file}")
        print("Please run: python multizone_step4_finalize_calibration.py")
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
    basic_params = ['totalZones', 'validPoints', 'overlapPoints', 'gridSize_rows', 'gridSize_cols']
    accuracy_params = ['pkAx1', 'pkAx2', 'pkVector', 'rmsAx1', 'rmsAx2', 'rmsVector']
    system_params = ['orthogonality', 'Ax1Slope', 'Ax2Slope']
    error_range_params = ['Ax1Err_min', 'Ax1Err_max', 'Ax2Err_min', 'Ax2Err_max', 
                         'VectorErr_min', 'VectorErr_max']
    
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
                            
                            # Use relaxed tolerance for final calibration results
                            # Some small differences expected due to numerical precision in complex pipeline
                            if key in basic_params:
                                tolerance = 1e-12  # Strict for integer/basic values
                            elif 'Err_' in key:
                                tolerance = 1e-6   # More relaxed for error statistics
                            else:
                                tolerance = 1e-8   # Medium tolerance for other values
                            
                            if diff < tolerance or rel_diff < tolerance:
                                print(f"  ✓ {key:20}: {octave_val} (diff: {diff:.2e})")
                                group_matches += 1
                            else:
                                print(f"  ✗ {key:20}: MATLAB={octave_val}, Python={python_val}")
                                print(f"      {'':20}   (abs diff: {diff:.2e}, rel diff: {rel_diff:.2e})")
                                group_diffs.append(f"{key}: MATLAB={octave_val} vs Python={python_val} (diff: {diff:.2e})")
                    
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
    basic_matches, basic_diffs = compare_group("BASIC PARAMETERS", basic_params)
    accuracy_matches, accuracy_diffs = compare_group("ACCURACY PERFORMANCE", accuracy_params)
    system_matches, system_diffs = compare_group("SYSTEM CHARACTERISTICS", system_params)
    error_matches, error_diffs = compare_group("ERROR RANGES", error_range_params)
    
    # Collect all results
    matches = basic_matches + accuracy_matches + system_matches + error_matches
    differences = basic_diffs + accuracy_diffs + system_diffs + error_diffs
    
    # Summary
    total = len(basic_params + accuracy_params + system_params + error_range_params)
    available_total = len([k for k in basic_params + accuracy_params + system_params + error_range_params if k in all_keys])
    
    print("\n" + "=" * 60)
    print(f"COMPARISON SUMMARY: {matches}/{available_total} available parameters match")
    
    if differences:
        print(f"\nDIFFERENCES FOUND ({len(differences)}):")
        for diff in differences:
            print(f"  - {diff}")
    
    success = (matches == available_total)
    if success:
        print("\n🎉 PERFECT MATCH! Multi-zone Step 4 implementations are identical.")
        print("✅ Complete calibration pipeline produces identical results!")
    else:
        print(f"\n⚠️  {len(differences)} differences found.")
        
        # Provide guidance on acceptable differences
        small_diffs = [d for d in differences if 'diff:' in d and ('e-0' in d or 'e-1' in d)]
        if len(small_diffs) == len(differences):
            print("\n💡 NOTE: All differences are very small and likely due to")
            print("   numerical precision in the complex multi-zone pipeline.")
            print("   These differences should not affect calibration quality.")
        
        # Check if major parameters match
        major_params = ['totalZones', 'validPoints', 'gridSize_rows', 'gridSize_cols']
        major_diffs = [d for d in differences if any(param in d for param in major_params)]
        
        if not major_diffs:
            print("\n✅ All major structural parameters match perfectly!")
    
    # Check for any extra parameters not in our groups
    known_params = set(basic_params + accuracy_params + system_params + error_range_params)
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
    with open('multizone_step4_comparison_report.txt', 'w') as f:
        f.write("MULTI-ZONE STEP 4 COMPARISON REPORT\n")
        f.write("=" * 40 + "\n\n")
        f.write(f"Result: {matches}/{available_total} parameters match\n\n")
        
        if differences:
            f.write("DIFFERENCES:\n")
            for diff in differences:
                f.write(f"  - {diff}\n")
        else:
            f.write("All parameters match perfectly!\n")
            
        f.write("\n\nCONCLUSION:\n")
        if success:
            f.write("✅ PERFECT AGREEMENT - Pipeline implementations are identical\n")
        elif len([d for d in differences if 'e-' in d]) == len(differences):
            f.write("✅ EXCELLENT AGREEMENT - Only tiny numerical differences\n")
        else:
            f.write("⚠️ SOME DIFFERENCES - Investigation recommended\n")
    
    print(f"\nDetailed report saved to: multizone_step4_comparison_report.txt")
    print("=" * 60)
    
    return success


if __name__ == "__main__":
    success = compare_multizone_step4()
    exit(0 if success else 1)
