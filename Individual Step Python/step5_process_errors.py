import numpy as np
import os


def step5_process_errors(grid_data, slope_data):
    """
    STEP5_PROCESS_ERRORS - Remove slopes and calculate vector sum accuracy error
    
    This function removes the calculated straightness slopes from the error data
    and computes the final accuracy errors including vector sum error. This
    isolates the true accuracy errors from systematic straightness errors.
    
    INPUT:
        grid_data - dict from step3_create_grid containing 2D grid data
        slope_data - dict from step4_calculate_slopes containing slope info
    
    OUTPUT:
        processed_data - dict containing final processed accuracy errors
    """
    
    # Initialize output dictionary
    processed_data = {}
    
    # Copy grid position data
    processed_data['X'] = grid_data['X'].copy()
    processed_data['Y'] = grid_data['Y'].copy()
    processed_data['SizeGrid'] = grid_data['SizeGrid']
    
    # Start with the original error data (make copies to avoid modifying originals)
    processed_data['Ax1Err'] = grid_data['Ax1Err'].copy()
    processed_data['Ax2Err'] = grid_data['Ax2Err'].copy()
    
    # Remove best-fit slopes from the error data
    print('Removing straightness slopes from error data...')
    
    # Remove Ax1 slope from all columns
    for i in range(processed_data['SizeGrid'][1]):
        processed_data['Ax1Err'][:, i] = processed_data['Ax1Err'][:, i] - slope_data['Ax1Line']
    
    # Remove Ax2 slope from all rows
    for i in range(processed_data['SizeGrid'][0]):
        processed_data['Ax2Err'][i, :] = processed_data['Ax2Err'][i, :] - slope_data['Ax2Line']
    
    # Subtract error at origin to set reference point to zero
    processed_data['Ax1Err'] = processed_data['Ax1Err'] - processed_data['Ax1Err'][0, 0]
    processed_data['Ax2Err'] = processed_data['Ax2Err'] - processed_data['Ax2Err'][0, 0]
    
    # Calculate vector sum accuracy error
    print('Calculating vector sum accuracy error...')
    processed_data['VectorErr'] = np.sqrt(processed_data['Ax1Err']**2 + processed_data['Ax2Err']**2)
    
    # Calculate peak-to-peak accuracy values
    processed_data['pkAx1'] = np.max(processed_data['Ax1Err']) - np.min(processed_data['Ax1Err'])
    processed_data['pkAx2'] = np.max(processed_data['Ax2Err']) - np.min(processed_data['Ax2Err'])
    processed_data['maxVectorErr'] = np.max(processed_data['VectorErr'])
    
    # Calculate RMS accuracy values
    processed_data['rmsAx1'] = np.std(processed_data['Ax1Err'], ddof=1)
    processed_data['rmsAx2'] = np.std(processed_data['Ax2Err'], ddof=1)
    processed_data['rmsVector'] = np.std(processed_data['VectorErr'], ddof=1)
    
    # Calculate accuracy amplitudes (half of peak-to-peak)
    processed_data['Ax1amplitude'] = processed_data['pkAx1'] / 2
    processed_data['Ax2amplitude'] = processed_data['pkAx2'] / 2
    
    # Store slope data for reference
    processed_data['slope_data'] = slope_data.copy()
    
    # Display error processing results
    print('\n=== ERROR PROCESSING RESULTS ===')
    print('After slope removal:')
    print(f"  Ax1 error range: [{np.min(processed_data['Ax1Err']):.3f}, {np.max(processed_data['Ax1Err']):.3f}] um")
    print(f"  Ax2 error range: [{np.min(processed_data['Ax2Err']):.3f}, {np.max(processed_data['Ax2Err']):.3f}] um")
    print(f"  Vector error range: [{np.min(processed_data['VectorErr']):.3f}, {np.max(processed_data['VectorErr']):.3f}] um")
    print('\nAccuracy Performance Summary:')
    print(f"  Ax1 Peak-to-Peak: {processed_data['pkAx1']:.3f} um (±{processed_data['Ax1amplitude']:.3f} um)")
    print(f"  Ax2 Peak-to-Peak: {processed_data['pkAx2']:.3f} um (±{processed_data['Ax2amplitude']:.3f} um)")
    print(f"  Max Vector Error: {processed_data['maxVectorErr']:.3f} um")
    print(f"  Ax1 RMS: {processed_data['rmsAx1']:.3f} um")
    print(f"  Ax2 RMS: {processed_data['rmsAx2']:.3f} um")
    print(f"  Vector RMS: {processed_data['rmsVector']:.3f} um")
    print(f"  Orthogonality: {slope_data['orthog']:.3f} arc-seconds")
    print('=================================\n')
    
    return processed_data


if __name__ == "__main__":
    # Test the function if run directly
    from step1_parse_header import step1_parse_header
    from step2_load_data import step2_load_data
    from step3_create_grid import step3_create_grid
    from step4_calculate_slopes import step4_calculate_slopes
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
        
        # Step 4: Calculate slopes
        print("Step 4: Calculating slopes...")
        slope_data = step4_calculate_slopes(grid_data)
        
        # Step 5: Process errors
        print("Step 5: Processing errors...")
        processed_data = step5_process_errors(grid_data, slope_data)
        
        print("=== COMPLETE PIPELINE TEST SUCCESSFUL ===")
        print("All processed data saved for comparison")
        
        # Save the result for comparison with MATLAB/Octave
        sio.savemat('step5_output_python.mat', {
            'processed_data': processed_data,
            'slope_data': slope_data,
            'grid_data': grid_data,
            'data_raw': data_raw, 
            'config': config
        })
        
    except Exception as err:
        print('ERROR in step5_process_errors:')
        print(str(err))
        import traceback
        traceback.print_exc()
