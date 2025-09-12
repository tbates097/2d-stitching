import os
import numpy as np


def multizone_step1_setup(num_row, num_col, travel_ax1, travel_ax2, zone_filenames):
    """
    MULTIZONE_STEP1_SETUP - Setup configuration for multi-zone stitching
    
    This function initializes the configuration parameters needed for 
    multi-zone stitching including zone layout, travel ranges, and filenames
    
    INPUT:
        num_row - number of calibration zone rows (zones in Axis 2 direction)
        num_col - number of calibration zone columns (zones in Axis 1 direction)
        travel_ax1 - [min, max] full calibrated travel for Axis 1 (scan axis)
        travel_ax2 - [min, max] full calibrated travel for Axis 2 (step axis)
        zone_filenames - 2D list of filenames, size [num_row][num_col]
    
    OUTPUT:
        setup - dict containing all configuration parameters
    """
    
    # Initialize output dictionary
    setup = {}
    
    # Validate inputs
    if num_row < 1 or num_col < 1:
        raise ValueError('Number of rows and columns must be >= 1')
    
    if len(travel_ax1) != 2 or len(travel_ax2) != 2:
        raise ValueError('Travel ranges must be [min, max] lists/arrays')
    
    if travel_ax1[1] <= travel_ax1[0] or travel_ax2[1] <= travel_ax2[0]:
        raise ValueError('Travel max must be greater than travel min')
    
    if not isinstance(zone_filenames, list) or len(zone_filenames) != num_row:
        raise ValueError('zone_filenames must be a 2D list of size [num_row][num_col]')
    
    for row in zone_filenames:
        if not isinstance(row, list) or len(row) != num_col:
            raise ValueError('Each row in zone_filenames must have num_col elements')
    
    # Store basic configuration
    setup['numRow'] = num_row
    setup['numCol'] = num_col
    setup['travelAx1'] = travel_ax1
    setup['travelAx2'] = travel_ax2
    setup['zone_filenames'] = zone_filenames
    
    # Calculate total travel distances
    setup['totalTravelAx1'] = travel_ax1[1] - travel_ax1[0]
    setup['totalTravelAx2'] = travel_ax2[1] - travel_ax2[0]
    
    # Set measurement direction factor (from original code)
    setup['y_meas_dir'] = -1  # slope opposite sign between axes
    
    # Initialize zone counter
    setup['zoneCount'] = 0
    
    # Validate that all zone files exist
    print('Validating zone files...')
    for i in range(num_row):
        for j in range(num_col):
            filename = zone_filenames[i][j]
            if not os.path.exists(filename):
                raise FileNotFoundError(f'Zone file not found: {filename} (Row {i+1}, Col {j+1})')
            print(f'  ✓ Row {i+1}, Col {j+1}: {filename}')
    
    # Store calibration file options (from original)
    setup['WriteCalFile'] = 1      # 1 = write cal file
    setup['OutAxis3'] = 0          # 0 = no gantry slave
    setup['OutAx3Value'] = 2       # master axis of gantry
    setup['CalFile'] = 'stitched_multizone.cal'
    setup['UserUnit'] = 'ENGLISH'  # 'METRIC' or 'ENGLISH'
    setup['writeOutputFile'] = 1
    setup['OutFile'] = 'stitched_multizone_accuracy.dat'
    
    # Initialize arrays for environmental data tracking
    setup['airTemp'] = np.zeros(num_row * num_col)
    setup['matTemp'] = np.zeros(num_row * num_col)
    setup['comment'] = [''] * (num_row * num_col)  # Use empty strings instead of None
    setup['fileDate'] = [''] * (num_row * num_col)  # Use empty strings instead of None
    
    # Display setup summary
    print('\n=== MULTI-ZONE SETUP SUMMARY ===')
    print(f"Zone layout: {num_row} rows × {num_col} columns = {num_row * num_col} total zones")
    print(f"Axis 1 travel: [{travel_ax1[0]:.3f}, {travel_ax1[1]:.3f}] ({setup['totalTravelAx1']:.3f} total)")
    print(f"Axis 2 travel: [{travel_ax2[0]:.3f}, {travel_ax2[1]:.3f}] ({setup['totalTravelAx2']:.3f} total)")
    print(f"Calibration file: {setup['CalFile']}")
    print(f"Output file: {setup['OutFile']}")
    print('=================================\n')
    
    return setup


