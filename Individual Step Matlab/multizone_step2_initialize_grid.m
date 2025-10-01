function grid_system = multizone_step2_initialize_grid(setup, process_zone_func)
% MULTIZONE_STEP2_INITIALIZE_GRID - Initialize full grid system and process first zone
%
% This function processes the first zone to establish the master reference,
% determines grid increments, and initializes the full travel accumulation matrices
%
% INPUT:
%   setup - structure from multizone_step1_setup containing configuration
%   process_zone_func - function handle to process individual zones (e.g. @step5_process_errors for single zones)
%
% OUTPUT:
%   grid_system - structure containing full grid system and first zone data

% Initialize output structure
grid_system = struct();

fprintf('Initializing full grid system...\n');
fprintf('Processing first zone (Row 1, Col 1)...\n');

% Process the first zone to establish master reference
first_zone_file = setup.zone_filenames{1,1};
fprintf('  Loading: %s\n', first_zone_file);

% Get the first zone data using our single-zone pipeline
% Step 1: Parse header
config = step1_parse_header(first_zone_file);

% Step 2: Load raw data  
data_raw = step2_load_data(first_zone_file, config);

% Step 3: Create grid
grid_data = step3_create_grid(data_raw);

% Step 4: Calculate slopes
slope_data = step4_calculate_slopes(grid_data);

% Step 5: Process errors
first_zone_data = step5_process_errors(grid_data, slope_data);

% Store master reference data for subsequent zones
grid_system.Ax1Master = first_zone_data.X;    % master Axis 1 position -- scan axis
grid_system.Ax2Master = first_zone_data.Y;    % master Axis 2 position -- step axis
grid_system.Ax1MasErr = first_zone_data.Ax1Err;  % master Ax1 error
grid_system.Ax2MasErr = first_zone_data.Ax2Err;  % master Ax2 error

% Store master data for row comparisons (used when starting new rows)
grid_system.rowAx1Master = grid_system.Ax1Master;
grid_system.rowAx2Master = grid_system.Ax2Master;
grid_system.rowAx1MasErr = grid_system.Ax1MasErr;
grid_system.rowAx2MasErr = grid_system.Ax2MasErr;

% Store system parameters from first zone
grid_system.SN = config.SN;
grid_system.Ax1Name = config.Ax1Name;
grid_system.Ax2Name = config.Ax2Name;
grid_system.Ax1Num = config.Ax1Num;
grid_system.Ax2Num = config.Ax2Num;
grid_system.Ax1Sign = config.Ax1Sign;
grid_system.Ax2Sign = config.Ax2Sign;
grid_system.UserUnit = config.UserUnit;
grid_system.calDivisor = config.calDivisor;
grid_system.posUnit = config.posUnit;
grid_system.errUnit = config.errUnit;
grid_system.Ax1Gantry = config.Ax1Gantry;
grid_system.Ax2Gantry = config.Ax2Gantry;
grid_system.Ax1SampDist = data_raw.Ax1SampDist;
grid_system.Ax2SampDist = data_raw.Ax2SampDist;
grid_system.operator = config.operator;
grid_system.model = config.model;

% Initialize environmental data arrays
grid_system.airTemp = setup.airTemp;
grid_system.matTemp = setup.matTemp;
grid_system.comment = setup.comment;
grid_system.fileDate = setup.fileDate;

% Store first zone environmental data
grid_system.airTemp(1) = str2double(config.airTemp);
grid_system.matTemp(1) = str2double(config.matTemp);
grid_system.comment{1} = config.comment;
grid_system.fileDate{1} = config.fileDate;

% Determine step sizes from first zone grid
grid_system.incAx1 = grid_system.Ax1Master(1,2) - grid_system.Ax1Master(1,1);
grid_system.incAx2 = grid_system.Ax2Master(2,1) - grid_system.Ax2Master(1,1);

fprintf('  Grid increments: Ax1 = %.6f, Ax2 = %.6f\n', grid_system.incAx1, grid_system.incAx2);

