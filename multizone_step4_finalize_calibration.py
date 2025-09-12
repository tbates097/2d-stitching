import numpy as np
import os
from copy import deepcopy


def multizone_step4_finalize_calibration(setup, grid_system):
    """
    MULTIZONE_STEP4_FINALIZE_CALIBRATION - Complete final averaging and generate calibration
    
    This function performs the final averaging of overlapped regions and generates
    the calibration file in Aerotech A3200 format
    
    INPUT:
        setup - dict from multizone_step1_setup containing configuration
        grid_system - dict from multizone_step3_stitch_zones with all zones
    
    OUTPUT:
        final_result - dict containing final calibration data and statistics
    """
    
    print('Step 4: Finalizing calibration and generating output files...')
    print('============================================================')
    
    # STEP 4A: Final averaging of overlapped regions
    print('Performing final averaging of overlapped regions...')
    
    # Divide accumulated values by avgCount to complete averaging in overlap regions
    total_size = grid_system['X'].shape
    valid_mask = grid_system['avgCount'] > 0
    
    print(f'  Grid size: {total_size[0]} x {total_size[1]} points')
    print(f'  Valid points: {np.sum(valid_mask)}')
    print(f'  Points with overlaps: {np.sum(grid_system["avgCount"] > 1)}')
    
    # Create final averaged matrices
    X_final = np.zeros(total_size)
    Y_final = np.zeros(total_size)
    Ax1Err_final = np.zeros(total_size)
    Ax2Err_final = np.zeros(total_size)
    
    # Perform averaging only for valid points
    X_final[valid_mask] = grid_system['X'][valid_mask] / grid_system['avgCount'][valid_mask]
    Y_final[valid_mask] = grid_system['Y'][valid_mask] / grid_system['avgCount'][valid_mask]
    Ax1Err_final[valid_mask] = grid_system['Ax1Err'][valid_mask] / grid_system['avgCount'][valid_mask]
    Ax2Err_final[valid_mask] = grid_system['Ax2Err'][valid_mask] / grid_system['avgCount'][valid_mask]
    
    print('  Final averaging completed')
    
    # STEP 4B: Remove global straightness slopes and calculate orthogonality
    print('Removing global straightness slopes...')
    
    # Calculate mean error curves for valid points
    valid_rows = np.any(valid_mask, axis=1)
    valid_cols = np.any(valid_mask, axis=0)
    
    Ax1_mean = np.mean(Ax1Err_final[valid_mask].reshape(-1, np.sum(valid_cols)), axis=1)
    Ax2_mean = np.mean(Ax2Err_final[valid_mask].reshape(np.sum(valid_rows), -1), axis=0)
    
    # Fit global slopes using valid points
    Y_valid = Y_final[valid_rows, 0]  # Y values for each row
    X_valid = X_final[0, valid_cols]  # X values for each column
    
    Ax1Coef = np.polyfit(Y_valid, Ax1_mean, 1)   # slope units microns/mm
    Ax2Coef = np.polyfit(X_valid, Ax2_mean, 1)   # slope units microns/mm
    
    print(f'  Global Ax1 slope: {Ax1Coef[0]:.6f} um/mm')
    print(f'  Global Ax2 slope: {Ax2Coef[0]:.6f} um/mm')
    
    # Create best fit lines
    y_meas_dir = -1  # measurement direction factor
    Ax1Line = np.polyval(Ax1Coef, Y_final[:, 0])
    Ax2Line = np.polyval(y_meas_dir * Ax1Coef, X_final[0, :])
    
    # Remove slopes from error data
    for i in range(total_size[1]):
        if np.any(valid_mask[:, i]):
            Ax1Err_final[:, i] -= Ax1Line
    
    for i in range(total_size[0]):
        if np.any(valid_mask[i, :]):
            Ax2Err_final[i, :] -= Ax2Line
    
    # Calculate orthogonality
    orthog = Ax1Coef[0] - y_meas_dir * Ax2Coef[0]
    orthog_arcsec = np.arctan(orthog/1000) * 180/np.pi * 3600  # convert to arc seconds
    
    print(f'  Global orthogonality error: {orthog_arcsec:.3f} arc-seconds')
    
    # STEP 4C: Calculate vector sum accuracy error
    print('Calculating vector sum accuracy errors...')
    
    # Subtract error at origin prior to vector sum calculation
    if valid_mask[0, 0]:
        Ax1Err_final = Ax1Err_final - Ax1Err_final[0, 0]
        Ax2Err_final = Ax2Err_final - Ax2Err_final[0, 0]
    
    # Calculate total vector sum accuracy error
    VectorErr = np.sqrt(Ax1Err_final**2 + Ax2Err_final**2)
    
    # Calculate peak-to-peak values (only for valid points)
    valid_ax1_errors = Ax1Err_final[valid_mask]
    valid_ax2_errors = Ax2Err_final[valid_mask]
    valid_vector_errors = VectorErr[valid_mask]
    
    pkAx1 = np.max(valid_ax1_errors) - np.min(valid_ax1_errors)
    pkAx2 = np.max(valid_ax2_errors) - np.min(valid_ax2_errors)
    pkVector = np.max(valid_vector_errors) - np.min(valid_vector_errors)
    
    # Calculate RMS values
    rmsAx1 = np.sqrt(np.mean(valid_ax1_errors**2))
    rmsAx2 = np.sqrt(np.mean(valid_ax2_errors**2))
    rmsVector = np.sqrt(np.mean(valid_vector_errors**2))
    
    print(f'  Ax1 Peak-to-Peak: {pkAx1:.3f} um (±{pkAx1/2:.3f} um)')
    print(f'  Ax2 Peak-to-Peak: {pkAx2:.3f} um (±{pkAx2/2:.3f} um)')
    print(f'  Vector Peak-to-Peak: {pkVector:.3f} um')
    print(f'  Ax1 RMS: {rmsAx1:.3f} um')
    print(f'  Ax2 RMS: {rmsAx2:.3f} um')
    print(f'  Vector RMS: {rmsVector:.3f} um')
    
    # STEP 4D: Generate calibration file (if requested)
    if setup['WriteCalFile']:
        print('Generating calibration file...')
        
        # Create signed calibration error tables with surrounding zeros
        size_cal = Ax1Err_final.shape
        
        # Create matrices filled with zeros (add extra rows/columns for smooth transitions)
        Ax1cal = np.zeros((size_cal[0]+2, size_cal[1]+2))
        Ax2cal = np.zeros((size_cal[0]+2, size_cal[1]+2))
        
        # Populate middle of matrices with measured data (inverted sign for correction)
        # Units: microns, precision to nm/10 (round to 4 decimal places)
        Ax1cal[1:-1, 1:-1] = -grid_system['Ax1Sign'] * np.round(Ax1Err_final * 10000)/10000
        Ax2cal[1:-1, 1:-1] = -grid_system['Ax2Sign'] * np.round(Ax2Err_final * 10000)/10000
        
        # Write calibration file
        write_cal_file(setup['CalFile'], Ax1cal, Ax2cal, grid_system, setup)
        
        print(f'  Calibration file saved: {setup["CalFile"]}')
    
    # STEP 4E: Generate output data file (if requested)
    if setup['writeOutputFile']:
        print('Generating output accuracy file...')
        
        write_accuracy_file(setup['OutFile'], X_final, Y_final, Ax1Err_final, Ax2Err_final,
                           VectorErr, valid_mask, grid_system, setup)
        
        print(f'  Output file saved: {setup["OutFile"]}')
    
    # Store final results
    final_result = {}
    final_result['X'] = X_final
    final_result['Y'] = Y_final
    final_result['Ax1Err'] = Ax1Err_final
    final_result['Ax2Err'] = Ax2Err_final
    final_result['VectorErr'] = VectorErr
    final_result['validMask'] = valid_mask
    final_result['avgCount'] = grid_system['avgCount']
    
    # Statistics
    final_result['pkAx1'] = pkAx1
    final_result['pkAx2'] = pkAx2
    final_result['pkVector'] = pkVector
    final_result['rmsAx1'] = rmsAx1
    final_result['rmsAx2'] = rmsAx2
    final_result['rmsVector'] = rmsVector
    final_result['orthogonality'] = orthog_arcsec
    final_result['Ax1Slope'] = Ax1Coef[0]
    final_result['Ax2Slope'] = Ax2Coef[0]
    
    # Grid information
    final_result['totalZones'] = grid_system['zoneCount']
    final_result['gridSize'] = list(total_size)
    final_result['validPoints'] = np.sum(valid_mask)
    final_result['overlapPoints'] = np.sum(grid_system['avgCount'] > 1)
    
    print('\n=== FINAL CALIBRATION SUMMARY ===')
    print(f'Total zones processed: {final_result["totalZones"]}')
    print(f'Final grid size: {total_size[0]} x {total_size[1]} points')
    print(f'Valid data points: {final_result["validPoints"]} ({100*final_result["validPoints"]/np.prod(total_size):.1f}% coverage)')
    print(f'Overlap points: {final_result["overlapPoints"]} ({100*final_result["overlapPoints"]/final_result["validPoints"]:.1f}% of valid points)')
    print('Final accuracy performance:')
    print(f'  Ax1: ±{pkAx1/2:.3f} um P-P, {rmsAx1:.3f} um RMS')
    print(f'  Ax2: ±{pkAx2/2:.3f} um P-P, {rmsAx2:.3f} um RMS')
    print(f'  Vector: {rmsVector:.3f} um RMS')
    print(f'  Orthogonality: {orthog_arcsec:.3f} arc-seconds')
    print('===================================\n')
    
    return final_result


