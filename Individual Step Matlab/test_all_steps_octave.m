% TEST_ALL_STEPS_OCTAVE - Test complete pipeline and generate output files
%
% This script runs the complete accuracy analysis pipeline (Steps 1-5) and
% generates .txt output files for each step that can be compared with Python results

clear all;
close all;

fprintf('=======================================================\n');
fprintf('COMPLETE ACCURACY ANALYSIS PIPELINE TEST\n');
fprintf('=======================================================\n');

% Test file selection
test_file = 'MATLAB Source/642583-1-1-CZ1.dat';

% Check if file exists
if ~exist(test_file, 'file')
    fprintf('ERROR: Test file %s not found!\n', test_file);
    fprintf('Available files in MATLAB Source:\n');
    files = dir('MATLAB Source/*.dat');
    for i = 1:length(files)
        fprintf('  %s\n', files(i).name);
    end
    return;
end

fprintf('Using test file: %s\n\n', test_file);

%% STEP 1: PARSE HEADER
fprintf('STEP 1: Parsing header configuration...\n');
fprintf('----------------------------------------\n');
try
    config = step1_parse_header(test_file);
    
    % Save Step 1 results to text file
    fid = fopen('step1_output_octave.txt', 'w');
    fprintf(fid, '=== STEP 1: HEADER PARSER RESULTS ===\n');
    fprintf(fid, 'SerialNumber: %s\n', config.SN);
    fprintf(fid, 'Ax1Name: %s\n', config.Ax1Name);
    fprintf(fid, 'Ax1Num: %d\n', config.Ax1Num);
    fprintf(fid, 'Ax1Sign: %d\n', config.Ax1Sign);
    fprintf(fid, 'Ax1Gantry: %d\n', config.Ax1Gantry);
    fprintf(fid, 'Ax2Name: %s\n', config.Ax2Name);
    fprintf(fid, 'Ax2Num: %d\n', config.Ax2Num);
    fprintf(fid, 'Ax2Sign: %d\n', config.Ax2Sign);
    fprintf(fid, 'Ax2Gantry: %d\n', config.Ax2Gantry);
    fprintf(fid, 'UserUnit: %s\n', config.UserUnit);
    fprintf(fid, 'calDivisor: %d\n', config.calDivisor);
    fprintf(fid, 'posUnit: %s\n', config.posUnit);
    fprintf(fid, 'errUnit: %s\n', config.errUnit);
    fprintf(fid, 'operator: %s\n', config.operator);
    fprintf(fid, 'model: %s\n', config.model);
    fprintf(fid, 'airTemp: %s\n', config.airTemp);
    fprintf(fid, 'matTemp: %s\n', config.matTemp);
    fprintf(fid, 'expandCoef: %s\n', config.expandCoef);
    fprintf(fid, 'comment: %s\n', config.comment);
    fprintf(fid, 'fileDate: %s\n', config.fileDate);
    fclose(fid);
    
    fprintf('✓ Step 1 completed successfully\n');
    fprintf('  Results saved to: step1_output_octave.txt\n\n');
    
catch err
    fprintf('✗ Step 1 FAILED: %s\n', err.message);
    return;
end

%% STEP 2: LOAD DATA
fprintf('STEP 2: Loading raw measurement data...\n');
fprintf('---------------------------------------\n');
try
    data_raw = step2_load_data(test_file, config);
    
    % Save Step 2 results to text file
    fid = fopen('step2_output_octave.txt', 'w');
    fprintf(fid, '=== STEP 2: RAW DATA LOADER RESULTS ===\n');
    fprintf(fid, 'NumAx1Points: %d\n', data_raw.NumAx1Points);
    fprintf(fid, 'NumAx2Points: %d\n', data_raw.NumAx2Points);
    fprintf(fid, 'TotalDataPoints: %d\n', data_raw.NumAx1Points * data_raw.NumAx2Points);
    fprintf(fid, 'Ax1MoveDist: %.6f\n', data_raw.Ax1MoveDist);
    fprintf(fid, 'Ax2MoveDist: %.6f\n', data_raw.Ax2MoveDist);
    fprintf(fid, 'Ax1SampDist: %.6f\n', data_raw.Ax1SampDist);
    fprintf(fid, 'Ax2SampDist: %.6f\n', data_raw.Ax2SampDist);
    fprintf(fid, 'Ax1Pos_min: %.6f\n', min(data_raw.Ax1Pos));
    fprintf(fid, 'Ax1Pos_max: %.6f\n', max(data_raw.Ax1Pos));
    fprintf(fid, 'Ax2Pos_min: %.6f\n', min(data_raw.Ax2Pos));
    fprintf(fid, 'Ax2Pos_max: %.6f\n', max(data_raw.Ax2Pos));
    fprintf(fid, 'Ax1RelErr_um_min: %.6f\n', min(data_raw.Ax1RelErr_um));
    fprintf(fid, 'Ax1RelErr_um_max: %.6f\n', max(data_raw.Ax1RelErr_um));
    fprintf(fid, 'Ax2RelErr_um_min: %.6f\n', min(data_raw.Ax2RelErr_um));
    fprintf(fid, 'Ax2RelErr_um_max: %.6f\n', max(data_raw.Ax2RelErr_um));
    fclose(fid);
    
    fprintf('✓ Step 2 completed successfully\n');
    fprintf('  Results saved to: step2_output_octave.txt\n\n');
    
