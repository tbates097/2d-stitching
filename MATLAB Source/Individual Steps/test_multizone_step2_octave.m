% TEST_MULTIZONE_STEP2_OCTAVE - Test multi-zone grid system initialization
%
% This script tests the multi-zone grid initialization step with the same
% parameters used in Python for comparison

clear all;
close all;

fprintf('Testing Multi-Zone Step 2: Grid System Initialization\n');
fprintf('======================================================\n');

% Use same configuration as 642583 test data  
numRow = 2;
numCol = 2;
travelAx1 = [-250/25.4, 250/25.4];  % Convert from mm to inches (500mm range)
travelAx2 = [-250/25.4, 250/25.4];  % Convert from mm to inches (500mm range)

% Zone filenames - using all available test files in a 2x2 layout
zone_filenames = cell(numRow, numCol);
zone_filenames{1,1} = 'MATLAB Source/642583-1-1-CZ1.dat';  % Row 1, Col 1
zone_filenames{1,2} = 'MATLAB Source/642583-1-1-CZ2.dat';  % Row 1, Col 2
zone_filenames{2,1} = 'MATLAB Source/642583-1-1-CZ3.dat';  % Row 2, Col 1
zone_filenames{2,2} = 'MATLAB Source/642583-1-1-CZ4.dat';  % Row 2, Col 2

try
    % Step 1: Create setup configuration
    fprintf('Step 1: Creating setup configuration...\n');
    setup = multizone_step1_setup(numRow, numCol, travelAx1, travelAx2, zone_filenames);
    
    % Step 2: Initialize grid system
    fprintf('Step 2: Initializing grid system...\n');
    grid_system = multizone_step2_initialize_grid(setup, []);
    
    % Verify the structure contains expected fields
    expected_fields = {'Ax1Master', 'Ax2Master', 'Ax1MasErr', 'Ax2MasErr', ...
                      'rowAx1Master', 'rowAx2Master', 'rowAx1MasErr', 'rowAx2MasErr', ...
                      'SN', 'Ax1Name', 'Ax2Name', 'model', 'operator', ...
                      'incAx1', 'incAx2', 'X', 'Y', 'Ax1Err', 'Ax2Err', 'avgCount', ...
                      'fullGridSize', 'Ax1size', 'Ax2size', 'zoneCount', ...
                      'airTemp', 'matTemp', 'comment', 'fileDate'};
    
    fprintf('Checking for expected fields...\n');
    missing_fields = 0;
    for i = 1:length(expected_fields)
        if isfield(grid_system, expected_fields{i})
            fprintf('✓ %s: Present\n', expected_fields{i});
        else
            fprintf('✗ %s: Missing\n', expected_fields{i});
            missing_fields = missing_fields + 1;
        end
    end
    
    % Save grid system results to text file for comparison
    fid = fopen('multizone_step2_output_octave.txt', 'w');
    fprintf(fid, '=== MULTIZONE STEP 2: GRID INITIALIZATION ===\n');
    fprintf(fid, 'SN: %s\n', grid_system.SN);
    fprintf(fid, 'Ax1Name: %s\n', grid_system.Ax1Name);
    fprintf(fid, 'Ax2Name: %s\n', grid_system.Ax2Name);
    fprintf(fid, 'model: %s\n', grid_system.model);
    fprintf(fid, 'operator: %s\n', grid_system.operator);
    fprintf(fid, 'incAx1: %.12f\n', grid_system.incAx1);
    fprintf(fid, 'incAx2: %.12f\n', grid_system.incAx2);
    fprintf(fid, 'fullGridSize_rows: %d\n', grid_system.fullGridSize(1));
    fprintf(fid, 'fullGridSize_cols: %d\n', grid_system.fullGridSize(2));
    fprintf(fid, 'Ax1size_rows: %d\n', grid_system.Ax1size(1));
    fprintf(fid, 'Ax1size_cols: %d\n', grid_system.Ax1size(2));
    fprintf(fid, 'zoneCount: %d\n', grid_system.zoneCount);
    fprintf(fid, 'nonZeroPoints: %d\n', sum(sum(grid_system.avgCount > 0)));
    fprintf(fid, 'Ax1Master_min: %.12f\n', min(min(grid_system.Ax1Master)));
    fprintf(fid, 'Ax1Master_max: %.12f\n', max(max(grid_system.Ax1Master)));
    fprintf(fid, 'Ax2Master_min: %.12f\n', min(min(grid_system.Ax2Master)));
    fprintf(fid, 'Ax2Master_max: %.12f\n', max(max(grid_system.Ax2Master)));
    fprintf(fid, 'Ax1MasErr_min: %.12f\n', min(min(grid_system.Ax1MasErr)));
    fprintf(fid, 'Ax1MasErr_max: %.12f\n', max(max(grid_system.Ax1MasErr)));
    fprintf(fid, 'Ax2MasErr_min: %.12f\n', min(min(grid_system.Ax2MasErr)));
    fprintf(fid, 'Ax2MasErr_max: %.12f\n', max(max(grid_system.Ax2MasErr)));
    fprintf(fid, 'airTemp_zone1: %.6f\n', grid_system.airTemp(1));
    fprintf(fid, 'matTemp_zone1: %.6f\n', grid_system.matTemp(1));
    fclose(fid);
    
    if missing_fields == 0
        fprintf('\n=== TEST COMPLETED SUCCESSFULLY ===\n');
        fprintf('Grid system initialized and first zone processed\n');
        fprintf('Results saved to: multizone_step2_output_octave.txt\n');
        
        % Save the results for comparison with Python
        grid_system_step2 = grid_system;
        setup_step2 = setup;
        save('multizone_step2_output_octave.mat', 'grid_system_step2', 'setup_step2');
        
        % Display key metrics
        fprintf('\nKEY METRICS:\n');
        fprintf('  Full grid: %d x %d points\n', grid_system.fullGridSize(1), grid_system.fullGridSize(2));
        fprintf('  First zone: %d x %d points\n', grid_system.Ax1size(1), grid_system.Ax1size(2));
        fprintf('  Grid increments: %.6f x %.6f\n', grid_system.incAx1, grid_system.incAx2);
        fprintf('  Non-zero points: %d\n', sum(sum(grid_system.avgCount > 0)));
        
    else
        fprintf('\n=== TEST FAILED ===\n');
        fprintf('%d fields missing from grid system structure\n', missing_fields);
    end
    
catch err
    fprintf('ERROR in multizone_step2_initialize_grid:\n');
    fprintf('%s\n', err.message);
    fprintf('Stack trace:\n');
    for i = 1:length(err.stack)
        fprintf('  %s at line %d\n', err.stack(i).name, err.stack(i).line);
    end
end
