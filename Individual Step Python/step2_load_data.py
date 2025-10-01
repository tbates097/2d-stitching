import numpy as np
import pandas as pd
import os


def step2_load_data(input_file, config):
    """
    STEP2_LOAD_DATA - Load and sort raw measurement data from file
    
    This function loads the numerical data from the measurement file and
    sorts it by step position (Axis 2) then scan position (Axis 1)
    
    INPUT:
        input_file - str, path to the data file
        config - dict from step1_parse_header containing configuration
    
    OUTPUT:
        data_raw - dict containing raw measurement data
    """
    
    # Initialize output dictionary
    data_raw = {}
    
    # Load numerical data from file (skip header lines)
    # Find where the numerical data starts (after the header)
    with open(input_file, 'r') as f:
        lines = f.readlines()
    
    # Find the start of numerical data (first line that starts with a number)
    data_start = 0
    for i, line in enumerate(lines):
        line = line.strip()
        if line and not line.startswith('%') and not line.startswith('#'):
            try:
                # Try to parse as numbers
                float(line.split()[0])
                data_start = i
                break
            except (ValueError, IndexError):
                continue
    
    # Load data using numpy
    s = np.loadtxt(input_file, skiprows=data_start)
    
    # Sort data for ascending step and scan positions
    # Column 1: Ax1TestLoc, Column 2: Ax2TestLoc  
    # Sort by column 1 (Ax2TestLoc) first, then column 0 (Ax1TestLoc)
    sort_indices = np.lexsort((s[:, 0], s[:, 1]))
    s = s[sort_indices]
    
    # Extract data columns
    data_raw['Ax1TestLoc'] = s[:, 0].astype(int)      # Axis 1 test location (incremental counter)
    data_raw['Ax2TestLoc'] = s[:, 1].astype(int)      # Axis 2 test location (incremental counter)
    data_raw['Ax1PosCmd'] = s[:, 2] / config['calDivisor']  # Commanded position (converted to mm)
    data_raw['Ax2PosCmd'] = s[:, 3] / config['calDivisor']  # Commanded position (converted to mm) 
    data_raw['Ax1RelErr'] = s[:, 4] / config['calDivisor']  # Raw relative error (converted to mm)
    data_raw['Ax2RelErr'] = s[:, 5] / config['calDivisor']  # Raw relative error (converted to mm)
    
    # Calculate processed relative error (convert to microns, subtract mean)
    data_raw['Ax1RelErr_um'] = (data_raw['Ax1RelErr'] - np.mean(data_raw['Ax1RelErr'])) * 1000
    data_raw['Ax2RelErr_um'] = (data_raw['Ax2RelErr'] - np.mean(data_raw['Ax2RelErr'])) * 1000
    
    # Calculate measurement parameters
    data_raw['NumAx1Points'] = int(np.max(data_raw['Ax1TestLoc']))
    data_raw['NumAx2Points'] = int(np.max(data_raw['Ax2TestLoc']))
    data_raw['Ax1MoveDist'] = np.max(data_raw['Ax1PosCmd']) - np.min(data_raw['Ax1PosCmd'])
    data_raw['Ax2MoveDist'] = np.max(data_raw['Ax2PosCmd']) - np.min(data_raw['Ax2PosCmd'])
    
    # Calculate sampling distances
    if data_raw['NumAx1Points'] > 1:
        data_raw['Ax1SampDist'] = data_raw['Ax1PosCmd'][1] - data_raw['Ax1PosCmd'][0]
    else:
        data_raw['Ax1SampDist'] = 0.0
    
    if data_raw['NumAx2Points'] > 1:
        data_raw['Ax2SampDist'] = data_raw['Ax2PosCmd'][data_raw['NumAx1Points']] - data_raw['Ax2PosCmd'][0]
    else:
        data_raw['Ax2SampDist'] = 0.0
    
    # Create position vectors
    data_raw['Ax1Pos'] = data_raw['Ax1PosCmd'][:data_raw['NumAx1Points']]
    data_raw['Ax2Pos'] = data_raw['Ax2PosCmd'][::data_raw['NumAx1Points']][:data_raw['NumAx2Points']]
    
    # Display summary information
    print('\n=== RAW DATA SUMMARY ===')
    print(f"Data points: {data_raw['NumAx1Points']} x {data_raw['NumAx2Points']} = "
          f"{data_raw['NumAx1Points'] * data_raw['NumAx2Points']} total")
    print(f"Axis 1 travel: {data_raw['Ax1MoveDist']:.3f} mm (sampling: {data_raw['Ax1SampDist']:.3f} mm)")
    print(f"Axis 2 travel: {data_raw['Ax2MoveDist']:.3f} mm (sampling: {data_raw['Ax2SampDist']:.3f} mm)")
    print(f"Axis 1 range: [{np.min(data_raw['Ax1Pos']):.3f}, {np.max(data_raw['Ax1Pos']):.3f}] mm")
    print(f"Axis 2 range: [{np.min(data_raw['Ax2Pos']):.3f}, {np.max(data_raw['Ax2Pos']):.3f}] mm")
    print(f"Raw error range Ax1: [{np.min(data_raw['Ax1RelErr_um']):.3f}, {np.max(data_raw['Ax1RelErr_um']):.3f}] um")
    print(f"Raw error range Ax2: [{np.min(data_raw['Ax2RelErr_um']):.3f}, {np.max(data_raw['Ax2RelErr_um']):.3f}] um")
    print('========================\n')
    
    return data_raw


if __name__ == "__main__":
    # Test the function if run directly
    from step1_parse_header import step1_parse_header
    import scipy.io as sio
    
    test_file = 'MATLAB Source/642583-1-1-CZ1.dat'
    
    if not os.path.exists(test_file):
        print(f"Test file {test_file} not found!")
        exit(1)
    
    try:
        # First get the configuration
        print("Step 1: Loading configuration...")
        config = step1_parse_header(test_file)
        
        # Then load the data
        print("Step 2: Loading raw data...")
        data_raw = step2_load_data(test_file, config)
        
        print("=== TEST COMPLETED SUCCESSFULLY ===")
        print("Raw data structure saved for comparison")
        
        # Save the result for comparison with MATLAB/Octave
        sio.savemat('step2_output_python.mat', {'data_raw': data_raw, 'config': config})
        
    except Exception as err:
        print('ERROR in step2_load_data:')
        print(str(err))
