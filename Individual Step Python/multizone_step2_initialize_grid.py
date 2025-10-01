import numpy as np
import os

# Import single-zone processing functions
from step1_parse_header import step1_parse_header
from step2_load_data import step2_load_data
from step3_create_grid import step3_create_grid
from step4_calculate_slopes import step4_calculate_slopes
from step5_process_errors import step5_process_errors


def multizone_step2_initialize_grid(setup):
    """
    MULTIZONE_STEP2_INITIALIZE_GRID - Initialize full grid system and process first zone
    
    This function processes the first zone to establish the master reference,
    determines grid increments, and initializes the full travel accumulation matrices
    
    INPUT:
        setup - dict from multizone_step1_setup containing configuration
    
    OUTPUT:
        grid_system - dict containing full grid system and first zone data
    """
    
    # Initialize output dictionary
    grid_system = {}
    
    print('Initializing full grid system...')
    print('Processing first zone (Row 1, Col 1)...')
    
    # Process the first zone to establish master reference
    first_zone_file = setup['zone_filenames'][0][0]  # Row 1, Col 1
    print(f'  Loading: {first_zone_file}')
    
    # Get the first zone data using our single-zone pipeline
    # Step 1: Parse header
    config = step1_parse_header(first_zone_file)
    
    # Step 2: Load raw data
    data_raw = step2_load_data(first_zone_file, config)
    
    # Step 3: Create grid
    grid_data = step3_create_grid(data_raw)
    
    # Step 4: Calculate slopes  
    slope_data = step4_calculate_slopes(grid_data)
    
    # Step 5: Process errors
    first_zone_data = step5_process_errors(grid_data, slope_data)
    
    # Store master reference data for subsequent zones
    grid_system['Ax1Master'] = first_zone_data['X'].copy()    # master Axis 1 position -- scan axis
    grid_system['Ax2Master'] = first_zone_data['Y'].copy()    # master Axis 2 position -- step axis  
    grid_system['Ax1MasErr'] = first_zone_data['Ax1Err'].copy()  # master Ax1 error
    grid_system['Ax2MasErr'] = first_zone_data['Ax2Err'].copy()  # master Ax2 error
    
    # Store master data for row comparisons (used when starting new rows)
    grid_system['rowAx1Master'] = grid_system['Ax1Master'].copy()
    grid_system['rowAx2Master'] = grid_system['Ax2Master'].copy()
    grid_system['rowAx1MasErr'] = grid_system['Ax1MasErr'].copy()
    grid_system['rowAx2MasErr'] = grid_system['Ax2MasErr'].copy()
    
    # Store system parameters from first zone
    grid_system['SN'] = config['SN']
    grid_system['Ax1Name'] = config['Ax1Name']
    grid_system['Ax2Name'] = config['Ax2Name']
    grid_system['Ax1Num'] = config['Ax1Num']
    grid_system['Ax2Num'] = config['Ax2Num']
    grid_system['Ax1Sign'] = config['Ax1Sign']
    grid_system['Ax2Sign'] = config['Ax2Sign']
    grid_system['UserUnit'] = config['UserUnit']
    grid_system['calDivisor'] = config['calDivisor']
    grid_system['posUnit'] = config['posUnit']
    grid_system['errUnit'] = config['errUnit']
    grid_system['Ax1Gantry'] = config['Ax1Gantry']
    grid_system['Ax2Gantry'] = config['Ax2Gantry']
    grid_system['Ax1SampDist'] = data_raw['Ax1SampDist']
    grid_system['Ax2SampDist'] = data_raw['Ax2SampDist']
    grid_system['operator'] = config['operator']
    grid_system['model'] = config['model']
    
    # Initialize environmental data arrays
    grid_system['airTemp'] = setup['airTemp'].copy()
    grid_system['matTemp'] = setup['matTemp'].copy()
    grid_system['comment'] = setup['comment'].copy()
    grid_system['fileDate'] = setup['fileDate'].copy()
    
    # Store first zone environmental data
    grid_system['airTemp'][0] = float(config['airTemp']) if config['airTemp'] else 0.0
    grid_system['matTemp'][0] = float(config['matTemp']) if config['matTemp'] else 0.0
    grid_system['comment'][0] = config['comment']
    grid_system['fileDate'][0] = config['fileDate']
    
    # Determine step sizes from first zone grid
    grid_system['incAx1'] = grid_system['Ax1Master'][0, 1] - grid_system['Ax1Master'][0, 0]
    grid_system['incAx2'] = grid_system['Ax2Master'][1, 0] - grid_system['Ax2Master'][0, 0]
    
    print(f"  Grid increments: Ax1 = {grid_system['incAx1']:.6f}, Ax2 = {grid_system['incAx2']:.6f}")
    
    # Calculate dimensions for full travel matrices
    # Convert travel ranges from inches to mm to match grid increments
    travel_ax1_mm = [setup['travelAx1'][0] * 25.4, setup['travelAx1'][1] * 25.4]
    travel_ax2_mm = [setup['travelAx2'][0] * 25.4, setup['travelAx2'][1] * 25.4]
    
    num_points_ax1 = round((travel_ax1_mm[1] - travel_ax1_mm[0]) / grid_system['incAx1'] + 1)
    num_points_ax2 = round((travel_ax2_mm[1] - travel_ax2_mm[0]) / grid_system['incAx2'] + 1)
    
    print(f"  Full grid dimensions: {num_points_ax2} x {num_points_ax1} points")
    
    # Initialize full travel matrices (all zeros initially)
    grid_system['X'] = np.zeros((num_points_ax2, num_points_ax1))      # Axis 1 Position
    grid_system['Y'] = np.zeros((num_points_ax2, num_points_ax1))      # Axis 2 Position
    grid_system['Ax1Err'] = np.zeros((num_points_ax2, num_points_ax1)) # Axis 1 Error
    grid_system['Ax2Err'] = np.zeros((num_points_ax2, num_points_ax1)) # Axis 2 Error
    grid_system['avgCount'] = np.zeros((num_points_ax2, num_points_ax1)) # Average counter for overlaps
    
    # Store dimensions for reference
    grid_system['fullGridSize'] = [num_points_ax2, num_points_ax1]
    grid_system['Ax1size'] = list(grid_system['Ax1Master'].shape)
    grid_system['Ax2size'] = list(grid_system['Ax2Master'].shape)
    
    # Calculate array indices for first zone (starts at origin of full grid)
    grid_system['arrayIndexAx1'] = 0  # offset index in Axis 1 direction (0-based)
    grid_system['arrayIndexAx2'] = 0  # offset index in Axis 2 direction (0-based)
    
    # Calculate ranges in full travel vectors for this zone
    ax1_size = grid_system['Ax1Master'].shape[1]  # Number of columns
    ax2_size = grid_system['Ax1Master'].shape[0]  # Number of rows
    
    grid_system['rangeAx1'] = slice(grid_system['arrayIndexAx1'], 
                                   grid_system['arrayIndexAx1'] + ax1_size)
    grid_system['rangeAx2'] = slice(grid_system['arrayIndexAx2'], 
                                   grid_system['arrayIndexAx2'] + ax2_size)
    
    # Add first zone's data to full travel matrices
    print('  Adding first zone data to accumulation matrices...')
    grid_system['X'][grid_system['rangeAx2'], grid_system['rangeAx1']] += grid_system['Ax1Master']
    grid_system['Y'][grid_system['rangeAx2'], grid_system['rangeAx1']] += grid_system['Ax2Master']
    grid_system['Ax1Err'][grid_system['rangeAx2'], grid_system['rangeAx1']] += grid_system['Ax1MasErr']
    grid_system['Ax2Err'][grid_system['rangeAx2'], grid_system['rangeAx1']] += grid_system['Ax2MasErr']
    grid_system['avgCount'][grid_system['rangeAx2'], grid_system['rangeAx1']] += np.ones(grid_system['Ax1Master'].shape)
    
    # Update zone counter
    grid_system['zoneCount'] = 1
    setup['zoneCount'] = 1  # Update the setup dictionary too
    
    # Display summary
    print('\n=== GRID SYSTEM SUMMARY ===')
    print(f"System: {grid_system['model']} (S/N: {grid_system['SN']})")
    print(f"Full grid size: {num_points_ax2} x {num_points_ax1} points")
    print(f"Grid spacing: {grid_system['incAx1']:.6f} x {grid_system['incAx2']:.6f}")
    print(f"Travel ranges: [{travel_ax1_mm[0]:.3f}, {travel_ax1_mm[1]:.3f}] mm x "
          f"[{travel_ax2_mm[0]:.3f}, {travel_ax2_mm[1]:.3f}] mm")
    print(f"First zone processed: {first_zone_file}")
    print(f"First zone size: {grid_system['Ax1size'][0]} x {grid_system['Ax1size'][1]} points")
    print(f"Non-zero accumulation points: {np.sum(grid_system['avgCount'] > 0)}")
    print('===========================\n')
    
    return grid_system


