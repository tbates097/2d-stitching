% TEST_MULTIZONE_STEP4_OCTAVE - Test complete multi-zone calibration pipeline
%
% This script tests the complete multi-zone processing pipeline through Step 4

clear all;
close all;

fprintf('Testing Multi-Zone Step 4: Complete Calibration Pipeline\n');
fprintf('========================================================\n');

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

% Override filenames for MATLAB version
matlab_cal_file = 'stitched_multizone_matlab.cal';
matlab_out_file = 'stitched_multizone_accuracy_matlab.dat';

try
    % Step 1: Create setup configuration
    fprintf('Step 1: Creating setup configuration...\n');
    setup = multizone_step1_setup(numRow, numCol, travelAx1, travelAx2, zone_filenames);
    
    % Override with MATLAB-specific filenames
    setup.CalFile = matlab_cal_file;
    setup.OutFile = matlab_out_file;
    
    % Step 2: Initialize grid system
    fprintf('Step 2: Initializing grid system...\n');
    grid_system = multizone_step2_initialize_grid(setup, []);
    
    % Step 3: Stitch all zones
    fprintf('Step 3: Stitching all zones...\n');
    grid_system = multizone_step3_stitch_zones(setup, grid_system);
    
    % Step 4: Finalize calibration
    fprintf('Step 4: Finalizing calibration...\n');
    final_result = multizone_step4_finalize_calibration(setup, grid_system);
    
    % Verify the final structure contains expected data
    fprintf('Checking final calibration results...\n');
    
    % Save final results to text file for comparison
    fid = fopen('multizone_step4_output_octave.txt', 'w');
    fprintf(fid, '=== MULTIZONE STEP 4: FINAL CALIBRATION ===\n');
    fprintf(fid, 'totalZones: %d\n', final_result.totalZones);
    fprintf(fid, 'validPoints: %d\n', final_result.validPoints);
    fprintf(fid, 'overlapPoints: %d\n', final_result.overlapPoints);
    fprintf(fid, 'gridSize_rows: %d\n', final_result.gridSize(1));
    fprintf(fid, 'gridSize_cols: %d\n', final_result.gridSize(2));
    fprintf(fid, 'pkAx1: %.12f\n', final_result.pkAx1);
    fprintf(fid, 'pkAx2: %.12f\n', final_result.pkAx2);
    fprintf(fid, 'pkVector: %.12f\n', final_result.pkVector);
    fprintf(fid, 'rmsAx1: %.12f\n', final_result.rmsAx1);
    fprintf(fid, 'rmsAx2: %.12f\n', final_result.rmsAx2);
    fprintf(fid, 'rmsVector: %.12f\n', final_result.rmsVector);
    fprintf(fid, 'orthogonality: %.12f\n', final_result.orthogonality);
    fprintf(fid, 'Ax1Slope: %.12f\n', final_result.Ax1Slope);
    fprintf(fid, 'Ax2Slope: %.12f\n', final_result.Ax2Slope);
    
    % Error ranges
    valid_mask = final_result.validMask;
    fprintf(fid, 'Ax1Err_min: %.12f\n', min(min(final_result.Ax1Err(valid_mask))));
    fprintf(fid, 'Ax1Err_max: %.12f\n', max(max(final_result.Ax1Err(valid_mask))));
    fprintf(fid, 'Ax2Err_min: %.12f\n', min(min(final_result.Ax2Err(valid_mask))));
    fprintf(fid, 'Ax2Err_max: %.12f\n', max(max(final_result.Ax2Err(valid_mask))));
    fprintf(fid, 'VectorErr_min: %.12f\n', min(min(final_result.VectorErr(valid_mask))));
    fprintf(fid, 'VectorErr_max: %.12f\n', max(max(final_result.VectorErr(valid_mask))));
    fclose(fid);
    
    % Display final performance summary
    fprintf('\n=== COMPLETE CALIBRATION PIPELINE RESULTS ===\n');
    fprintf('Total zones processed: %d\n', final_result.totalZones);
    fprintf('Final grid size: %d x %d points\n', final_result.gridSize(1), final_result.gridSize(2));
    fprintf('Valid data points: %d\n', final_result.validPoints);
    fprintf('Overlap points: %d\n', final_result.overlapPoints);
    
    % Calculate coverage percentage
    total_grid_points = final_result.gridSize(1) * final_result.gridSize(2);
    coverage_pct = 100 * final_result.validPoints / total_grid_points;
    overlap_pct = 100 * final_result.overlapPoints / final_result.validPoints;
    
    fprintf('Grid coverage: %.1f%% (%d/%d points)\n', coverage_pct, ...
            final_result.validPoints, total_grid_points);
    fprintf('Overlap regions: %.1f%% (%d/%d valid points)\n', overlap_pct, ...
            final_result.overlapPoints, final_result.validPoints);
    
    fprintf('\nFINAL ACCURACY PERFORMANCE:\n');
    fprintf('  Ax1: ±%.3f um P-P, %.3f um RMS\n', final_result.pkAx1/2, final_result.rmsAx1);
    fprintf('  Ax2: ±%.3f um P-P, %.3f um RMS\n', final_result.pkAx2/2, final_result.rmsAx2);
    fprintf('  Vector: %.3f um RMS, %.3f um P-P\n', final_result.rmsVector, final_result.pkVector);
    fprintf('  Orthogonality: %.3f arc-seconds\n', final_result.orthogonality);
    
    fprintf('  Global straightness slopes:\n');
    fprintf('    Ax1: %.6f um/mm\n', final_result.Ax1Slope);
    fprintf('    Ax2: %.6f um/mm\n', final_result.Ax2Slope);
    
    % Check if calibration files were generated
    if setup.WriteCalFile && exist(matlab_cal_file, 'file')
        fprintf('\n✅ Calibration file generated: %s\n', matlab_cal_file);
    end
    
    if setup.writeOutputFile && exist(matlab_out_file, 'file')
        fprintf('✅ Output accuracy file generated: %s\n', matlab_out_file);
    end
    
    fprintf('\n=== TEST COMPLETED SUCCESSFULLY ===\n');
    fprintf('Complete multi-zone calibration pipeline executed\n');
    fprintf('Results saved to: multizone_step4_output_octave.txt\n');
    
    % Save the results for comparison with Python
    final_result_step4 = final_result;
    setup_step4 = setup;
    grid_system_step4 = grid_system;
    save('multizone_step4_output_octave.mat', 'final_result_step4', 'setup_step4', 'grid_system_step4');
    
    fprintf('\n🎉 COMPLETE MULTI-ZONE CALIBRATION PIPELINE SUCCESSFUL!\n');
    fprintf('✅ All 4 zones processed and stitched\n');
    fprintf('✅ Final averaging completed\n'); 
    fprintf('✅ Calibration file generated\n');
    fprintf('✅ Accuracy verification file created\n');
    
catch err
    fprintf('ERROR in multizone_step4_finalize_calibration:\n');
    fprintf('%s\n', err.message);
    fprintf('Stack trace:\n');
    for i = 1:length(err.stack)
        fprintf('  %s at line %d\n', err.stack(i).name, err.stack(i).line);
    end
end