def write_cal_file(filename, Ax1cal, Ax2cal, grid_system, setup):
    """Write calibration file using START2D header format (per attached example)."""

    # Determine units strings
    pos_unit = 'METRIC' if setup.get('UserUnit', 'METRIC').upper().startswith('METRIC') else 'ENGLISH'
    cor_unit = f"{pos_unit}/1000"

    # Grid spacing (delta)
    dx = float(grid_system['incAx1'])
    dy = float(grid_system['incAx2'])

    # Number of points per row/column (Ax1cal is rows x cols)
    num_cols = Ax1cal.shape[1]
    num_rows = Ax1cal.shape[0]

    # Offsets (half-extent with the surrounding zero border included)
    # OFFSETROW applies to rows (Y/Axis2), OFFSETCOL applies to columns (X/Axis1)
    offset_row = ((num_rows - 1) / 2.0) * dy
    offset_col = ((num_cols - 1) / 2.0) * dx

    with open(filename, 'w') as f:
        # START2D header lines
        # Literal tokens copied from the provided reference header
        ax2_num = int(grid_system.get('Ax2Num', 0))
        ax1_num = int(grid_system.get('Ax1Num', 0))
        out_axis3 = int(setup.get('OutAxis3', 0))
        out_ax3_value = int(setup.get('OutAx3Value', 0))
        f.write(f":START2D {ax2_num} {ax1_num} {out_axis3} {out_ax3_value} {dx:.3f} {dy:.3f} {num_cols}\n")
        f.write(f":START2D POSUNIT={pos_unit} CORUNIT={cor_unit} OFFSETROW = {offset_row:.3f} OFFSETCOL = {offset_col:.3f}\n")
        f.write("\n")

        # Calibration data: write pairs (Ax1, Ax2) across columns for each row
        for i in range(num_rows):
            line_parts = []
            for j in range(num_cols):
                line_parts.append(f"{Ax1cal[i, j]:.4f}\t{Ax2cal[i, j]:.4f}")
            f.write("\t".join(line_parts) + "\n")

        # Footer
        f.write("\n:END\n")


