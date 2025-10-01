import numpy as np
from copy import deepcopy

# Import single-zone processing functions
from step1_parse_header import step1_parse_header
from step2_load_data import step2_load_data
from step3_create_grid import step3_create_grid
from step4_calculate_slopes import step4_calculate_slopes
from step5_process_errors import step5_process_errors


def multizone_step3_stitch_zones(setup, grid_system):
    """
    MULTIZONE_STEP3_STITCH_ZONES - Process and stitch all zones in the multi-zone grid
    
    This function processes all zones beyond the first one, applying column and row
    stitching algorithms to create a seamless calibration map
    
    INPUT:
        setup - dict from multizone_step1_setup containing configuration
        grid_system - dict from multizone_step2_initialize_grid
    
    OUTPUT:
        grid_system - updated dict with all zones processed and stitched
    """
    
    print('Step 3: Processing and stitching all zones...')
    print('==============================================')
    
    # Constants
    y_meas_dir = -1   # slope due to mirror misalignment is always opposite sign
                      # between axes when laser and encoder read positive in same direction
    
    # Initialize master data for column and row stitching
    col_master = {}  # Master for column stitching (within each row)
    row_master = {}  # Masters for row stitching
    
    # Process all zones in row-major order
    for i in range(setup['numRow']):
        for j in range(setup['numCol']):
            
            print('----------------------------------------')
            print(f'Processing Zone: Row {i+1}, Col {j+1}')
            
            # Skip first zone (already processed in Step 2)
            if (i == 0) and (j == 0):
                # First zone is already the master - just store references
                col_master['X'] = grid_system['Ax1Master'].copy()
                col_master['Y'] = grid_system['Ax2Master'].copy()
                col_master['Ax1Err'] = grid_system['Ax1MasErr'].copy()
                col_master['Ax2Err'] = grid_system['Ax2MasErr'].copy()
                row_master[(i, j)] = deepcopy(col_master)
                
                print('  First zone (already processed) - set as master')
                continue
            
            # Process current zone data
            zone_file = setup['zone_filenames'][i][j]
            print(f'  Loading: {zone_file}')
            
            # Get zone data using single-zone pipeline
            config = step1_parse_header(zone_file)
            data_raw = step2_load_data(zone_file, config)
            grid_data = step3_create_grid(data_raw)
            # Use raw interpolated error grids (no per-zone detrending or origin shift)
            slave_data = {
                'X': grid_data['X'].copy(),
                'Y': grid_data['Y'].copy(),
                'Ax1Err': grid_data['Ax1Err'].copy(),
                'Ax2Err': grid_data['Ax2Err'].copy(),
            }
            
            # Store environmental data
            zone_idx = grid_system['zoneCount']
            grid_system['airTemp'][zone_idx] = float(config['airTemp']) if config['airTemp'] else 0.0
            grid_system['matTemp'][zone_idx] = float(config['matTemp']) if config['matTemp'] else 0.0
            grid_system['comment'][zone_idx] = config['comment']
            grid_system['fileDate'][zone_idx] = config['fileDate']
            
            # Determine stitching type and master data
            if j > 0:
                # Column stitching (same row, next column)
                print('  Performing COLUMN stitching with previous zone')
                master = col_master
                stitch_type = 'column'
            else:
                # Row stitching (next row, first column)
                print('  Performing ROW stitching with zone from previous row')
                master = row_master[(i-1, j)]
                stitch_type = 'row'
            
            # Apply stitching corrections
            slave_corrected = apply_stitching_corrections(master, slave_data, stitch_type, y_meas_dir)
            
            # Update masters for future stitching
            col_master = deepcopy(slave_corrected)
            if (i > 0) and (j == 0):
                row_master[(i, j)] = deepcopy(slave_corrected)
            
            # Calculate position in full grid for this zone
            array_index_ax1 = round((slave_corrected['X'][0, 0] - grid_system['X'][0, 0]) / grid_system['incAx1'])
            array_index_ax2 = round((slave_corrected['Y'][0, 0] - grid_system['Y'][0, 0]) / grid_system['incAx2'])
            
            slave_shape = slave_corrected['X'].shape
            range_ax1 = slice(array_index_ax1, array_index_ax1 + slave_shape[1])
            range_ax2 = slice(array_index_ax2, array_index_ax2 + slave_shape[0])
            
            print(f'  Adding to full grid at indices: Ax1=[{array_index_ax1}:{array_index_ax1 + slave_shape[1]-1}], ' +
                  f'Ax2=[{array_index_ax2}:{array_index_ax2 + slave_shape[0]-1}]')
            
            # Add corrected zone data to full travel matrices
            grid_system['X'][range_ax2, range_ax1] += slave_corrected['X']
            grid_system['Y'][range_ax2, range_ax1] += slave_corrected['Y']
            grid_system['Ax1Err'][range_ax2, range_ax1] += slave_corrected['Ax1Err']
            grid_system['Ax2Err'][range_ax2, range_ax1] += slave_corrected['Ax2Err']
            grid_system['avgCount'][range_ax2, range_ax1] += np.ones(slave_shape)
            
            grid_system['zoneCount'] += 1
            print(f'  Zone {grid_system["zoneCount"]} processed successfully')
    
    print('\n=== ZONE STITCHING SUMMARY ===')
    print(f'Total zones processed: {grid_system["zoneCount"]}')
    print(f'Non-zero accumulation points: {np.sum(grid_system["avgCount"] > 0)}')
    print(f'Max accumulation count: {np.max(grid_system["avgCount"])}')
    print('==============================\n')
    
    return grid_system


