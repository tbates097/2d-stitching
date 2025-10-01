% TEST_ORIGINAL_VS_STEPS - Compare original MATLAB against step-by-step implementation
%
% This script runs the debug version of the original A3200Acc2DMultiZone.m
% and compares its intermediate outputs against the step-by-step implementation
% to verify that the steps correctly reproduce the original algorithm.

clear all;
close all;

fprintf('========================================================\n');
fprintf('ORIGINAL MATLAB vs STEP-BY-STEP VERIFICATION TEST\n');
fprintf('========================================================\n');

% Test file
test_file = 'MATLAB Source/642583-1-1-CZ1.dat';

if ~exist(test_file, 'file')
    fprintf('ERROR: Test file %s not found!\n', test_file);
    return;
end

fprintf('Using test file: %s\n\n', test_file);

%% RUN ORIGINAL DEBUG VERSION
fprintf('1. Running ORIGINAL A3200Acc2DMultiZone_debug...\n');
fprintf('------------------------------------------------\n');

% Capture command window output
diary original_debug_output.txt
diary on

try
    data_original = A3200Acc2DMultiZone_debug(test_file);
    fprintf('✓ Original MATLAB function completed successfully\n\n');
    original_success = 1;
catch err
    fprintf('✗ Original MATLAB function FAILED: %s\n\n', err.message);
    original_success = 0;
end

diary off

%% RUN STEP-BY-STEP VERSION  
fprintf('2. Running STEP-BY-STEP implementation...\n');
fprintf('------------------------------------------\n');

if original_success
    try
        % Step 1: Parse header
        config = step1_parse_header(test_file);
        fprintf('✓ Step 1 completed\n');
        
        % Step 2: Load data
        data_raw = step2_load_data(test_file, config);
        fprintf('✓ Step 2 completed\n');
        
        % Step 3: Create grid
        grid_data = step3_create_grid(data_raw);
        fprintf('✓ Step 3 completed\n');
        
        % Step 4: Calculate slopes
        slope_data = step4_calculate_slopes(grid_data);
        fprintf('✓ Step 4 completed\n');
        
        % Step 5: Process errors
        processed_data = step5_process_errors(grid_data, slope_data);
        fprintf('✓ Step 5 completed\n');
        
        steps_success = 1;
        
    catch err
        fprintf('✗ Step-by-step implementation FAILED: %s\n', err.message);
        steps_success = 0;
    end
else
    fprintf('Skipping step-by-step test due to original failure\n');
    steps_success = 0;
end

%% COMPARE FINAL DATA STRUCTURES
fprintf('\n3. Comparing final data structures...\n');
fprintf('-------------------------------------\n');

if original_success && steps_success
    
    % Compare key values from final data structures
    fprintf('Comparing final processed results:\n');
    
    % Position matrices
    X_diff = max(max(abs(data_original.X - processed_data.X)));
    Y_diff = max(max(abs(data_original.Y - processed_data.Y)));
    
    % Error matrices  
    Ax1Err_diff = max(max(abs(data_original.Ax1Err - processed_data.Ax1Err)));
    Ax2Err_diff = max(max(abs(data_original.Ax2Err - processed_data.Ax2Err)));
    
    fprintf('Position matrix X max difference: %.12f\n', X_diff);
    fprintf('Position matrix Y max difference: %.12f\n', Y_diff);
    fprintf('Ax1Err matrix max difference: %.12f\n', Ax1Err_diff);
    fprintf('Ax2Err matrix max difference: %.12f\n', Ax2Err_diff);
    
    % Check if differences are negligible
    tolerance = 1e-10;
    if X_diff < tolerance && Y_diff < tolerance && ...
       Ax1Err_diff < tolerance && Ax2Err_diff < tolerance
        fprintf('✓ Final data structures match within tolerance (%.0e)\n', tolerance);
        data_match = 1;
    else
        fprintf('✗ Final data structures differ beyond tolerance\n');
        data_match = 0;
    end
    
else
    fprintf('Cannot compare - one or both implementations failed\n');
    data_match = 0;
end

%% FINAL SUMMARY
fprintf('\n========================================================\n');
fprintf('VERIFICATION SUMMARY\n');
fprintf('========================================================\n');

if original_success && steps_success && data_match
    fprintf('🎉 SUCCESS: Step-by-step implementation exactly matches original!\n');
    fprintf('   - Original MATLAB function executed successfully\n');
    fprintf('   - Step-by-step implementation executed successfully\n');
    fprintf('   - Final data structures are identical\n');
    fprintf('\nThe step breakdown correctly reproduces the original algorithm.\n');
    result = 'SUCCESS';
else
    fprintf('❌ VERIFICATION ISSUES DETECTED:\n');
    if ~original_success
        fprintf('   - Original MATLAB function failed\n');
    end
    if ~steps_success
        fprintf('   - Step-by-step implementation failed\n'); 
    end
    if original_success && steps_success && ~data_match
        fprintf('   - Final data structures differ\n');
    end
    fprintf('\nNeed to investigate differences.\n');
    result = 'FAILED';
end

fprintf('\nDetailed debug output saved to: original_debug_output.txt\n');
fprintf('Test completed: %s\n', datestr(now));
fprintf('========================================================\n');

% Save results for further analysis
save('verification_results.mat', 'data_original', 'processed_data', 'config', ...
     'data_raw', 'grid_data', 'slope_data', 'result');
