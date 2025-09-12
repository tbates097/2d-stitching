function slope_data = step4_calculate_slopes(grid_data)
% STEP4_CALCULATE_SLOPES - Calculate straightness slopes and orthogonality
%
% This function calculates the best-fit slopes for straightness errors in both
% axes and computes the orthogonality between the axes. These slopes will be
% removed later to isolate the accuracy errors.
%
% INPUT:
%   grid_data - structure from step3_create_grid containing 2D grid data
%
% OUTPUT:
%   slope_data - structure containing slope coefficients and orthogonality

% Initialize output structure
slope_data = struct();

% Mirror misalignment factor - slope is always opposite sign between axes
% when laser and encoder read positive in the same direction
y_meas_dir = -1;

% Calculate mean straightness errors along each axis
% Ax1 straightness: average error in Ax1 direction vs Ax2 position
mean_ax1_err = mean(grid_data.Ax1Err, 2);  % Average across rows (Ax1 direction)
mean_ax2_err = mean(grid_data.Ax2Err, 1);  % Average across columns (Ax2 direction)

% Fit linear slopes to the mean straightness errors
% Ax1Coef: slope of Ax1 error vs Ax2 position (units: microns/mm)  
slope_data.Ax1Coef = polyfit(grid_data.Y(:,1), mean_ax1_err, 1);

% Ax2Coef: slope of Ax2 error vs Ax1 position (units: microns/mm)
slope_data.Ax2Coef = polyfit(grid_data.X(1,:), mean_ax2_err, 1);

% Create best-fit lines for slope removal
slope_data.Ax1Line = polyval(slope_data.Ax1Coef, grid_data.Y(:,1));
slope_data.Ax2Line = polyval(y_meas_dir * slope_data.Ax1Coef, grid_data.X(1,:));

% Create straightness data for orthogonality plots (remove best fit lines)
slope_data.Ax1Orthog = mean_ax1_err - slope_data.Ax1Line;
slope_data.Ax2Orthog = mean_ax2_err - polyval(slope_data.Ax2Coef, grid_data.X(1,:));

% Calculate orthogonality error
% This represents how much the axes deviate from being perfectly perpendicular
orthog_slope = slope_data.Ax1Coef(1) - y_meas_dir * slope_data.Ax2Coef(1);
slope_data.orthog = atan(orthog_slope / 1000) * 180 / pi * 3600;  % Convert to arc seconds

% Store measurement direction factor
slope_data.y_meas_dir = y_meas_dir;

% Store mean error vectors for reference
slope_data.mean_ax1_err = mean_ax1_err;
slope_data.mean_ax2_err = mean_ax2_err;

% Display slope calculation results
fprintf('\n=== SLOPE CALCULATION RESULTS ===\n');
fprintf('Ax1 straightness slope: %.6f um/mm\n', slope_data.Ax1Coef(1));
fprintf('Ax1 straightness offset: %.6f um\n', slope_data.Ax1Coef(2));
fprintf('Ax2 straightness slope: %.6f um/mm\n', slope_data.Ax2Coef(1));
fprintf('Ax2 straightness offset: %.6f um\n', slope_data.Ax2Coef(2));
fprintf('Orthogonality error: %.3f arc-seconds\n', slope_data.orthog);
fprintf('RMS Ax1 straightness (after detrend): %.3f um\n', std(slope_data.Ax1Orthog));
fprintf('RMS Ax2 straightness (after detrend): %.3f um\n', std(slope_data.Ax2Orthog));
fprintf('=================================\n\n');

end