if __name__ == "__main__":
    # Test the function with setup from Step 1
    from multizone_step1_setup import multizone_step1_setup
    import scipy.io as sio
    
    # Create test setup (using 642583 test data ranges)
    num_row = 2
    num_col = 2
    travel_ax1 = [-250/25.4, 250/25.4]  # Convert from mm to inches (500mm range)
    travel_ax2 = [-250/25.4, 250/25.4]  # Convert from mm to inches (500mm range)
    
    zone_filenames = [
        ['MATLAB Source/642583-1-1-CZ1.dat', 'MATLAB Source/642583-1-1-CZ2.dat'],  # Row 1
        ['MATLAB Source/642583-1-1-CZ3.dat', 'MATLAB Source/642583-1-1-CZ4.dat']   # Row 2
    ]
    
    try:
        # Step 1: Create setup
        setup = multizone_step1_setup(num_row, num_col, travel_ax1, travel_ax2, zone_filenames)
        
        # Step 2: Initialize grid system
        grid_system = multizone_step2_initialize_grid(setup)
        
        # Save results to text file for comparison
        with open('multizone_step2_output_python.txt', 'w') as f:
            f.write('=== MULTIZONE STEP 2: GRID INITIALIZATION ===\n')
            f.write(f"SN: {grid_system['SN']}\n")
            f.write(f"Ax1Name: {grid_system['Ax1Name']}\n")
            f.write(f"Ax2Name: {grid_system['Ax2Name']}\n")
            f.write(f"model: {grid_system['model']}\n")
            f.write(f"operator: {grid_system['operator']}\n")
            f.write(f"incAx1: {grid_system['incAx1']:.12f}\n")
            f.write(f"incAx2: {grid_system['incAx2']:.12f}\n")
            f.write(f"fullGridSize_rows: {grid_system['fullGridSize'][0]}\n")
            f.write(f"fullGridSize_cols: {grid_system['fullGridSize'][1]}\n")
            f.write(f"Ax1size_rows: {grid_system['Ax1size'][0]}\n")
            f.write(f"Ax1size_cols: {grid_system['Ax1size'][1]}\n")
            f.write(f"zoneCount: {grid_system['zoneCount']}\n")
            f.write(f"nonZeroPoints: {np.sum(grid_system['avgCount'] > 0)}\n")
            f.write(f"Ax1Master_min: {np.min(grid_system['Ax1Master']):.12f}\n")
            f.write(f"Ax1Master_max: {np.max(grid_system['Ax1Master']):.12f}\n")
            f.write(f"Ax2Master_min: {np.min(grid_system['Ax2Master']):.12f}\n")
            f.write(f"Ax2Master_max: {np.max(grid_system['Ax2Master']):.12f}\n")
            f.write(f"Ax1MasErr_min: {np.min(grid_system['Ax1MasErr']):.12f}\n")
            f.write(f"Ax1MasErr_max: {np.max(grid_system['Ax1MasErr']):.12f}\n")
            f.write(f"Ax2MasErr_min: {np.min(grid_system['Ax2MasErr']):.12f}\n")
            f.write(f"Ax2MasErr_max: {np.max(grid_system['Ax2MasErr']):.12f}\n")
            f.write(f"airTemp_zone1: {grid_system['airTemp'][0]:.6f}\n")
            f.write(f"matTemp_zone1: {grid_system['matTemp'][0]:.6f}\n")
        
        print("=== TEST COMPLETED SUCCESSFULLY ===")
        print("Grid system initialized and first zone processed")
        print("Results saved to: multizone_step2_output_python.txt")
        
        # Save for comparison with MATLAB (exclude slice objects)  
        grid_system_save = grid_system.copy()
        # Convert slice objects to indices for saving
        grid_system_save['rangeAx1_start'] = grid_system['rangeAx1'].start
        grid_system_save['rangeAx1_stop'] = grid_system['rangeAx1'].stop
        grid_system_save['rangeAx2_start'] = grid_system['rangeAx2'].start
        grid_system_save['rangeAx2_stop'] = grid_system['rangeAx2'].stop
        del grid_system_save['rangeAx1']  # Remove slice objects
        del grid_system_save['rangeAx2']
        
        sio.savemat('multizone_step2_output_python.mat', {
            'grid_system': grid_system_save, 
            'setup': setup
        })
        
    except Exception as err:
        print('ERROR in multizone_step2_initialize_grid:')
        print(str(err))
        import traceback
        traceback.print_exc()