def apply_stitching_corrections(master, slave, stitch_type, y_meas_dir):
    """
    Apply stitching corrections to align slave zone with master zone
    
    INPUT:
        master - master zone data dict
        slave - slave zone data dict
        stitch_type - 'column' or 'row' stitching
        y_meas_dir - measurement direction factor for orthogonality
    
    OUTPUT:
        slave_corrected - corrected slave zone data dict
    """
    
    slave_corrected = deepcopy(slave)  # Copy slave data
    
    if stitch_type == 'column':
        # Column stitching: stitching adjacent zones in same row (Axis 1 direction)

        # Determine overlap like MATLAB: find k where slave X just exceeds max(master X)
        master_x = master['X'][0, :]
        slave_x = slave['X'][0, :]
        max_master_x = np.max(master_x)
        k = 0
        while k < slave_x.size and slave_x[k] < max_master_x:
            k += 1
        if k == 0:
            print('    Warning: No overlap found for column stitching (k=0)')
            return slave_corrected

        m_range = np.arange(master_x.size - k, master_x.size)
        s_range = np.arange(0, k)
        print(f'    Overlap: Master cols {m_range[0]}-{m_range[-1]}, Slave cols {s_range[0]}-{s_range[-1]}')

        # Calculate mean error curves in overlap regions for Ax1 (column means over overlap cols)
        master_ax1_mean = np.mean(master['Ax1Err'][:, m_range], axis=1)
        slave_ax1_mean = np.mean(slave['Ax1Err'][:, s_range], axis=1)

        # Fit linear slopes to mean curves (Ax1 straightness vs Y)
        master_coef_ax1 = np.polyfit(master['Y'][:, 0], master_ax1_mean, 1)
        slave_coef_ax1 = np.polyfit(slave['Y'][:, 0], slave_ax1_mean, 1)
        print(f'    Ax1 slope correction: Master={master_coef_ax1[0]:.6f}, Slave={slave_coef_ax1[0]:.6f} um/mm')

        # Apply Ax1 slope corrections to all columns of slave
        y_vec_slave = slave['Y'][:, 0]
        for n in range(slave['X'].shape[1]):
            slave_corrected['Ax1Err'][:, n] = (
                slave_corrected['Ax1Err'][:, n]
                - np.polyval(slave_coef_ax1, y_vec_slave)
                + np.polyval(master_coef_ax1, y_vec_slave)
            )

        # Apply Ax2 orthogonality correction (coupled to Ax1)
        master_coef_ax2_orth = y_meas_dir * master_coef_ax1
        slave_coef_ax2_orth = y_meas_dir * slave_coef_ax1
        for n in range(slave['Y'].shape[0]):
            slave_corrected['Ax2Err'][n, :] = (
                slave_corrected['Ax2Err'][n, :]
                - np.polyval(slave_coef_ax2_orth, slave['X'][n, :])
                + np.polyval(master_coef_ax2_orth, slave['X'][n, :])
            )

        # Apply offset corrections to match mean levels in overlap regions (scalar means)
        ax1_correction = np.mean(master['Ax1Err'][:, m_range]) - np.mean(slave_corrected['Ax1Err'][:, s_range])
        ax2_correction = np.mean(master['Ax2Err'][:, m_range]) - np.mean(slave_corrected['Ax2Err'][:, s_range])
        slave_corrected['Ax1Err'] += ax1_correction
        slave_corrected['Ax2Err'] += ax2_correction
        print(f'    Offset corrections: Ax1={ax1_correction:.3f}, Ax2={ax2_correction:.3f} um')
        
    else:  # row stitching
        # Row stitching: stitching zones in next row (Axis 2 direction)

        # Determine overlap like MATLAB using Y positions
        master_y = master['Y'][:, 0]
        slave_y = slave['Y'][:, 0]
        max_master_y = np.max(master_y)
        k = 0
        while k < slave_y.size and slave_y[k] < max_master_y:
            k += 1
        if k == 0:
            print('    Warning: No overlap found for row stitching (k=0)')
            return slave_corrected

        m_range = np.arange(master_y.size - k, master_y.size)
        s_range = np.arange(0, k)
        print(f'    Overlap: Master rows {m_range[0]}-{m_range[-1]}, Slave rows {s_range[0]}-{s_range[-1]}')

        # Calculate mean error curves in overlap regions for Ax2 (row means over overlap rows)
        master_ax2_mean = np.mean(master['Ax2Err'][m_range, :], axis=0)
        slave_ax2_mean = np.mean(slave['Ax2Err'][s_range, :], axis=0)

        # Fit linear slopes to mean curves (Ax2 straightness vs X)
        master_coef_ax2 = np.polyfit(master['X'][0, :], master_ax2_mean, 1)
        slave_coef_ax2 = np.polyfit(slave['X'][0, :], slave_ax2_mean, 1)
        print(f'    Ax2 slope correction: Master={master_coef_ax2[0]:.6f}, Slave={slave_coef_ax2[0]:.6f} um/mm')

        # Apply Ax2 slope corrections to all rows of slave
        for n in range(slave['Y'].shape[0]):
            slave_corrected['Ax2Err'][n, :] = (
                slave_corrected['Ax2Err'][n, :]
                - np.polyval(slave_coef_ax2, slave['X'][n, :])
                + np.polyval(master_coef_ax2, slave['X'][n, :])
            )

        # Apply scalar offset corrections using overlap regions
        ax1_correction = np.mean(master['Ax1Err'][m_range, :]) - np.mean(slave_corrected['Ax1Err'][s_range, :])
        ax2_correction = np.mean(master['Ax2Err'][m_range, :]) - np.mean(slave_corrected['Ax2Err'][s_range, :])
        slave_corrected['Ax1Err'] += ax1_correction
        slave_corrected['Ax2Err'] += ax2_correction
        print(f'    Offset corrections: Ax1={ax1_correction:.3f}, Ax2={ax2_correction:.3f} um')
    
    return slave_corrected