if __name__ == "__main__":
    # Test the function with example data
    
    # Example configuration using all 4 available zones (2x2 grid)
    num_row = 2
    num_col = 2  
    travel_ax1 = [-200/25.4, 200/25.4]  # Convert from mm to inches
    travel_ax2 = [-75/25.4, 75/25.4]
    
    # Zone filenames - using all available test files in a 2x2 layout
    zone_filenames = [
        ['MATLAB Source/642583-1-1-CZ1.dat', 'MATLAB Source/642583-1-1-CZ2.dat'],  # Row 1
        ['MATLAB Source/642583-1-1-CZ3.dat', 'MATLAB Source/642583-1-1-CZ4.dat']   # Row 2
    ]
    
    try:
        setup = multizone_step1_setup(num_row, num_col, travel_ax1, travel_ax2, zone_filenames)
        
        # Save setup results to text file for comparison
        with open('multizone_step1_output_python.txt', 'w') as f:
            f.write('=== MULTIZONE STEP 1: SETUP CONFIGURATION ===\n')
            f.write(f"numRow: {setup['numRow']}\n")
            f.write(f"numCol: {setup['numCol']}\n")
            f.write(f"travelAx1_min: {setup['travelAx1'][0]:.6f}\n")
            f.write(f"travelAx1_max: {setup['travelAx1'][1]:.6f}\n")
            f.write(f"travelAx2_min: {setup['travelAx2'][0]:.6f}\n")
            f.write(f"travelAx2_max: {setup['travelAx2'][1]:.6f}\n")
            f.write(f"totalTravelAx1: {setup['totalTravelAx1']:.6f}\n")
            f.write(f"totalTravelAx2: {setup['totalTravelAx2']:.6f}\n")
            f.write(f"y_meas_dir: {setup['y_meas_dir']}\n")
            f.write(f"zoneCount: {setup['zoneCount']}\n")
            f.write(f"WriteCalFile: {setup['WriteCalFile']}\n")
            f.write(f"OutAxis3: {setup['OutAxis3']}\n")
            f.write(f"OutAx3Value: {setup['OutAx3Value']}\n")
            f.write(f"CalFile: {setup['CalFile']}\n")
            f.write(f"UserUnit: {setup['UserUnit']}\n")
            f.write(f"writeOutputFile: {setup['writeOutputFile']}\n")
            f.write(f"OutFile: {setup['OutFile']}\n")
            f.write(f"zone_filename_1_1: {setup['zone_filenames'][0][0]}\n")
            f.write(f"zone_filename_1_2: {setup['zone_filenames'][0][1]}\n")
            f.write(f"zone_filename_2_1: {setup['zone_filenames'][1][0]}\n")
            f.write(f"zone_filename_2_2: {setup['zone_filenames'][1][1]}\n")
            f.write(f"airTemp_length: {len(setup['airTemp'])}\n")
            f.write(f"matTemp_length: {len(setup['matTemp'])}\n")
            f.write(f"comment_length: {len(setup['comment'])}\n")
            f.write(f"fileDate_length: {len(setup['fileDate'])}\n")
        
        print("=== TEST COMPLETED SUCCESSFULLY ===")
        print("Setup configuration created and validated")
        print("Results saved to: multizone_step1_output_python.txt")
        
        # Save for comparison with MATLAB
        import scipy.io as sio
        sio.savemat('multizone_step1_output_python.mat', {'setup': setup})
        
    except Exception as err:
        print('ERROR in multizone_step1_setup:')
        print(str(err))
        import traceback
        traceback.print_exc()
