#!/usr/bin/env python3
"""
COMPARE_MULTIZONE_STEP1 - Compare multi-zone Step 1 outputs between MATLAB and Python
"""

import os


def compare_multizone_step1():
    """Compare multi-zone Step 1 output files"""
    
    print("=" * 60)
    print("MULTI-ZONE STEP 1: MATLAB vs PYTHON COMPARISON")
    print("=" * 60)
    
    octave_file = "multizone_step1_output_octave.txt"
    python_file = "multizone_step1_output_python.txt"
    
    # Check if both files exist
    if not os.path.exists(octave_file):
        print(f"❌ MATLAB output file missing: {octave_file}")
        print("Please run: test_multizone_step1_octave")
        return False
    
    if not os.path.exists(python_file):
        print(f"❌ Python output file missing: {python_file}")
        print("Please run: python multizone_step1_setup.py")
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
    
    print(f"\nFound {len(all_keys)} configuration parameters to compare\n")
    
    matches = 0
    differences = []
    
    for key in sorted(all_keys):
        octave_val = octave_config.get(key, "MISSING")
        python_val = python_config.get(key, "MISSING")
        
        if octave_val == "MISSING":
            print(f"✗ {key:25}: Missing in MATLAB")
            differences.append(f"{key}: Missing in MATLAB")
        elif python_val == "MISSING":
            print(f"✗ {key:25}: Missing in Python")
            differences.append(f"{key}: Missing in Python")
        else:
            # Try numerical comparison first
            try:
                oct_num = float(octave_val)
                py_num = float(python_val)
                
                # Check for exact match or very small difference
                if oct_num == py_num:
                    print(f"✓ {key:25}: {octave_val} (exact match)")
                    matches += 1
                else:
                    diff = abs(oct_num - py_num)
                    rel_diff = diff / max(abs(oct_num), abs(py_num)) if max(abs(oct_num), abs(py_num)) > 0 else 0
                    
                    if diff < 1e-10 or rel_diff < 1e-10:
                        print(f"✓ {key:25}: {octave_val} (tiny diff: {diff:.2e})")
                        matches += 1
                    else:
                        print(f"✗ {key:25}: MATLAB={octave_val}, Python={python_val} (diff: {diff:.2e})")
                        differences.append(f"{key}: MATLAB={octave_val} vs Python={python_val}")
            
            except ValueError:
                # String comparison
                if octave_val == python_val:
                    print(f"✓ {key:25}: '{octave_val}' (string match)")
                    matches += 1
                else:
                    print(f"✗ {key:25}: MATLAB='{octave_val}', Python='{python_val}'")
                    differences.append(f"{key}: MATLAB='{octave_val}' vs Python='{python_val}'")
    
    # Summary
    total = len(all_keys)
    print("\n" + "=" * 60)
    print(f"COMPARISON SUMMARY: {matches}/{total} parameters match")
    
    if differences:
        print(f"\nDIFFERENCES FOUND ({len(differences)}):")
        for diff in differences:
            print(f"  - {diff}")
    
    success = (matches == total)
    if success:
        print("\n🎉 PERFECT MATCH! Multi-zone Step 1 implementations are identical.")
    else:
        print(f"\n❌ {len(differences)} differences found. Need investigation.")
    
    # Save detailed report
    with open('multizone_step1_comparison_report.txt', 'w') as f:
        f.write("MULTI-ZONE STEP 1 COMPARISON REPORT\n")
        f.write("=" * 40 + "\n\n")
        f.write(f"Result: {matches}/{total} parameters match\n\n")
        
        if differences:
            f.write("DIFFERENCES:\n")
            for diff in differences:
                f.write(f"  - {diff}\n")
        else:
            f.write("All parameters match perfectly!\n")
    
    print(f"\nDetailed report saved to: multizone_step1_comparison_report.txt")
    print("=" * 60)
    
    return success


if __name__ == "__main__":
    success = compare_multizone_step1()
    exit(0 if success else 1)
