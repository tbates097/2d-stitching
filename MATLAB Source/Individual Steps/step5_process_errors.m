function processed_data = step5_process_errors(grid_data, slope_data)
% STEP5_PROCESS_ERRORS - Remove slopes and calculate vector sum accuracy error
%
% This function removes the calculated straightness slopes from the error data
% and computes the final accuracy errors including vector sum error. This
% isolates the true accuracy errors from systematic straightness errors.
%
% INPUT:
%   grid_data - structure from step3_create_grid containing 2D grid data
%   slope_data - structure from step4_calculate_slopes containing slope info
%
% OUTPUT:
%   processed_data - structure containing final processed accuracy errors

% Initialize output structure
processed_data = struct();

% Copy grid position data
processed_data.X = grid_data.X;
processed_data.Y = grid_data.Y;
processed_data.SizeGrid = grid_data.SizeGrid;

% Start with the original error data
processed_data.Ax1Err = grid_data.Ax1Err;
processed_data.Ax2Err = grid_data.Ax2Err;

% Remove best-fit slopes from the error data
fprintf('Removing straightness slopes from error data...\n');

% Remove Ax1 slope from all columns
for i = 1:processed_data.SizeGrid(2)
    processed_data.Ax1Err(:,i) = processed_data.Ax1Err(:,i) - slope_data.Ax1Line;
end

% Remove Ax2 slope from all rows  
for i = 1:processed_data.SizeGrid(1)
    processed_data.Ax2Err(i,:) = processed_data.Ax2Err(i,:) - slope_data.Ax2Line;
end

% Subtract error at origin to set reference point to zero
processed_data.Ax1Err = processed_data.Ax1Err - processed_data.Ax1Err(1,1);
processed_data.Ax2Err = processed_data.Ax2Err - processed_data.Ax2Err(1,1);

% Calculate vector sum accuracy error
fprintf('Calculating vector sum accuracy error...\n');
processed_data.VectorErr = sqrt(processed_data.Ax1Err.^2 + processed_data.Ax2Err.^2);

% Calculate peak-to-peak accuracy values
processed_data.pkAx1 = max(max(processed_data.Ax1Err)) - min(min(processed_data.Ax1Err));
processed_data.pkAx2 = max(max(processed_data.Ax2Err)) - min(min(processed_data.Ax2Err));
processed_data.maxVectorErr = max(max(processed_data.VectorErr));

% Calculate RMS accuracy values
processed_data.rmsAx1 = std(processed_data.Ax1Err(:));
processed_data.rmsAx2 = std(processed_data.Ax2Err(:));
processed_data.rmsVector = std(processed_data.VectorErr(:));

% Calculate accuracy amplitudes (half of peak-to-peak)
processed_data.Ax1amplitude = processed_data.pkAx1 / 2;
processed_data.Ax2amplitude = processed_data.pkAx2 / 2;

% Store slope data for reference
processed_data.slope_data = slope_data;

% Display error processing results
fprintf('\n=== ERROR PROCESSING RESULTS ===\n');
fprintf('After slope removal:\n');
fprintf('  Ax1 error range: [%.3f, %.3f] um\n', ...
    min(min(processed_data.Ax1Err)), max(max(processed_data.Ax1Err)));
fprintf('  Ax2 error range: [%.3f, %.3f] um\n', ...
    min(min(processed_data.Ax2Err)), max(max(processed_data.Ax2Err)));
fprintf('  Vector error range: [%.3f, %.3f] um\n', ...
    min(min(processed_data.VectorErr)), max(max(processed_data.VectorErr)));
fprintf('\nAccuracy Performance Summary:\n');
fprintf('  Ax1 Peak-to-Peak: %.3f um (±%.3f um)\n', processed_data.pkAx1, processed_data.Ax1amplitude);
fprintf('  Ax2 Peak-to-Peak: %.3f um (±%.3f um)\n', processed_data.pkAx2, processed_data.Ax2amplitude);
fprintf('  Max Vector Error: %.3f um\n', processed_data.maxVectorErr);
fprintf('  Ax1 RMS: %.3f um\n', processed_data.rmsAx1);
fprintf('  Ax2 RMS: %.3f um\n', processed_data.rmsAx2);
fprintf('  Vector RMS: %.3f um\n', processed_data.rmsVector);
fprintf('  Orthogonality: %.3f arc-seconds\n', slope_data.orthog);
fprintf('=================================\n\n');

end
