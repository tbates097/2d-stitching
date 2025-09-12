import numpy as np
import os


def step4_calculate_slopes(grid_data):
    """
    STEP4_CALCULATE_SLOPES - Calculate straightness slopes and orthogonality
    
    This function calculates the best-fit slopes for straightness errors in both
    axes and computes the orthogonality between the axes. These slopes will be
    removed later to isolate the accuracy errors.
    
    INPUT:
        grid_data - dict from step3_create_grid containing 2D grid data
    
    OUTPUT:
        slope_data - dict containing slope coefficients and orthogonality
    """
    
    # Initialize output dictionary
    slope_data = {}
    
    # Mirror misalignment factor - slope is always opposite sign between axes
    # when laser and encoder read positive in the same direction
    y_meas_dir = -1
    
    # Calculate mean straightness errors along each axis
    # Ax1 straightness: average error in Ax1 direction vs Ax2 position
    mean_ax1_err = np.mean(grid_data['Ax1Err'], axis=1)  # Average across rows (Ax1 direction)
    mean_ax2_err = np.mean(grid_data['Ax2Err'], axis=0)  # Average across columns (Ax2 direction)
    
    # Fit linear slopes to the mean straightness errors
    # Ax1Coef: slope of Ax1 error vs Ax2 position (units: microns/mm)
    slope_data['Ax1Coef'] = np.polyfit(grid_data['Y'][:, 0], mean_ax1_err, 1)
    
    # Ax2Coef: slope of Ax2 error vs Ax1 position (units: microns/mm)
    slope_data['Ax2Coef'] = np.polyfit(grid_data['X'][0, :], mean_ax2_err, 1)
    
    # Create best-fit lines for slope removal
    slope_data['Ax1Line'] = np.polyval(slope_data['Ax1Coef'], grid_data['Y'][:, 0])
    slope_data['Ax2Line'] = np.polyval(y_meas_dir * slope_data['Ax1Coef'], grid_data['X'][0, :])
    
    # Create straightness data for orthogonality plots (remove best fit lines)
    slope_data['Ax1Orthog'] = mean_ax1_err - slope_data['Ax1Line']
    slope_data['Ax2Orthog'] = mean_ax2_err - np.polyval(slope_data['Ax2Coef'], grid_data['X'][0, :])
    
    # Calculate orthogonality error
    # This represents how much the axes deviate from being perfectly perpendicular
    orthog_slope = slope_data['Ax1Coef'][0] - y_meas_dir * slope_data['Ax2Coef'][0]
    slope_data['orthog'] = np.arctan(orthog_slope / 1000) * 180 / np.pi * 3600  # Convert to arc seconds
    
    # Store measurement direction factor
    slope_data['y_meas_dir'] = y_meas_dir
    
    # Store mean error vectors for reference
    slope_data['mean_ax1_err'] = mean_ax1_err
    slope_data['mean_ax2_err'] = mean_ax2_err
    
    # Display slope calculation results
    print('\n=== SLOPE CALCULATION RESULTS ===')
    print(f"Ax1 straightness slope: {slope_data['Ax1Coef'][0]:.6f} um/mm")
    print(f"Ax1 straightness offset: {slope_data['Ax1Coef'][1]:.6f} um")
    print(f"Ax2 straightness slope: {slope_data['Ax2Coef'][0]:.6f} um/mm")
    print(f"Ax2 straightness offset: {slope_data['Ax2Coef'][1]:.6f} um")
    print(f"Orthogonality error: {slope_data['orthog']:.3f} arc-seconds")
    print(f"RMS Ax1 straightness (after detrend): {np.std(slope_data['Ax1Orthog']):.3f} um")
    print(f"RMS Ax2 straightness (after detrend): {np.std(slope_data['Ax2Orthog']):.3f} um")
    print('=================================\n')
    
    return slope_data


if __name__ == "__main__":
    # Test the function if run directly
    from step1_parse_header import step1_parse_header
    from step2_load_data import step2_load_data
    from step3_create_grid import step3_create_grid
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
        
        print("=== TEST COMPLETED SUCCESSFULLY ===")
        print("Slope data structure saved for comparison")
        
        # Save the result for comparison with MATLAB/Octave
        sio.savemat('step4_output_python.mat', {
            'slope_data': slope_data,
            'grid_data': grid_data,
            'data_raw': data_raw, 
            'config': config
        })
        
    except Exception as err:
        print('ERROR in step4_calculate_slopes:')
        print(str(err))
        import traceback
        traceback.print_exc()
