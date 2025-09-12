% TEST_MULTIZONE_STEP3_OCTAVE - Test multi-zone stitching algorithm
%
% This script tests the complete multi-zone processing pipeline through Step 3

clear all;
close all;

fprintf('Testing Multi-Zone Step 3: Zone Stitching Algorithm\n');
fprintf('===================================================\n');

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
    
    % Step 3: Stitch all zones
    fprintf('Step 3: Stitching all zones...\n');
    grid_system = multizone_step3_stitch_zones(setup, grid_system);
    
    % Verify the final structure contains expected data
    fprintf('Checking final grid system...\n');
    
    % Save stitching results to text file for comparison
    fid = fopen('multizone_step3_output_octave.txt', 'w');
    fprintf(fid, '=== MULTIZONE STEP 3: ZONE STITCHING ===\n');
    fprintf(fid, 'totalZones: %d\n', grid_system.zoneCount);
    fprintf(fid, 'nonZeroPoints: %d\n', sum(sum(grid_system.avgCount > 0)));
    fprintf(fid, 'maxAvgCount: %d\n', max(max(grid_system.avgCount)));
    fprintf(fid, 'fullGridSize_rows: %d\n', grid_system.fullGridSize(1));
    fprintf(fid, 'fullGridSize_cols: %d\n', grid_system.fullGridSize(2));
    
    % Calculate statistics only for non-zero accumulation points
    valid_mask = grid_system.avgCount > 0;
    fprintf(fid, 'X_min: %.12f\n', min(min(grid_system.X(valid_mask))));
    fprintf(fid, 'X_max: %.12f\n', max(max(grid_system.X(valid_mask))));
    fprintf(fid, 'Y_min: %.12f\n', min(min(grid_system.Y(valid_mask))));
    fprintf(fid, 'Y_max: %.12f\n', max(max(grid_system.Y(valid_mask))));
    fprintf(fid, 'Ax1Err_min: %.12f\n', min(min(grid_system.Ax1Err(valid_mask))));
    fprintf(fid, 'Ax1Err_max: %.12f\n', max(max(grid_system.Ax1Err(valid_mask))));
    fprintf(fid, 'Ax2Err_min: %.12f\n', min(min(grid_system.Ax2Err(valid_mask))));
    fprintf(fid, 'Ax2Err_max: %.12f\n', max(max(grid_system.Ax2Err(valid_mask))));
    
    % Environmental data summary
    valid_temps = grid_system.airTemp(grid_system.airTemp ~= 0);
    fprintf(fid, 'airTemp_mean: %.6f\n', mean(valid_temps));
    valid_temps = grid_system.matTemp(grid_system.matTemp ~= 0);
    fprintf(fid, 'matTemp_mean: %.6f\n', mean(valid_temps));
    fclose(fid);
    
    % Display key metrics
    fprintf('\n=== STITCHING RESULTS SUMMARY ===\n');
    fprintf('Total zones processed: %d\n', grid_system.zoneCount);
    fprintf('Full grid size: %d x %d points\n', grid_system.fullGridSize(1), grid_system.fullGridSize(2));
    fprintf('Non-zero accumulation points: %d\n', sum(sum(grid_system.avgCount > 0)));
    fprintf('Max accumulation count: %d\n', max(max(grid_system.avgCount)));
    
    % Calculate coverage percentage
    total_points = grid_system.fullGridSize(1) * grid_system.fullGridSize(2);
    covered_points = sum(sum(grid_system.avgCount > 0));
    coverage_pct = 100 * covered_points / total_points;
    fprintf('Grid coverage: %.1f%% (%d/%d points)\n', coverage_pct, covered_points, total_points);
    
    % Show overlap statistics
    overlap_points = sum(sum(grid_system.avgCount > 1));
    overlap_pct = 100 * overlap_points / covered_points;
    fprintf('Overlap regions: %.1f%% (%d/%d covered points)\n', overlap_pct, overlap_points, covered_points);
    
    fprintf('\n=== TEST COMPLETED SUCCESSFULLY ===\n');
    fprintf('All zones processed and stitched\n');
    fprintf('Results saved to: multizone_step3_output_octave.txt\n');
    
    % Save the results for comparison with Python
    grid_system_step3 = grid_system;
    setup_step3 = setup;
    save('multizone_step3_output_octave.mat', 'grid_system_step3', 'setup_step3');
    
catch err
    fprintf('ERROR in multizone_step3_stitch_zones:\n');
    fprintf('%s\n', err.message);
    fprintf('Stack trace:\n');
    for i = 1:length(err.stack)
        fprintf('  %s at line %d\n', err.stack(i).name, err.stack(i).line);
    end
end
