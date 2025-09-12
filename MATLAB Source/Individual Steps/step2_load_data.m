function data_raw = step2_load_data(InputFile, config)
% STEP2_LOAD_DATA - Load and sort raw measurement data from file
%
% This function loads the numerical data from the measurement file and
% sorts it by step position (Axis 2) then scan position (Axis 1)
%
% INPUT:
%   InputFile - string, path to the data file
%   config - structure from step1_parse_header containing configuration
%
% OUTPUT:
%   data_raw - structure containing raw measurement data

% Initialize output structure
data_raw = struct();

% Load numerical data from file (skip header lines)
s = load(InputFile);

% Sort data for ascending step and scan positions
% Column 1: Ax1TestLoc, Column 2: Ax2TestLoc
s = sortrows(s, [2 1]);

% Extract data columns
data_raw.Ax1TestLoc = s(:,1);        % Axis 1 test location (incremental counter)
data_raw.Ax2TestLoc = s(:,2);        % Axis 2 test location (incremental counter)  
data_raw.Ax1PosCmd = s(:,3) / config.calDivisor;  % Commanded position (converted to mm)
data_raw.Ax2PosCmd = s(:,4) / config.calDivisor;  % Commanded position (converted to mm)
data_raw.Ax1RelErr = s(:,5) / config.calDivisor;  % Raw relative error (converted to mm)
data_raw.Ax2RelErr = s(:,6) / config.calDivisor;  % Raw relative error (converted to mm)

% Calculate processed relative error (convert to microns, subtract mean)
data_raw.Ax1RelErr_um = (data_raw.Ax1RelErr - mean(data_raw.Ax1RelErr)) * 1000;
data_raw.Ax2RelErr_um = (data_raw.Ax2RelErr - mean(data_raw.Ax2RelErr)) * 1000;

% Calculate measurement parameters
data_raw.NumAx1Points = max(data_raw.Ax1TestLoc);
data_raw.NumAx2Points = max(data_raw.Ax2TestLoc);
data_raw.Ax1MoveDist = max(data_raw.Ax1PosCmd) - min(data_raw.Ax1PosCmd);
data_raw.Ax2MoveDist = max(data_raw.Ax2PosCmd) - min(data_raw.Ax2PosCmd);

% Calculate sampling distances
if data_raw.NumAx1Points > 1
    data_raw.Ax1SampDist = data_raw.Ax1PosCmd(2) - data_raw.Ax1PosCmd(1);
else
    data_raw.Ax1SampDist = 0;
end

if data_raw.NumAx2Points > 1
    data_raw.Ax2SampDist = data_raw.Ax2PosCmd(data_raw.NumAx1Points + 1) - data_raw.Ax2PosCmd(1);
else
    data_raw.Ax2SampDist = 0;
end

% Create position vectors
data_raw.Ax1Pos = data_raw.Ax1PosCmd(1:data_raw.NumAx1Points);
data_raw.Ax2Pos = data_raw.Ax2PosCmd(1:(data_raw.NumAx1Points):(data_raw.NumAx1Points * data_raw.NumAx2Points));

% Display summary information
fprintf('\n=== RAW DATA SUMMARY ===\n');
fprintf('Data points: %d x %d = %d total\n', data_raw.NumAx1Points, data_raw.NumAx2Points, ...
    data_raw.NumAx1Points * data_raw.NumAx2Points);
fprintf('Axis 1 travel: %.3f mm (sampling: %.3f mm)\n', data_raw.Ax1MoveDist, data_raw.Ax1SampDist);
fprintf('Axis 2 travel: %.3f mm (sampling: %.3f mm)\n', data_raw.Ax2MoveDist, data_raw.Ax2SampDist);
fprintf('Axis 1 range: [%.3f, %.3f] mm\n', min(data_raw.Ax1Pos), max(data_raw.Ax1Pos));
fprintf('Axis 2 range: [%.3f, %.3f] mm\n', min(data_raw.Ax2Pos), max(data_raw.Ax2Pos));
fprintf('Raw error range Ax1: [%.3f, %.3f] um\n', min(data_raw.Ax1RelErr_um), max(data_raw.Ax1RelErr_um));
fprintf('Raw error range Ax2: [%.3f, %.3f] um\n', min(data_raw.Ax2RelErr_um), max(data_raw.Ax2RelErr_um));
fprintf('========================\n\n');

end
