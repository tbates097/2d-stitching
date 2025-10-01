function setup = multizone_step1_setup(numRow, numCol, travelAx1, travelAx2, zone_filenames)
% MULTIZONE_STEP1_SETUP - Setup configuration for multi-zone stitching
%
% This function initializes the configuration parameters needed for 
% multi-zone stitching including zone layout, travel ranges, and filenames
%
% INPUT:
%   numRow - number of calibration zone rows (zones in Axis 2 direction)  
%   numCol - number of calibration zone columns (zones in Axis 1 direction)
%   travelAx1 - [min max] full calibrated travel for Axis 1 (scan axis)
%   travelAx2 - [min max] full calibrated travel for Axis 2 (step axis)  
%   zone_filenames - cell array of filenames, size [numRow x numCol]
%
% OUTPUT:
%   setup - structure containing all configuration parameters

% Initialize output structure
setup = struct();

% Validate inputs
if numRow < 1 || numCol < 1
    error('Number of rows and columns must be >= 1');
end

if length(travelAx1) ~= 2 || length(travelAx2) ~= 2
    error('Travel ranges must be [min max] vectors');
end

if travelAx1(2) <= travelAx1(1) || travelAx2(2) <= travelAx2(1)
    error('Travel max must be greater than travel min');
end

if ~iscell(zone_filenames) || any(size(zone_filenames) ~= [numRow numCol])
    error('zone_filenames must be a cell array of size [numRow x numCol]');
end

% Store basic configuration
setup.numRow = numRow;
setup.numCol = numCol;
setup.travelAx1 = travelAx1;
setup.travelAx2 = travelAx2;
setup.zone_filenames = zone_filenames;

% Calculate total travel distances
setup.totalTravelAx1 = travelAx1(2) - travelAx1(1);
setup.totalTravelAx2 = travelAx2(2) - travelAx2(1);

% Set measurement direction factor (from original code)
setup.y_meas_dir = -1;  % slope opposite sign between axes

% Initialize zone counter
setup.zoneCount = 0;

% Validate that all zone files exist
fprintf('Validating zone files...\n');
for i = 1:numRow
    for j = 1:numCol
        filename = char(zone_filenames{i,j});
        if ~exist(filename, 'file')
            error('Zone file not found: %s (Row %d, Col %d)', filename, i, j);
        end
        fprintf('  ✓ Row %d, Col %d: %s\n', i, j, filename);
    end
end

% Store calibration file options (from original)
setup.WriteCalFile = 1;     % 1 = write cal file
setup.OutAxis3 = 0;         % 0 = no gantry slave  
setup.OutAx3Value = 2;      % master axis of gantry
setup.CalFile = 'stitched_multizone.cal';
setup.UserUnit = 'ENGLISH'; % 'METRIC' or 'ENGLISH'
setup.writeOutputFile = 1;
setup.OutFile = 'stitched_multizone_accuracy.dat';

% Initialize arrays for environmental data tracking
setup.airTemp = zeros(1, numRow * numCol);
setup.matTemp = zeros(1, numRow * numCol); 
setup.comment = cell(1, numRow * numCol);
setup.fileDate = cell(1, numRow * numCol);

% Display setup summary
fprintf('\n=== MULTI-ZONE SETUP SUMMARY ===\n');
fprintf('Zone layout: %d rows × %d columns = %d total zones\n', ...
    numRow, numCol, numRow * numCol);
fprintf('Axis 1 travel: [%.3f, %.3f] (%.3f total)\n', ...
    travelAx1(1), travelAx1(2), setup.totalTravelAx1);
fprintf('Axis 2 travel: [%.3f, %.3f] (%.3f total)\n', ...
    travelAx2(1), travelAx2(2), setup.totalTravelAx2);
fprintf('Calibration file: %s\n', setup.CalFile);
fprintf('Output file: %s\n', setup.OutFile);
fprintf('=================================\n\n');

end
