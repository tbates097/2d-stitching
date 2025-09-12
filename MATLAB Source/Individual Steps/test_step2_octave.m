% TEST_STEP2_OCTAVE - Test the data loader with actual data file
%
% This script tests step2_load_data.m with one of the existing data files

clear all;
close all;

fprintf('Testing Step 2: Data Loader\n');
fprintf('===========================\n');

% Test file
test_file = 'MATLAB Source/642583-1-1-CZ1.dat';

% Check if file exists
if ~exist(test_file, 'file')
    fprintf('Test file %s not found!\n', test_file);
    return;
end

try
    % First get the configuration (Step 1)
    fprintf('Step 1: Loading configuration...\n');
    config = step1_parse_header(test_file);
    
    % Then load the raw data (Step 2)
    fprintf('Step 2: Loading raw data...\n');
    data_raw = step2_load_data(test_file, config);
    
    % Verify the structure contains expected fields
    expected_fields = {'Ax1TestLoc', 'Ax2TestLoc', 'Ax1PosCmd', 'Ax2PosCmd', ...
                      'Ax1RelErr', 'Ax2RelErr', 'Ax1RelErr_um', 'Ax2RelErr_um', ...
                      'NumAx1Points', 'NumAx2Points', 'Ax1MoveDist', 'Ax2MoveDist', ...
                      'Ax1SampDist', 'Ax2SampDist', 'Ax1Pos', 'Ax2Pos'};
    
    fprintf('Checking for expected fields...\n');
    missing_fields = 0;
    for i = 1:length(expected_fields)
        if isfield(data_raw, expected_fields{i})
            fprintf('✓ %s: Present\n', expected_fields{i});
        else
            fprintf('✗ %s: Missing\n', expected_fields{i});
            missing_fields = missing_fields + 1;
        end
    end
    
    if missing_fields == 0
        fprintf('\n=== TEST COMPLETED SUCCESSFULLY ===\n');
        fprintf('Raw data structure saved as ''data_raw_step2'' and ''config_step2''\n');
        
        % Save the results for comparison with Python
        data_raw_step2 = data_raw;
        config_step2 = config;
        save('step2_output.mat', 'data_raw_step2', 'config_step2');
    else
        fprintf('\n=== TEST FAILED ===\n');
        fprintf('%d fields missing from data structure\n', missing_fields);
    end
    
catch err
    fprintf('ERROR in step2_load_data:\n');
    fprintf('%s\n', err.message);
end
