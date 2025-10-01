function grid_data = step3_create_grid(data_raw)
% STEP3_CREATE_GRID - Create 2D position and error matrices using griddata interpolation
%
% This function takes the raw measurement data and interpolates it onto a regular
% 2D grid using MATLAB's griddata function, creating the position matrices X, Y
% and error matrices Ax1Err, Ax2Err
%
% INPUT:
%   data_raw - structure from step2_load_data containing raw measurement data
%
% OUTPUT:
%   grid_data - structure containing 2D grid matrices

% Initialize output structure
grid_data = struct();

% Create 2D position matrices using meshgrid
[X, Y] = meshgrid(data_raw.Ax1Pos, data_raw.Ax2Pos);
grid_data.X = X;
grid_data.Y = Y;
grid_data.SizeGrid = size(X);

% Normalize position vectors for griddata interpolation
% This helps with numerical stability when using griddata
% MJS 5Feb2018 - Changed to max-min to fix bug where all negative travel led to divide by zero
maxAx1 = max(data_raw.Ax1PosCmd) - min(data_raw.Ax1PosCmd);
maxAx2 = max(data_raw.Ax2PosCmd) - min(data_raw.Ax2PosCmd);

% Handle case where there's no movement (single point)
if maxAx1 == 0
    maxAx1 = 1;
end
if maxAx2 == 0
    maxAx2 = 1;
end

% Interpolate error data onto regular grid using griddata
fprintf('Interpolating Axis 1 error data onto regular grid...\n');
grid_data.Ax1Err = griddata(data_raw.Ax1PosCmd / maxAx1, ...
                           data_raw.Ax2PosCmd / maxAx2, ...
                           data_raw.Ax1RelErr_um, ...
                           X / maxAx1, ...
                           Y / maxAx2);

fprintf('Interpolating Axis 2 error data onto regular grid...\n');
grid_data.Ax2Err = griddata(data_raw.Ax1PosCmd / maxAx1, ...
                           data_raw.Ax2PosCmd / maxAx2, ...
                           data_raw.Ax2RelErr_um, ...
                           X / maxAx1, ...
                           Y / maxAx2);

% Store normalization factors for reference
grid_data.maxAx1 = maxAx1;
grid_data.maxAx2 = maxAx2;

% Check for NaN values in interpolated data
nan_count_ax1 = sum(sum(isnan(grid_data.Ax1Err)));
nan_count_ax2 = sum(sum(isnan(grid_data.Ax2Err)));

% Display grid information
fprintf('\n=== GRID DATA SUMMARY ===\n');
fprintf('Grid size: %d x %d\n', grid_data.SizeGrid(1), grid_data.SizeGrid(2));
fprintf('X range: [%.3f, %.3f] mm\n', min(min(X)), max(max(X)));
fprintf('Y range: [%.3f, %.3f] mm\n', min(min(Y)), max(max(Y)));
fprintf('Ax1 error range: [%.3f, %.3f] um\n', min(min(grid_data.Ax1Err)), max(max(grid_data.Ax1Err)));
fprintf('Ax2 error range: [%.3f, %.3f] um\n', min(min(grid_data.Ax2Err)), max(max(grid_data.Ax2Err)));
fprintf('NaN values - Ax1: %d, Ax2: %d\n', nan_count_ax1, nan_count_ax2);

if nan_count_ax1 > 0 || nan_count_ax2 > 0
    fprintf('WARNING: NaN values detected in interpolated data!\n');
else
    fprintf('Interpolation completed successfully - no NaN values\n');
end
fprintf('=========================\n\n');

end
