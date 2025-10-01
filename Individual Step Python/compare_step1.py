#!/usr/bin/env python3
"""
COMPARE_STEP1 - Compare outputs between Octave and Python header parsers
"""

import subprocess
import os
import scipy.io as sio
from step1_parse_header import step1_parse_header
import numpy as np

def run_octave_test():
    """Run the Octave test and load the results"""
    print("Running Octave test...")
    
    # Run Octave test
    try:
        result = subprocess.run(['octave', '--no-gui', '--eval', 'test_step1_octave'], 
                              capture_output=True, text=True, cwd='.')
        print("Octave output:")
        print(result.stdout)
        if result.stderr:
            print("Octave errors:")
            print(result.stderr)
    except FileNotFoundError:
        print("Octave not found. Trying with 'octave-cli'...")
        try:
            result = subprocess.run(['octave-cli', '--eval', 'test_step1_octave'], 
                                  capture_output=True, text=True, cwd='.')
            print("Octave output:")
            print(result.stdout)
            if result.stderr:
                print("Octave errors:")
                print(result.stderr)
        except FileNotFoundError:
            print("Neither 'octave' nor 'octave-cli' found. Please install GNU Octave.")
            return None
    
    # Load Octave results
    if os.path.exists('step1_output.mat'):
        octave_data = sio.loadmat('step1_output.mat')
        return octave_data['config_step1']
    else:
        print("Octave output file not found!")
        return None

def run_python_test():
    """Run the Python test and return the results"""
    print("\nRunning Python test...")
    
    test_file = 'MATLAB Source/642583-1-1-CZ1.dat'
    
    if not os.path.exists(test_file):
        print(f"Test file {test_file} not found!")
        return None
    
    try:
        config = step1_parse_header(test_file)
        return config
    except Exception as err:
        print(f"Error in Python parser: {err}")
        return None

def compare_configs(octave_config, python_config):
    """Compare the two configuration dictionaries"""
    print("\n" + "="*50)
    print("COMPARISON RESULTS")
    print("="*50)
    
    if octave_config is None or python_config is None:
        print("Cannot compare - one or both parsers failed")
        return False
    
    # Handle Octave struct array format
    if isinstance(octave_config, np.ndarray) and octave_config.size == 1:
        octave_config = octave_config.item()
    
    # Get all field names
    if hasattr(octave_config, 'dtype'):
        octave_fields = set(octave_config.dtype.names)
    else:
        octave_fields = set(octave_config.keys()) if isinstance(octave_config, dict) else set()
    
    python_fields = set(python_config.keys())
    all_fields = octave_fields.union(python_fields)
    
    matches = 0
    total = 0
    differences = []
    
    for field in sorted(all_fields):
        total += 1
        
        # Get values from both configs
        octave_val = None
        python_val = None
        
        if field in octave_fields:
            if hasattr(octave_config, 'dtype'):
                octave_val = octave_config[field]
                if isinstance(octave_val, np.ndarray):
                    if octave_val.size == 1:
                        octave_val = octave_val.item()
                    elif octave_val.dtype.char == 'U':  # Unicode string
                        octave_val = str(octave_val.item())
                    else:
                        octave_val = octave_val.tolist()
            else:
                octave_val = octave_config[field]
        
        if field in python_fields:
            python_val = python_config[field]
        
        # Compare values
        if octave_val is None and python_val is None:
            print(f"✓ {field:15}: Both None")
            matches += 1
        elif octave_val is None:
            print(f"✗ {field:15}: Octave=None, Python={repr(python_val)}")
            differences.append((field, octave_val, python_val))
        elif python_val is None:
            print(f"✗ {field:15}: Octave={repr(octave_val)}, Python=None")
            differences.append((field, octave_val, python_val))
        else:
            # Handle string comparison
            octave_str = str(octave_val).strip()
            python_str = str(python_val).strip()
            
            if octave_str == python_str:
                print(f"✓ {field:15}: {repr(octave_str)}")
                matches += 1
            else:
                print(f"✗ {field:15}: Octave={repr(octave_str)}, Python={repr(python_str)}")
                differences.append((field, octave_val, python_val))
    
    print("\n" + "="*50)
    print(f"SUMMARY: {matches}/{total} fields match")
    
    if differences:
        print(f"\nDIFFERENCES ({len(differences)}):")
        for field, octave_val, python_val in differences:
            print(f"  {field}: Octave={repr(octave_val)} vs Python={repr(python_val)}")
    
    success = (matches == total)
    if success:
        print("\n🎉 PERFECT MATCH! Both parsers produce identical results.")
    else:
        print(f"\n❌ {total - matches} differences found. Need to fix the parsers.")
    
    return success

def main():
    print("Step 1 Comparison: Header Parser")
    print("="*40)
    
    # Run both tests
    octave_config = run_octave_test()
    python_config = run_python_test()
    
    # Compare results
    success = compare_configs(octave_config, python_config)
    
    return success

if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)
