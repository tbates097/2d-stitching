% TEST_MULTIZONE_STEP1_OCTAVE - Test multi-zone setup configuration
%
% This script tests the multi-zone setup step with the same parameters
% that will be used in Python for comparison

clear all;
close all;

fprintf('Testing Multi-Zone Step 1: Setup Configuration\n');
fprintf('==============================================\n');

% Example configuration using all 4 available zones (2x2 grid)
numRow = 2;
numCol = 2;
travelAx1 = [-200/25.4, 200/25.4];  % Convert from mm to inches  
travelAx2 = [-75/25.4, 75/25.4];

% Zone filenames - using all available test files in a 2x2 layout
zone_filenames = cell(numRow, numCol);
zone_filenames{1,1} = 'MATLAB Source/642583-1-1-CZ1.dat';  % Row 1, Col 1
zone_filenames{1,2} = 'MATLAB Source/642583-1-1-CZ2.dat';  % Row 1, Col 2
zone_filenames{2,1} = 'MATLAB Source/642583-1-1-CZ3.dat';  % Row 2, Col 1
zone_filenames{2,2} = 'MATLAB Source/642583-1-1-CZ4.dat';  % Row 2, Col 2

try
    % Test the setup function
    setup = multizone_step1_setup(numRow, numCol, travelAx1, travelAx2, zone_filenames);
    
    % Verify the structure contains expected fields
    expected_fields = {'numRow', 'numCol', 'travelAx1', 'travelAx2', ...
                      'zone_filenames', 'totalTravelAx1', 'totalTravelAx2', ...
                      'y_meas_dir', 'zoneCount', 'WriteCalFile', 'OutAxis3', ...
                      'OutAx3Value', 'CalFile', 'UserUnit', 'writeOutputFile', ...
                      'OutFile', 'airTemp', 'matTemp', 'comment', 'fileDate'};
    
    fprintf('Checking for expected fields...\n');
    missing_fields = 0;
    for i = 1:length(expected_fields)
        if isfield(setup, expected_fields{i})
            fprintf('✓ %s: Present\n', expected_fields{i});
        else
            fprintf('✗ %s: Missing\n', expected_fields{i});
            missing_fields = missing_fields + 1;
        end
    end
    
    % Save setup results to text file for comparison
    fid = fopen('multizone_step1_output_octave.txt', 'w');
    fprintf(fid, '=== MULTIZONE STEP 1: SETUP CONFIGURATION ===\n');
    fprintf(fid, 'numRow: %d\n', setup.numRow);
    fprintf(fid, 'numCol: %d\n', setup.numCol);
    fprintf(fid, 'travelAx1_min: %.6f\n', setup.travelAx1(1));
    fprintf(fid, 'travelAx1_max: %.6f\n', setup.travelAx1(2));
    fprintf(fid, 'travelAx2_min: %.6f\n', setup.travelAx2(1));
    fprintf(fid, 'travelAx2_max: %.6f\n', setup.travelAx2(2));
    fprintf(fid, 'totalTravelAx1: %.6f\n', setup.totalTravelAx1);
    fprintf(fid, 'totalTravelAx2: %.6f\n', setup.totalTravelAx2);
    fprintf(fid, 'y_meas_dir: %d\n', setup.y_meas_dir);
    fprintf(fid, 'zoneCount: %d\n', setup.zoneCount);
    fprintf(fid, 'WriteCalFile: %d\n', setup.WriteCalFile);
    fprintf(fid, 'OutAxis3: %d\n', setup.OutAxis3);
    fprintf(fid, 'OutAx3Value: %d\n', setup.OutAx3Value);
    fprintf(fid, 'CalFile: %s\n', setup.CalFile);
    fprintf(fid, 'UserUnit: %s\n', setup.UserUnit);
    fprintf(fid, 'writeOutputFile: %d\n', setup.writeOutputFile);
    fprintf(fid, 'OutFile: %s\n', setup.OutFile);
    fprintf(fid, 'zone_filename_1_1: %s\n', setup.zone_filenames{1,1});
    fprintf(fid, 'zone_filename_1_2: %s\n', setup.zone_filenames{1,2});
    fprintf(fid, 'zone_filename_2_1: %s\n', setup.zone_filenames{2,1});
    fprintf(fid, 'zone_filename_2_2: %s\n', setup.zone_filenames{2,2});
    fprintf(fid, 'airTemp_length: %d\n', length(setup.airTemp));
    fprintf(fid, 'matTemp_length: %d\n', length(setup.matTemp));
    fprintf(fid, 'comment_length: %d\n', length(setup.comment));
    fprintf(fid, 'fileDate_length: %d\n', length(setup.fileDate));
    fclose(fid);
    
    if missing_fields == 0
        fprintf('\n=== TEST COMPLETED SUCCESSFULLY ===\n');
        fprintf('Setup configuration created and validated\n');
        fprintf('Results saved to: multizone_step1_output_octave.txt\n');
        
        % Save the setup for comparison with Python
        setup_step1 = setup;
        save('multizone_step1_output_octave.mat', 'setup_step1');
    else
        fprintf('\n=== TEST FAILED ===\n');
        fprintf('%d fields missing from setup structure\n', missing_fields);
    end
    
catch err
    fprintf('ERROR in multizone_step1_setup:\n');
    fprintf('%s\n', err.message);
end
