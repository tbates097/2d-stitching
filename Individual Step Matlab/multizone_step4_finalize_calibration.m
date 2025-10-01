function final_result = multizone_step4_finalize_calibration(setup, grid_system)
% MULTIZONE_STEP4_FINALIZE_CALIBRATION - Complete final averaging and generate calibration
%
% This function performs the final averaging of overlapped regions and generates
% the calibration file in Aerotech A3200 format
%
% INPUT:
%   setup - structure from multizone_step1_setup containing configuration
%   grid_system - structure from multizone_step3_stitch_zones with all zones
%
% OUTPUT:
%   final_result - structure containing final calibration data and statistics

fprintf('Step 4: Finalizing calibration and generating output files...\n');
fprintf('============================================================\n');

% STEP 4A: Final averaging of overlapped regions
fprintf('Performing final averaging of overlapped regions...\n');

% Divide accumulated values by avgCount to complete averaging in overlap regions
totalSize = size(grid_system.X);
validMask = grid_system.avgCount > 0;

fprintf('  Grid size: %d x %d points\n', totalSize(1), totalSize(2));
fprintf('  Valid points: %d\n', sum(sum(validMask)));
fprintf('  Points with overlaps: %d\n', sum(sum(grid_system.avgCount > 1)));

% Create final averaged matrices
X_final = zeros(totalSize);
Y_final = zeros(totalSize);
Ax1Err_final = zeros(totalSize);
Ax2Err_final = zeros(totalSize);

% Perform averaging only for valid points
for i = 1:totalSize(1)
    for j = 1:totalSize(2)
        if grid_system.avgCount(i,j) > 0
            X_final(i,j) = grid_system.X(i,j) / grid_system.avgCount(i,j);
            Y_final(i,j) = grid_system.Y(i,j) / grid_system.avgCount(i,j);
            Ax1Err_final(i,j) = grid_system.Ax1Err(i,j) / grid_system.avgCount(i,j);
            Ax2Err_final(i,j) = grid_system.Ax2Err(i,j) / grid_system.avgCount(i,j);
        end
    end
end

fprintf('  Final averaging completed\n');

% STEP 4B: Remove global straightness slopes and calculate orthogonality
fprintf('Removing global straightness slopes...\n');

% Calculate mean error curves for valid points (MATLAB indexing fix)
% Find which rows and columns have valid data
valid_rows = any(validMask, 2);  % which rows have any valid data
valid_cols = any(validMask, 1);  % which columns have any valid data

% Calculate mean error curves for each valid row and column
Ax1_mean = zeros(sum(valid_rows), 1);
Ax2_mean = zeros(1, sum(valid_cols));

row_idx = 1;
for i = 1:totalSize(1)
    if valid_rows(i)
        valid_data_in_row = Ax1Err_final(i, validMask(i,:));
        if ~isempty(valid_data_in_row)
            Ax1_mean(row_idx) = mean(valid_data_in_row);
        end
        row_idx = row_idx + 1;
    end
end

col_idx = 1;
for j = 1:totalSize(2)
    if valid_cols(j)
        valid_data_in_col = Ax2Err_final(validMask(:,j), j);
        if ~isempty(valid_data_in_col)
            Ax2_mean(col_idx) = mean(valid_data_in_col);
        end
        col_idx = col_idx + 1;
    end
end

% Get corresponding Y and X values for valid rows and columns
Y_valid_rows = Y_final(valid_rows, 1);
X_valid_cols = X_final(1, valid_cols);

% Fit global slopes
Ax1Coef = polyfit(Y_valid_rows, Ax1_mean, 1);   % slope units microns/mm
Ax2Coef = polyfit(X_valid_cols, Ax2_mean, 1);   % slope units microns/mm

fprintf('  Global Ax1 slope: %.6f um/mm\n', Ax1Coef(1));
fprintf('  Global Ax2 slope: %.6f um/mm\n', Ax2Coef(1));

% Create best fit lines
y_meas_dir = -1;  % measurement direction factor
Ax1Line = polyval(Ax1Coef, Y_final(:,1));
Ax2Line = polyval(y_meas_dir * Ax1Coef, X_final(1,:));

% Remove slopes from error data
for i = 1:totalSize(2)
    if sum(validMask(:,i)) > 0
        Ax1Err_final(:,i) = Ax1Err_final(:,i) - Ax1Line;
    end
