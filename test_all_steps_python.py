#!/usr/bin/env python3
"""
TEST_ALL_STEPS_PYTHON - Test complete pipeline and generate output files

This script runs the complete accuracy analysis pipeline (Steps 1-5) and
generates .txt output files for each step that can be compared with Octave results
"""

import os
import numpy as np
import scipy.io as sio
from datetime import datetime

# Import all step functions
from step1_parse_header import step1_parse_header
from step2_load_data import step2_load_data
from step3_create_grid import step3_create_grid
from step4_calculate_slopes import step4_calculate_slopes
from step5_process_errors import step5_process_errors


def main():
    print('=' * 55)
    print('COMPLETE ACCURACY ANALYSIS PIPELINE TEST')
    print('=' * 55)
    
    # Test file selection
    test_file = 'MATLAB Source/642583-1-1-CZ1.dat'
    
    # Check if file exists
    if not os.path.exists(test_file):
        print(f'ERROR: Test file {test_file} not found!')
        matlab_dir = 'MATLAB Source'
        if os.path.exists(matlab_dir):
            print('Available files in MATLAB Source:')
            for f in os.listdir(matlab_dir):
                if f.endswith('.dat'):
                    print(f'  {f}')
        return False
    
    print(f'Using test file: {test_file}\n')
    
    ## STEP 1: PARSE HEADER
    print('STEP 1: Parsing header configuration...')
    print('-' * 40)
    try:
        config = step1_parse_header(test_file)
        
        # Save Step 1 results to text file
        with open('step1_output_python.txt', 'w') as f:
            f.write('=== STEP 1: HEADER PARSER RESULTS ===\n')
            f.write(f"SerialNumber: {config.get('SN', '')}\n")
            f.write(f"Ax1Name: {config.get('Ax1Name', '')}\n")
            f.write(f"Ax1Num: {config.get('Ax1Num', 0)}\n")
            f.write(f"Ax1Sign: {config.get('Ax1Sign', 0)}\n")
            f.write(f"Ax1Gantry: {config.get('Ax1Gantry', 0)}\n")
            f.write(f"Ax2Name: {config.get('Ax2Name', '')}\n")
            f.write(f"Ax2Num: {config.get('Ax2Num', 0)}\n")
            f.write(f"Ax2Sign: {config.get('Ax2Sign', 0)}\n")
            f.write(f"Ax2Gantry: {config.get('Ax2Gantry', 0)}\n")
            f.write(f"UserUnit: {config.get('UserUnit', '')}\n")
            f.write(f"calDivisor: {config.get('calDivisor', 0)}\n")
            f.write(f"posUnit: {config.get('posUnit', '')}\n")
            f.write(f"errUnit: {config.get('errUnit', '')}\n")
            f.write(f"operator: {config.get('operator', '')}\n")
            f.write(f"model: {config.get('model', '')}\n")
            f.write(f"airTemp: {config.get('airTemp', '')}\n")
            f.write(f"matTemp: {config.get('matTemp', '')}\n")
            f.write(f"expandCoef: {config.get('expandCoef', '')}\n")
            f.write(f"comment: {config.get('comment', '')}\n")
            f.write(f"fileDate: {config.get('fileDate', '')}\n")
        
        print('✓ Step 1 completed successfully')
        print('  Results saved to: step1_output_python.txt\n')
        
    except Exception as err:
        print(f'✗ Step 1 FAILED: {err}')
        return False
    
    ## STEP 2: LOAD DATA
    print('STEP 2: Loading raw measurement data...')
    print('-' * 39)
    try:
        data_raw = step2_load_data(test_file, config)
        
        # Save Step 2 results to text file
        with open('step2_output_python.txt', 'w') as f:
            f.write('=== STEP 2: RAW DATA LOADER RESULTS ===\n')
            f.write(f"NumAx1Points: {data_raw['NumAx1Points']}\n")
            f.write(f"NumAx2Points: {data_raw['NumAx2Points']}\n")
            f.write(f"TotalDataPoints: {data_raw['NumAx1Points'] * data_raw['NumAx2Points']}\n")
            f.write(f"Ax1MoveDist: {data_raw['Ax1MoveDist']:.6f}\n")
            f.write(f"Ax2MoveDist: {data_raw['Ax2MoveDist']:.6f}\n")
            f.write(f"Ax1SampDist: {data_raw['Ax1SampDist']:.6f}\n")
            f.write(f"Ax2SampDist: {data_raw['Ax2SampDist']:.6f}\n")
            f.write(f"Ax1Pos_min: {np.min(data_raw['Ax1Pos']):.6f}\n")
            f.write(f"Ax1Pos_max: {np.max(data_raw['Ax1Pos']):.6f}\n")
            f.write(f"Ax2Pos_min: {np.min(data_raw['Ax2Pos']):.6f}\n")
            f.write(f"Ax2Pos_max: {np.max(data_raw['Ax2Pos']):.6f}\n")
            f.write(f"Ax1RelErr_um_min: {np.min(data_raw['Ax1RelErr_um']):.6f}\n")
            f.write(f"Ax1RelErr_um_max: {np.max(data_raw['Ax1RelErr_um']):.6f}\n")
            f.write(f"Ax2RelErr_um_min: {np.min(data_raw['Ax2RelErr_um']):.6f}\n")
            f.write(f"Ax2RelErr_um_max: {np.max(data_raw['Ax2RelErr_um']):.6f}\n")
        
        print('✓ Step 2 completed successfully')
        print('  Results saved to: step2_output_python.txt\n')
        
    except Exception as err:
        print(f'✗ Step 2 FAILED: {err}')
        return False
    
    ## STEP 3: CREATE GRID
    print('STEP 3: Creating 2D interpolated grid...')
    print('-' * 40)
    try:
        grid_data = step3_create_grid(data_raw)
        
        # Save Step 3 results to text file
        with open('step3_output_python.txt', 'w') as f:
            f.write('=== STEP 3: GRID CREATOR RESULTS ===\n')
            f.write(f"GridSize_rows: {grid_data['SizeGrid'][0]}\n")
            f.write(f"GridSize_cols: {grid_data['SizeGrid'][1]}\n")
            f.write(f"X_min: {np.min(grid_data['X']):.6f}\n")
            f.write(f"X_max: {np.max(grid_data['X']):.6f}\n")
            f.write(f"Y_min: {np.min(grid_data['Y']):.6f}\n")
            f.write(f"Y_max: {np.max(grid_data['Y']):.6f}\n")
            f.write(f"Ax1Err_min: {np.min(grid_data['Ax1Err']):.6f}\n")
            f.write(f"Ax1Err_max: {np.max(grid_data['Ax1Err']):.6f}\n")
            f.write(f"Ax2Err_min: {np.min(grid_data['Ax2Err']):.6f}\n")
            f.write(f"Ax2Err_max: {np.max(grid_data['Ax2Err']):.6f}\n")
            f.write(f"maxAx1: {grid_data['maxAx1']:.6f}\n")
            f.write(f"maxAx2: {grid_data['maxAx2']:.6f}\n")
            f.write(f"NaN_count_Ax1: {np.sum(np.isnan(grid_data['Ax1Err']))}\n")
            f.write(f"NaN_count_Ax2: {np.sum(np.isnan(grid_data['Ax2Err']))}\n")
        
        print('✓ Step 3 completed successfully')
        print('  Results saved to: step3_output_python.txt\n')
        
    except Exception as err:
        print(f'✗ Step 3 FAILED: {err}')
        import traceback
        traceback.print_exc()
        return False
    
    ## STEP 4: CALCULATE SLOPES
    print('STEP 4: Calculating straightness slopes...')
    print('-' * 42)
    try:
        slope_data = step4_calculate_slopes(grid_data)
        
        # Save Step 4 results to text file
        with open('step4_output_python.txt', 'w') as f:
            f.write('=== STEP 4: SLOPE CALCULATOR RESULTS ===\n')
            f.write(f"Ax1Coef_slope: {slope_data['Ax1Coef'][0]:.12f}\n")
            f.write(f"Ax1Coef_offset: {slope_data['Ax1Coef'][1]:.12f}\n")
            f.write(f"Ax2Coef_slope: {slope_data['Ax2Coef'][0]:.12f}\n")
            f.write(f"Ax2Coef_offset: {slope_data['Ax2Coef'][1]:.12f}\n")
            f.write(f"orthog_arcsec: {slope_data['orthog']:.12f}\n")
            f.write(f"y_meas_dir: {slope_data['y_meas_dir']}\n")
            f.write(f"Ax1Line_min: {np.min(slope_data['Ax1Line']):.12f}\n")
            f.write(f"Ax1Line_max: {np.max(slope_data['Ax1Line']):.12f}\n")
            f.write(f"Ax2Line_min: {np.min(slope_data['Ax2Line']):.12f}\n")
            f.write(f"Ax2Line_max: {np.max(slope_data['Ax2Line']):.12f}\n")
            f.write(f"Ax1Orthog_std: {np.std(slope_data['Ax1Orthog']):.12f}\n")
            f.write(f"Ax2Orthog_std: {np.std(slope_data['Ax2Orthog']):.12f}\n")
            f.write(f"mean_ax1_err_min: {np.min(slope_data['mean_ax1_err']):.12f}\n")
            f.write(f"mean_ax1_err_max: {np.max(slope_data['mean_ax1_err']):.12f}\n")
            f.write(f"mean_ax2_err_min: {np.min(slope_data['mean_ax2_err']):.12f}\n")
            f.write(f"mean_ax2_err_max: {np.max(slope_data['mean_ax2_err']):.12f}\n")
        
        print('✓ Step 4 completed successfully')
        print('  Results saved to: step4_output_python.txt\n')
        
    except Exception as err:
        print(f'✗ Step 4 FAILED: {err}')
        import traceback
        traceback.print_exc()
        return False
    
    ## STEP 5: PROCESS ERRORS
    print('STEP 5: Processing final accuracy errors...')
    print('-' * 43)
    try:
        processed_data = step5_process_errors(grid_data, slope_data)
        
        # Save Step 5 results to text file
        with open('step5_output_python.txt', 'w') as f:
            f.write('=== STEP 5: ERROR PROCESSOR RESULTS ===\n')
            f.write(f"Ax1Err_min: {np.min(processed_data['Ax1Err']):.12f}\n")
            f.write(f"Ax1Err_max: {np.max(processed_data['Ax1Err']):.12f}\n")
            f.write(f"Ax2Err_min: {np.min(processed_data['Ax2Err']):.12f}\n")
            f.write(f"Ax2Err_max: {np.max(processed_data['Ax2Err']):.12f}\n")
            f.write(f"VectorErr_min: {np.min(processed_data['VectorErr']):.12f}\n")
            f.write(f"VectorErr_max: {np.max(processed_data['VectorErr']):.12f}\n")
            f.write(f"pkAx1: {processed_data['pkAx1']:.12f}\n")
            f.write(f"pkAx2: {processed_data['pkAx2']:.12f}\n")
            f.write(f"maxVectorErr: {processed_data['maxVectorErr']:.12f}\n")
            f.write(f"rmsAx1: {processed_data['rmsAx1']:.12f}\n")
            f.write(f"rmsAx2: {processed_data['rmsAx2']:.12f}\n")
            f.write(f"rmsVector: {processed_data['rmsVector']:.12f}\n")
            f.write(f"Ax1amplitude: {processed_data['Ax1amplitude']:.12f}\n")
            f.write(f"Ax2amplitude: {processed_data['Ax2amplitude']:.12f}\n")
            f.write(f"orthog_arcsec: {processed_data['slope_data']['orthog']:.12f}\n")
        
        print('✓ Step 5 completed successfully')
        print('  Results saved to: step5_output_python.txt\n')
        
    except Exception as err:
        print(f'✗ Step 5 FAILED: {err}')
        import traceback
        traceback.print_exc()
        return False
    
    ## SUMMARY
    print('=' * 55)
    print('PIPELINE COMPLETED SUCCESSFULLY!')
    print('=' * 55)
    print('Generated output files:')
    print('  step1_output_python.txt - Header configuration')
    print('  step2_output_python.txt - Raw data summary')
    print('  step3_output_python.txt - Grid interpolation results')
    print('  step4_output_python.txt - Slope calculation results')
    print('  step5_output_python.txt - Final accuracy results')
    print()
    
    print('FINAL ACCURACY SUMMARY:')
    print(f"  System: {config.get('model', 'Unknown')} (S/N: {config.get('SN', 'Unknown')})")
    print(f"  {config.get('Ax1Name', 'Ax1')} Direction: ±{processed_data['Ax1amplitude']:.3f} μm (RMS: {processed_data['rmsAx1']:.3f} μm)")
    print(f"  {config.get('Ax2Name', 'Ax2')} Direction: ±{processed_data['Ax2amplitude']:.3f} μm (RMS: {processed_data['rmsAx2']:.3f} μm)")
    print(f"  Vector Sum: {processed_data['maxVectorErr']:.3f} μm max (RMS: {processed_data['rmsVector']:.3f} μm)")
    print(f"  Orthogonality: {processed_data['slope_data']['orthog']:.3f} arc-seconds")
    print(f"\nTest completed: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print('=' * 55)
    
    # Save final data to .mat file for further analysis if needed
    sio.savemat('complete_pipeline_python.mat', {
        'config': config,
        'data_raw': data_raw,
        'grid_data': grid_data,
        'slope_data': slope_data,
        'processed_data': processed_data
    })
    print('All data saved to: complete_pipeline_python.mat')
    
    return True


if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)