catch err
    fprintf('✗ Step 2 FAILED: %s\n', err.message);
    return;
end

%% STEP 3: CREATE GRID
fprintf('STEP 3: Creating 2D interpolated grid...\n');
fprintf('----------------------------------------\n');
try
    grid_data = step3_create_grid(data_raw);
    
    % Save Step 3 results to text file
    fid = fopen('step3_output_octave.txt', 'w');
    fprintf(fid, '=== STEP 3: GRID CREATOR RESULTS ===\n');
    fprintf(fid, 'GridSize_rows: %d\n', grid_data.SizeGrid(1));
    fprintf(fid, 'GridSize_cols: %d\n', grid_data.SizeGrid(2));
    fprintf(fid, 'X_min: %.6f\n', min(min(grid_data.X)));
    fprintf(fid, 'X_max: %.6f\n', max(max(grid_data.X)));
    fprintf(fid, 'Y_min: %.6f\n', min(min(grid_data.Y)));
    fprintf(fid, 'Y_max: %.6f\n', max(max(grid_data.Y)));
    fprintf(fid, 'Ax1Err_min: %.6f\n', min(min(grid_data.Ax1Err)));
    fprintf(fid, 'Ax1Err_max: %.6f\n', max(max(grid_data.Ax1Err)));
    fprintf(fid, 'Ax2Err_min: %.6f\n', min(min(grid_data.Ax2Err)));
    fprintf(fid, 'Ax2Err_max: %.6f\n', max(max(grid_data.Ax2Err)));
    fprintf(fid, 'maxAx1: %.6f\n', grid_data.maxAx1);
    fprintf(fid, 'maxAx2: %.6f\n', grid_data.maxAx2);
    fprintf(fid, 'NaN_count_Ax1: %d\n', sum(sum(isnan(grid_data.Ax1Err))));
    fprintf(fid, 'NaN_count_Ax2: %d\n', sum(sum(isnan(grid_data.Ax2Err))));
    fclose(fid);
    
    fprintf('✓ Step 3 completed successfully\n');
    fprintf('  Results saved to: step3_output_octave.txt\n\n');
    
catch err
    fprintf('✗ Step 3 FAILED: %s\n', err.message);
    return;
end

%% STEP 4: CALCULATE SLOPES
fprintf('STEP 4: Calculating straightness slopes...\n');
fprintf('------------------------------------------\n');
try
    slope_data = step4_calculate_slopes(grid_data);
    
    % Save Step 4 results to text file
    fid = fopen('step4_output_octave.txt', 'w');
    fprintf(fid, '=== STEP 4: SLOPE CALCULATOR RESULTS ===\n');
    fprintf(fid, 'Ax1Coef_slope: %.12f\n', slope_data.Ax1Coef(1));
    fprintf(fid, 'Ax1Coef_offset: %.12f\n', slope_data.Ax1Coef(2));
    fprintf(fid, 'Ax2Coef_slope: %.12f\n', slope_data.Ax2Coef(1));
    fprintf(fid, 'Ax2Coef_offset: %.12f\n', slope_data.Ax2Coef(2));
    fprintf(fid, 'orthog_arcsec: %.12f\n', slope_data.orthog);
    fprintf(fid, 'y_meas_dir: %d\n', slope_data.y_meas_dir);
    fprintf(fid, 'Ax1Line_min: %.12f\n', min(slope_data.Ax1Line));
    fprintf(fid, 'Ax1Line_max: %.12f\n', max(slope_data.Ax1Line));
    fprintf(fid, 'Ax2Line_min: %.12f\n', min(slope_data.Ax2Line));
    fprintf(fid, 'Ax2Line_max: %.12f\n', max(slope_data.Ax2Line));
    fprintf(fid, 'Ax1Orthog_std: %.12f\n', std(slope_data.Ax1Orthog));
    fprintf(fid, 'Ax2Orthog_std: %.12f\n', std(slope_data.Ax2Orthog));
    fprintf(fid, 'mean_ax1_err_min: %.12f\n', min(slope_data.mean_ax1_err));
    fprintf(fid, 'mean_ax1_err_max: %.12f\n', max(slope_data.mean_ax1_err));
    fprintf(fid, 'mean_ax2_err_min: %.12f\n', min(slope_data.mean_ax2_err));
    fprintf(fid, 'mean_ax2_err_max: %.12f\n', max(slope_data.mean_ax2_err));
    fclose(fid);
    
    fprintf('✓ Step 4 completed successfully\n');
    fprintf('  Results saved to: step4_output_octave.txt\n\n');
    