end
for i = 1:totalSize(1)
    if sum(validMask(i,:)) > 0
        Ax2Err_final(i,:) = Ax2Err_final(i,:) - Ax2Line;
    end
end

% Calculate orthogonality
orthog = Ax1Coef(1) - y_meas_dir * Ax2Coef(1);
orthog_arcsec = atan(orthog/1000) * 180/pi * 3600;  % convert to arc seconds

fprintf('  Global orthogonality error: %.3f arc-seconds\n', orthog_arcsec);

% STEP 4C: Calculate vector sum accuracy error
fprintf('Calculating vector sum accuracy errors...\n');

% Subtract error at origin prior to vector sum calculation
if validMask(1,1)
    Ax1Err_final = Ax1Err_final - Ax1Err_final(1,1);
    Ax2Err_final = Ax2Err_final - Ax2Err_final(1,1);
end

% Calculate total vector sum accuracy error
VectorErr = sqrt(Ax1Err_final.^2 + Ax2Err_final.^2);

% Calculate peak-to-peak values (only for valid points)
valid_ax1_errors = Ax1Err_final(validMask);
valid_ax2_errors = Ax2Err_final(validMask);
valid_vector_errors = VectorErr(validMask);

pkAx1 = max(valid_ax1_errors) - min(valid_ax1_errors);
pkAx2 = max(valid_ax2_errors) - min(valid_ax2_errors);
pkVector = max(valid_vector_errors) - min(valid_vector_errors);

% Calculate RMS values
rmsAx1 = sqrt(mean(valid_ax1_errors.^2));
rmsAx2 = sqrt(mean(valid_ax2_errors.^2));
rmsVector = sqrt(mean(valid_vector_errors.^2));

fprintf('  Ax1 Peak-to-Peak: %.3f um (±%.3f um)\n', pkAx1, pkAx1/2);
fprintf('  Ax2 Peak-to-Peak: %.3f um (±%.3f um)\n', pkAx2, pkAx2/2);
fprintf('  Vector Peak-to-Peak: %.3f um\n', pkVector);
fprintf('  Ax1 RMS: %.3f um\n', rmsAx1);
fprintf('  Ax2 RMS: %.3f um\n', rmsAx2);
fprintf('  Vector RMS: %.3f um\n', rmsVector);

% STEP 4D: Generate calibration file (if requested)
if setup.WriteCalFile
    fprintf('Generating calibration file...\n');
    
    % Create signed calibration error tables with surrounding zeros
    sizeCal = size(Ax1Err_final);
    
    % Create matrices filled with zeros (add extra rows/columns for smooth transitions)
    Ax1cal = zeros(sizeCal(1)+2, sizeCal(2)+2);
    Ax2cal = zeros(sizeCal(1)+2, sizeCal(2)+2);
    
    % Populate middle of matrices with measured data (inverted sign for correction)
    % Units: microns, precision to nm/10 (round to 4 decimal places)
    Ax1cal(2:(end-1), 2:(end-1)) = -grid_system.Ax1Sign * round(Ax1Err_final * 10000)/10000;
    Ax2cal(2:(end-1), 2:(end-1)) = -grid_system.Ax2Sign * round(Ax2Err_final * 10000)/10000;
    
    % Write calibration file
    write_cal_file(setup.CalFile, Ax1cal, Ax2cal, grid_system, setup);
    
    fprintf('  Calibration file saved: %s\n', setup.CalFile);
end

% STEP 4E: Generate output data file (if requested)
if setup.writeOutputFile
    fprintf('Generating output accuracy file...\n');
    
    write_accuracy_file(setup.OutFile, X_final, Y_final, Ax1Err_final, Ax2Err_final, ...
                       VectorErr, validMask, grid_system, setup);
    
    fprintf('  Output file saved: %s\n', setup.OutFile);
end

% Store final results
final_result = struct();
final_result.X = X_final;
final_result.Y = Y_final;
final_result.Ax1Err = Ax1Err_final;
final_result.Ax2Err = Ax2Err_final;
final_result.VectorErr = VectorErr;
final_result.validMask = validMask;
final_result.avgCount = grid_system.avgCount;

