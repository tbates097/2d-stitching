import numpy as np
from scipy.interpolate import griddata
import os


def step3_create_grid(data_raw):
    """
    STEP3_CREATE_GRID - Create 2D position and error matrices using griddata interpolation
    
    This function takes the raw measurement data and interpolates it onto a regular
    2D grid using scipy's griddata function, creating the position matrices X, Y
    and error matrices Ax1Err, Ax2Err
    
    INPUT:
        data_raw - dict from step2_load_data containing raw measurement data
    
    OUTPUT:
        grid_data - dict containing 2D grid matrices
    """
    
    # Initialize output dictionary
    grid_data = {}
    
    # Create 2D position matrices using meshgrid
    X, Y = np.meshgrid(data_raw['Ax1Pos'], data_raw['Ax2Pos'])
    grid_data['X'] = X
    grid_data['Y'] = Y
    grid_data['SizeGrid'] = X.shape
    
    # Normalize position vectors for griddata interpolation
    # This helps with numerical stability when using griddata
    # Changed to max-min to fix bug where all negative travel led to divide by zero
    maxAx1 = np.max(data_raw['Ax1PosCmd']) - np.min(data_raw['Ax1PosCmd'])
    maxAx2 = np.max(data_raw['Ax2PosCmd']) - np.min(data_raw['Ax2PosCmd'])
    
    # Handle case where there's no movement (single point)
    if maxAx1 == 0:
        maxAx1 = 1.0
    if maxAx2 == 0:
        maxAx2 = 1.0
    
    # Prepare normalized coordinates for interpolation
    points = np.column_stack((data_raw['Ax1PosCmd'] / maxAx1, data_raw['Ax2PosCmd'] / maxAx2))
    xi = np.column_stack((X.flatten() / maxAx1, Y.flatten() / maxAx2))
    
    # Interpolate error data onto regular grid using griddata
    print('Interpolating Axis 1 error data onto regular grid...')
    ax1_err_flat = griddata(points, data_raw['Ax1RelErr_um'], xi, method='linear')
    grid_data['Ax1Err'] = ax1_err_flat.reshape(X.shape)
    
    print('Interpolating Axis 2 error data onto regular grid...')
    ax2_err_flat = griddata(points, data_raw['Ax2RelErr_um'], xi, method='linear')
    grid_data['Ax2Err'] = ax2_err_flat.reshape(X.shape)
    
    # Store normalization factors for reference
    grid_data['maxAx1'] = maxAx1
    grid_data['maxAx2'] = maxAx2
    
    # Check for NaN values in interpolated data
    nan_count_ax1 = np.sum(np.isnan(grid_data['Ax1Err']))
    nan_count_ax2 = np.sum(np.isnan(grid_data['Ax2Err']))
    
    # Display grid information
    print('\n=== GRID DATA SUMMARY ===')
    print(f"Grid size: {grid_data['SizeGrid'][0]} x {grid_data['SizeGrid'][1]}")
    print(f"X range: [{np.min(X):.3f}, {np.max(X):.3f}] mm")
    print(f"Y range: [{np.min(Y):.3f}, {np.max(Y):.3f}] mm")
    print(f"Ax1 error range: [{np.nanmin(grid_data['Ax1Err']):.3f}, {np.nanmax(grid_data['Ax1Err']):.3f}] um")
    print(f"Ax2 error range: [{np.nanmin(grid_data['Ax2Err']):.3f}, {np.nanmax(grid_data['Ax2Err']):.3f}] um")
    print(f"NaN values - Ax1: {nan_count_ax1}, Ax2: {nan_count_ax2}")
    
    if nan_count_ax1 > 0 or nan_count_ax2 > 0:
        print('WARNING: NaN values detected in interpolated data!')
    else:
        print('Interpolation completed successfully - no NaN values')
    print('=========================\n')
    
    return grid_data


if __name__ == "__main__":
    # Test the function if run directly
    from step1_parse_header import step1_parse_header
    from step2_load_data import step2_load_data
    import scipy.io as sio
    
    test_file = 'MATLAB Source/642583-1-1-CZ1.dat'
    
    if not os.path.exists(test_file):
        print(f"Test file {test_file} not found!")
        exit(1)
    
    try:
        # Step 1: Get the configuration
        print("Step 1: Loading configuration...")
        config = step1_parse_header(test_file)
        
        # Step 2: Load the raw data
        print("Step 2: Loading raw data...")
        data_raw = step2_load_data(test_file, config)
        
        # Step 3: Create the grid
        print("Step 3: Creating 2D grid...")
        grid_data = step3_create_grid(data_raw)
        
        print("=== TEST COMPLETED SUCCESSFULLY ===")
        print("Grid data structure saved for comparison")
        
        # Save the result for comparison with MATLAB/Octave
        sio.savemat('step3_output_python.mat', {
            'grid_data': grid_data, 
            'data_raw': data_raw, 
            'config': config
        })
        
    except Exception as err:
        print('ERROR in step3_create_grid:')
        print(str(err))
        import traceback
        traceback.print_exc()