def write_accuracy_file(filename, X, Y, Ax1Err, Ax2Err, VectorErr, valid_mask, grid_system, setup):
    """Write accuracy verification file"""
    
    with open(filename, 'w') as f:
        # Write header
        f.write('% Multi-Zone 2D Accuracy Calibration Results\n')
        f.write(f'% System: {grid_system["model"]} (S/N: {grid_system["SN"]})\n')
        f.write(f'% Zones processed: {grid_system["zoneCount"]}\n')
        f.write(f'% Grid size: {X.shape[0]} x {X.shape[1]} points\n')
        f.write(f'% Units: {grid_system["UserUnit"]}\n')
        f.write('% Ax1TestLoc Ax2TestLoc Ax1Err Ax2Err VectorErr AvgCount\n')
        
        # Write data for valid points only
        for i in range(X.shape[0]):
            for j in range(X.shape[1]):
                if valid_mask[i, j]:
                    f.write(f'{X[i,j]:.6f}\t{Y[i,j]:.6f}\t{Ax1Err[i,j]:.6f}\t'
                           f'{Ax2Err[i,j]:.6f}\t{VectorErr[i,j]:.6f}\t{grid_system["avgCount"][i,j]:.0f}\n')


if __name__ == "__main__":
    # Test the function with setup from Steps 1-3
    from multizone_step1_setup import multizone_step1_setup
    from multizone_step2_initialize_grid import multizone_step2_initialize_grid
    from multizone_step3_stitch_zones import multizone_step3_stitch_zones
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
    
    # Override filenames for Python version
    python_cal_file = 'stitched_multizone_python.cal'
    python_out_file = 'stitched_multizone_accuracy_python.dat'
    
    try:
        # Step 1: Create setup
        print("=== STEP 1: Setup Configuration ===")
        setup = multizone_step1_setup(num_row, num_col, travel_ax1, travel_ax2, zone_filenames)
        
        # Override with Python-specific filenames
        setup['CalFile'] = python_cal_file
        setup['OutFile'] = python_out_file
        
        # Step 2: Initialize grid system
        print("\n=== STEP 2: Initialize Grid System ===")
        grid_system = multizone_step2_initialize_grid(setup)
        
        # Step 3: Stitch all zones
        print("\n=== STEP 3: Stitch All Zones ===")
        grid_system = multizone_step3_stitch_zones(setup, grid_system)
        
        # Step 4: Finalize calibration
        print("\n=== STEP 4: Finalize Calibration ===")
        final_result = multizone_step4_finalize_calibration(setup, grid_system)
        
        # Save results to text file for comparison
        with open('multizone_step4_output_python.txt', 'w') as f:
            f.write('=== MULTIZONE STEP 4: FINAL CALIBRATION ===\n')
            f.write(f"totalZones: {final_result['totalZones']}\n")
            f.write(f"validPoints: {final_result['validPoints']}\n")
            f.write(f"overlapPoints: {final_result['overlapPoints']}\n")
            f.write(f"gridSize_rows: {final_result['gridSize'][0]}\n")
            f.write(f"gridSize_cols: {final_result['gridSize'][1]}\n")
            f.write(f"pkAx1: {final_result['pkAx1']:.12f}\n")
            f.write(f"pkAx2: {final_result['pkAx2']:.12f}\n")
            f.write(f"pkVector: {final_result['pkVector']:.12f}\n")
            f.write(f"rmsAx1: {final_result['rmsAx1']:.12f}\n")
            f.write(f"rmsAx2: {final_result['rmsAx2']:.12f}\n")
            f.write(f"rmsVector: {final_result['rmsVector']:.12f}\n")
            f.write(f"orthogonality: {final_result['orthogonality']:.12f}\n")
            f.write(f"Ax1Slope: {final_result['Ax1Slope']:.12f}\n")
            f.write(f"Ax2Slope: {final_result['Ax2Slope']:.12f}\n")
            
            # Error ranges
            valid_mask = final_result['validMask']
            f.write(f"Ax1Err_min: {np.min(final_result['Ax1Err'][valid_mask]):.12f}\n")
            f.write(f"Ax1Err_max: {np.max(final_result['Ax1Err'][valid_mask]):.12f}\n")
            f.write(f"Ax2Err_min: {np.min(final_result['Ax2Err'][valid_mask]):.12f}\n")
            f.write(f"Ax2Err_max: {np.max(final_result['Ax2Err'][valid_mask]):.12f}\n")
            f.write(f"VectorErr_min: {np.min(final_result['VectorErr'][valid_mask]):.12f}\n")
            f.write(f"VectorErr_max: {np.max(final_result['VectorErr'][valid_mask]):.12f}\n")
        
        print("=== TEST COMPLETED SUCCESSFULLY ===")
        print("Complete multi-zone calibration pipeline executed")
        print("Results saved to: multizone_step4_output_python.txt")
        
        # Save for comparison with MATLAB
        final_result_save = deepcopy(final_result)
        # Convert numpy arrays to lists/regular types for saving
        keys_to_delete = []
        for key in final_result_save.keys():
            if isinstance(final_result_save[key], np.ndarray):
                if final_result_save[key].size > 100:  # Don't save very large arrays
                    keys_to_delete.append(key)
        
        for key in keys_to_delete:
            del final_result_save[key]
        
        sio.savemat('multizone_step4_output_python.mat', {
            'final_result': final_result_save,
            'setup': setup
        })
        
        print("\n🎉 COMPLETE MULTI-ZONE CALIBRATION PIPELINE SUCCESSFUL!")
        print("✅ All 4 zones processed and stitched")
        print("✅ Final averaging completed") 
        print("✅ Calibration file generated")
        print("✅ Accuracy verification file created")
        
    except Exception as err:
        print('ERROR in multizone_step4_finalize_calibration:')
        print(str(err))
        import traceback
        traceback.print_exc()