if __name__ == "__main__":
    # Test the function with setup from Steps 1 & 2
    from multizone_step1_setup import multizone_step1_setup
    from multizone_step2_initialize_grid import multizone_step2_initialize_grid
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
        print("=== STEP 1: Setup Configuration ===")
        setup = multizone_step1_setup(num_row, num_col, travel_ax1, travel_ax2, zone_filenames)
        
        # Step 2: Initialize grid system
        print("\n=== STEP 2: Initialize Grid System ===")
        grid_system = multizone_step2_initialize_grid(setup)
        
        # Step 3: Stitch all zones
        print("\n=== STEP 3: Stitch All Zones ===")
        grid_system = multizone_step3_stitch_zones(setup, grid_system)
        
        # Save results to text file for comparison
        with open('multizone_step3_output_python.txt', 'w') as f:
            f.write('=== MULTIZONE STEP 3: ZONE STITCHING ===\n')
            f.write(f"totalZones: {grid_system['zoneCount']}\n")
            f.write(f"nonZeroPoints: {np.sum(grid_system['avgCount'] > 0)}\n")
            f.write(f"maxAvgCount: {np.max(grid_system['avgCount'])}\n")
            f.write(f"fullGridSize_rows: {grid_system['fullGridSize'][0]}\n")
            f.write(f"fullGridSize_cols: {grid_system['fullGridSize'][1]}\n")
            f.write(f"X_min: {np.min(grid_system['X'][grid_system['avgCount'] > 0]):.12f}\n")
            f.write(f"X_max: {np.max(grid_system['X'][grid_system['avgCount'] > 0]):.12f}\n")
            f.write(f"Y_min: {np.min(grid_system['Y'][grid_system['avgCount'] > 0]):.12f}\n")
            f.write(f"Y_max: {np.max(grid_system['Y'][grid_system['avgCount'] > 0]):.12f}\n")
            f.write(f"Ax1Err_min: {np.min(grid_system['Ax1Err'][grid_system['avgCount'] > 0]):.12f}\n")
            f.write(f"Ax1Err_max: {np.max(grid_system['Ax1Err'][grid_system['avgCount'] > 0]):.12f}\n")
            f.write(f"Ax2Err_min: {np.min(grid_system['Ax2Err'][grid_system['avgCount'] > 0]):.12f}\n")
            f.write(f"Ax2Err_max: {np.max(grid_system['Ax2Err'][grid_system['avgCount'] > 0]):.12f}\n")
            
            # Environmental data summary
            f.write(f"airTemp_mean: {np.mean([x for x in grid_system['airTemp'] if x != 0]):.6f}\n")
            f.write(f"matTemp_mean: {np.mean([x for x in grid_system['matTemp'] if x != 0]):.6f}\n")
        
        print("=== TEST COMPLETED SUCCESSFULLY ===")
        print("All zones processed and stitched")
        print("Results saved to: multizone_step3_output_python.txt")
        
        # Save for comparison with MATLAB (exclude problematic objects)
        grid_system_save = deepcopy(grid_system)
        # Remove any objects that can't be saved to .mat
        keys_to_remove = []
        for key in grid_system_save.keys():
            if key.startswith('range') and isinstance(grid_system_save[key], slice):
                keys_to_remove.append(key)
        
        for key in keys_to_remove:
            del grid_system_save[key]
        
        sio.savemat('multizone_step3_output_python.mat', {
            'grid_system': grid_system_save,
            'setup': setup
        })
        
    except Exception as err:
        print('ERROR in multizone_step3_stitch_zones:')
        print(str(err))
        import traceback
        traceback.print_exc()