% Calculate dimensions for full travel matrices
% Convert travel ranges from inches to mm to match grid increments
travelAx1_mm = setup.travelAx1 * 25.4;
travelAx2_mm = setup.travelAx2 * 25.4;

numPointsAx1 = round((travelAx1_mm(2) - travelAx1_mm(1)) / grid_system.incAx1 + 1);
numPointsAx2 = round((travelAx2_mm(2) - travelAx2_mm(1)) / grid_system.incAx2 + 1);

fprintf('  Full grid dimensions: %d x %d points\n', numPointsAx2, numPointsAx1);

% Initialize full travel matrices (all zeros initially)
grid_system.X = zeros(numPointsAx2, numPointsAx1);      % Axis 1 Position
grid_system.Y = zeros(numPointsAx2, numPointsAx1);      % Axis 2 Position  
grid_system.Ax1Err = zeros(numPointsAx2, numPointsAx1); % Axis 1 Error
grid_system.Ax2Err = zeros(numPointsAx2, numPointsAx1); % Axis 2 Error
grid_system.avgCount = zeros(numPointsAx2, numPointsAx1); % Average counter for overlaps

% Store dimensions for reference
grid_system.fullGridSize = [numPointsAx2, numPointsAx1];
grid_system.Ax1size = size(grid_system.Ax1Master);
grid_system.Ax2size = size(grid_system.Ax2Master);

% Calculate array indices for first zone (starts at origin of full grid)
grid_system.arrayIndexAx1 = 1;  % offset index in Axis 1 direction
grid_system.arrayIndexAx2 = 1;  % offset index in Axis 2 direction

% Calculate ranges in full travel vectors for this zone
grid_system.rangeAx1 = grid_system.arrayIndexAx1-1+(1:grid_system.Ax1size(2));
grid_system.rangeAx2 = grid_system.arrayIndexAx2-1+(1:grid_system.Ax2size(1));

% Add first zone's data to full travel matrices
fprintf('  Adding first zone data to accumulation matrices...\n');
grid_system.X(grid_system.rangeAx2, grid_system.rangeAx1) = ...
    grid_system.X(grid_system.rangeAx2, grid_system.rangeAx1) + grid_system.Ax1Master;
grid_system.Y(grid_system.rangeAx2, grid_system.rangeAx1) = ...
    grid_system.Y(grid_system.rangeAx2, grid_system.rangeAx1) + grid_system.Ax2Master;
grid_system.Ax1Err(grid_system.rangeAx2, grid_system.rangeAx1) = ...
    grid_system.Ax1Err(grid_system.rangeAx2, grid_system.rangeAx1) + grid_system.Ax1MasErr;
grid_system.Ax2Err(grid_system.rangeAx2, grid_system.rangeAx1) = ...
    grid_system.Ax2Err(grid_system.rangeAx2, grid_system.rangeAx1) + grid_system.Ax2MasErr;
grid_system.avgCount(grid_system.rangeAx2, grid_system.rangeAx1) = ...
    grid_system.avgCount(grid_system.rangeAx2, grid_system.rangeAx1) + ones(size(grid_system.Ax1Master));

% Update zone counter
grid_system.zoneCount = 1;
setup.zoneCount = 1;  % Update the setup structure too

% Display summary
fprintf('\n=== GRID SYSTEM SUMMARY ===\n');
fprintf('System: %s (S/N: %s)\n', grid_system.model, grid_system.SN);
fprintf('Full grid size: %d x %d points\n', numPointsAx2, numPointsAx1);
fprintf('Grid spacing: %.6f x %.6f\n', grid_system.incAx1, grid_system.incAx2);
fprintf('Travel ranges: [%.3f, %.3f] mm x [%.3f, %.3f] mm\n', ...
    travelAx1_mm(1), travelAx1_mm(2), travelAx2_mm(1), travelAx2_mm(2));
fprintf('First zone processed: %s\n', first_zone_file);
fprintf('First zone size: %d x %d points\n', grid_system.Ax1size(1), grid_system.Ax1size(2));
fprintf('Non-zero accumulation points: %d\n', sum(sum(grid_system.avgCount > 0)));
fprintf('===========================\n\n');

end
