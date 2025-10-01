% TEST_STEP1_OCTAVE - Test the header parser with actual data file
%
% This script tests step1_parse_header.m with one of the existing data files

clear all;
close all;

fprintf('Testing Step 1: Header Parser\n');
fprintf('=============================\n');

% Test with the zone data file
test_file = 'MATLAB Source/642583-1-1-CZ1.dat';

% Check if file exists
if ~exist(test_file, 'file')
    fprintf('Test file %s not found!\n', test_file);
    fprintf('Looking for available .dat files in MATLAB Source directory...\n');
    
    % Look for .dat files in MATLAB Source
    dat_files = dir('MATLAB Source/*.dat');
    if ~isempty(dat_files)
        test_file = fullfile('MATLAB Source', dat_files(1).name);
        fprintf('Found data file: %s\n', test_file);
    else
        fprintf('No .dat files found. Please provide a data file to test with.\n');
        return;
    end
end

try
    % Test the header parser
    config = step1_parse_header(test_file);
    
    % Verify the structure contains expected fields
    expected_fields = {'SN', 'Ax1Name', 'Ax1Num', 'Ax1Sign', 'Ax1Gantry', ...
                      'Ax2Name', 'Ax2Num', 'Ax2Sign', 'Ax2Gantry', ...
                      'UserUnit', 'calDivisor', 'posUnit', 'errUnit', ...
                      'operator', 'model', 'airTemp', 'matTemp', ...
                      'expandCoef', 'comment', 'fileDate'};
    
    fprintf('Checking for expected fields...\n');
    for i = 1:length(expected_fields)
        if isfield(config, expected_fields{i})
            fprintf('✓ %s: Present\n', expected_fields{i});
        else
            fprintf('✗ %s: Missing\n', expected_fields{i});
        end
    end
    
    fprintf('\n=== TEST COMPLETED SUCCESSFULLY ===\n');
    fprintf('Config structure saved as ''config_step1''\n');
    
    % Save the result for comparison with Python
    config_step1 = config;
    save('step1_output.mat', 'config_step1');
    
catch err
    fprintf('ERROR in step1_parse_header:\n');
    fprintf('%s\n', err.message);
end