catch err
    fprintf('✗ Step 4 FAILED: %s\n', err.message);
    return;
end

%% STEP 5: PROCESS ERRORS
fprintf('STEP 5: Processing final accuracy errors...\n');
fprintf('-------------------------------------------\n');
try
    processed_data = step5_process_errors(grid_data, slope_data);
    
    % Save Step 5 results to text file
    fid = fopen('step5_output_octave.txt', 'w');
    fprintf(fid, '=== STEP 5: ERROR PROCESSOR RESULTS ===\n');
    fprintf(fid, 'Ax1Err_min: %.12f\n', min(min(processed_data.Ax1Err)));
    fprintf(fid, 'Ax1Err_max: %.12f\n', max(max(processed_data.Ax1Err)));
    fprintf(fid, 'Ax2Err_min: %.12f\n', min(min(processed_data.Ax2Err)));
    fprintf(fid, 'Ax2Err_max: %.12f\n', max(max(processed_data.Ax2Err)));
    fprintf(fid, 'VectorErr_min: %.12f\n', min(min(processed_data.VectorErr)));
    fprintf(fid, 'VectorErr_max: %.12f\n', max(max(processed_data.VectorErr)));
    fprintf(fid, 'pkAx1: %.12f\n', processed_data.pkAx1);
    fprintf(fid, 'pkAx2: %.12f\n', processed_data.pkAx2);
    fprintf(fid, 'maxVectorErr: %.12f\n', processed_data.maxVectorErr);
    fprintf(fid, 'rmsAx1: %.12f\n', processed_data.rmsAx1);
    fprintf(fid, 'rmsAx2: %.12f\n', processed_data.rmsAx2);
    fprintf(fid, 'rmsVector: %.12f\n', processed_data.rmsVector);
    fprintf(fid, 'Ax1amplitude: %.12f\n', processed_data.Ax1amplitude);
    fprintf(fid, 'Ax2amplitude: %.12f\n', processed_data.Ax2amplitude);
    fprintf(fid, 'orthog_arcsec: %.12f\n', processed_data.slope_data.orthog);
    fclose(fid);
    
    fprintf('✓ Step 5 completed successfully\n');
    fprintf('  Results saved to: step5_output_octave.txt\n\n');
    
catch err
    fprintf('✗ Step 5 FAILED: %s\n', err.message);
    return;
end

%% SUMMARY
fprintf('=======================================================\n');
fprintf('PIPELINE COMPLETED SUCCESSFULLY!\n');
fprintf('=======================================================\n');
fprintf('Generated output files:\n');
fprintf('  step1_output_octave.txt - Header configuration\n');
fprintf('  step2_output_octave.txt - Raw data summary\n');
fprintf('  step3_output_octave.txt - Grid interpolation results\n');
fprintf('  step4_output_octave.txt - Slope calculation results\n');
fprintf('  step5_output_octave.txt - Final accuracy results\n');
fprintf('\n');

fprintf('FINAL ACCURACY SUMMARY:\n');
fprintf('  System: %s (S/N: %s)\n', config.model, config.SN);
fprintf('  %s Direction: ±%.3f μm (RMS: %.3f μm)\n', config.Ax1Name, processed_data.Ax1amplitude, processed_data.rmsAx1);
fprintf('  %s Direction: ±%.3f μm (RMS: %.3f μm)\n', config.Ax2Name, processed_data.Ax2amplitude, processed_data.rmsAx2);
fprintf('  Vector Sum: %.3f μm max (RMS: %.3f μm)\n', processed_data.maxVectorErr, processed_data.rmsVector);
fprintf('  Orthogonality: %.3f arc-seconds\n', processed_data.slope_data.orthog);
fprintf('\nTest completed: %s\n', datestr(now));
fprintf('=======================================================\n');

% Save final data to .mat file for further analysis if needed
save('complete_pipeline_octave.mat', 'config', 'data_raw', 'grid_data', 'slope_data', 'processed_data');
fprintf('All data saved to: complete_pipeline_octave.mat\n');