% Statistics
final_result.pkAx1 = pkAx1;
final_result.pkAx2 = pkAx2;
final_result.pkVector = pkVector;
final_result.rmsAx1 = rmsAx1;
final_result.rmsAx2 = rmsAx2;
final_result.rmsVector = rmsVector;
final_result.orthogonality = orthog_arcsec;
final_result.Ax1Slope = Ax1Coef(1);
final_result.Ax2Slope = Ax2Coef(1);

% Grid information
final_result.totalZones = grid_system.zoneCount;
final_result.gridSize = totalSize;
final_result.validPoints = sum(sum(validMask));
final_result.overlapPoints = sum(sum(grid_system.avgCount > 1));

fprintf('\n=== FINAL CALIBRATION SUMMARY ===\n');
fprintf('Total zones processed: %d\n', final_result.totalZones);
fprintf('Final grid size: %d x %d points\n', totalSize(1), totalSize(2));
fprintf('Valid data points: %d (%.1f%% coverage)\n', final_result.validPoints, ...
        100*final_result.validPoints/prod(totalSize));
fprintf('Overlap points: %d (%.1f%% of valid points)\n', final_result.overlapPoints, ...
        100*final_result.overlapPoints/final_result.validPoints);
fprintf('Final accuracy performance:\n');
fprintf('  Ax1: ±%.3f um P-P, %.3f um RMS\n', pkAx1/2, rmsAx1);
fprintf('  Ax2: ±%.3f um P-P, %.3f um RMS\n', pkAx2/2, rmsAx2);
fprintf('  Vector: %.3f um RMS\n', rmsVector);
fprintf('  Orthogonality: %.3f arc-seconds\n', orthog_arcsec);
fprintf('===================================\n\n');

end


function write_cal_file(filename, Ax1cal, Ax2cal, grid_system, setup)
% Write Aerotech A3200 calibration file

fid = fopen(filename, 'w');

% Write header
fprintf(fid, 'GLOBAL\n');
fprintf(fid, 'TYPE 3\n');
fprintf(fid, 'AXES %s %s\n', grid_system.Ax1Name, grid_system.Ax2Name);

% Calculate starting positions (with extra border)
startAx1 = min(min(grid_system.X(grid_system.avgCount > 0))) - grid_system.incAx1;
startAx2 = min(min(grid_system.Y(grid_system.avgCount > 0))) - grid_system.incAx2;

fprintf(fid, 'UNITSYSTEM %s\n', setup.UserUnit);
fprintf(fid, 'START %.6f %.6f\n', startAx1, startAx2);
fprintf(fid, 'DELTA %.6f %.6f\n', grid_system.incAx1, grid_system.incAx2);
fprintf(fid, 'POINTS %d %d\n', size(Ax1cal,2), size(Ax1cal,1));
fprintf(fid, 'END\n');

% Write calibration data
for i = 1:size(Ax1cal,1)
    for j = 1:size(Ax1cal,2)
        if j < size(Ax1cal,2)
            fprintf(fid, '%.4f\t%.4f\t', Ax1cal(i,j), Ax2cal(i,j));
        else
            fprintf(fid, '%.4f\t%.4f\n', Ax1cal(i,j), Ax2cal(i,j));
        end
    end
end

fclose(fid);
end


function write_accuracy_file(filename, X, Y, Ax1Err, Ax2Err, VectorErr, validMask, grid_system, setup)
% Write accuracy verification file

fid = fopen(filename, 'w');

% Write header
fprintf(fid, '%% Multi-Zone 2D Accuracy Calibration Results\n');
fprintf(fid, '%% System: %s (S/N: %s)\n', grid_system.model, grid_system.SN);
fprintf(fid, '%% Zones processed: %d\n', grid_system.zoneCount);
fprintf(fid, '%% Grid size: %d x %d points\n', size(X,1), size(X,2));
fprintf(fid, '%% Units: %s\n', grid_system.UserUnit);
fprintf(fid, '%% Ax1TestLoc Ax2TestLoc Ax1Err Ax2Err VectorErr AvgCount\n');

% Write data for valid points only
for i = 1:size(X,1)
    for j = 1:size(X,2)
        if validMask(i,j)
            fprintf(fid, '%.6f\t%.6f\t%.6f\t%.6f\t%.6f\t%d\n', ...
                   X(i,j), Y(i,j), Ax1Err(i,j), Ax2Err(i,j), VectorErr(i,j), ...
                   grid_system.avgCount(i,j));
        end
    end
end

fclose(fid);
end
