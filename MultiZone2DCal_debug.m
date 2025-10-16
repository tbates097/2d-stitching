% MultiZone2DCal_debug - Enhanced debugging version for Python comparison
% This version provides detailed debug output at each stitching step

clear all;
close all;

% Set up paths and filenames
zone_files = {
    'MATLAB Source/642583-1-1-CZ1.dat',
    'MATLAB Source/642583-1-1-CZ2.dat', 
    'MATLAB Source/642583-1-1-CZ3.dat',
    'MATLAB Source/642583-1-1-CZ4.dat'
};

% Grid parameters
numRow = 2;
numCol = 2;

% Output files
out_cal_file = 'octave_multizone_debug.cal';
out_dat_file = 'octave_multizone_debug.dat';

fprintf('=== OCTAVE MULTIZONE 2D CALIBRATION - ENHANCED DEBUG ===\n');
fprintf('Processing %d zones in %dx%d grid\n', length(zone_files), numRow, numCol);

y_meas_dir = -1;
zone_count = 0;

% Store all zone data for final analysis
all_zones = {};

% Process each zone individually first
for zone_idx = 1:length(zone_files)
    fprintf('\n=== LOADING ZONE %d: %s ===\n', zone_idx, zone_files{zone_idx});
    
    zone_data = A3200Acc2DMultiZone_Octave(zone_files{zone_idx});
    all_zones{zone_idx} = zone_data;
    
    fprintf('Zone %d summary:\n', zone_idx);
    fprintf('  Grid size: %dx%d\n', size(zone_data.X,1), size(zone_data.X,2));
    fprintf('  X range: %.1f to %.1f mm\n', min(min(zone_data.X)), max(max(zone_data.X)));
    fprintf('  Y range: %.1f to %.1f mm\n', min(min(zone_data.Y)), max(max(zone_data.Y)));
    fprintf('  Ax1Err range: %.6f to %.6f μm\n', min(min(zone_data.Ax1Err)), max(max(zone_data.Ax1Err)));
    fprintf('  Ax2Err range: %.6f to %.6f μm\n', min(min(zone_data.Ax2Err)), max(max(zone_data.Ax2Err)));
    
    % Show corner values
    [nrows, ncols] = size(zone_data.X);
    fprintf('  Corner positions:\n');
    fprintf('    TL: (%.1f, %.1f), TR: (%.1f, %.1f)\n', ...
            zone_data.X(1,1), zone_data.Y(1,1), zone_data.X(1,ncols), zone_data.Y(1,ncols));
    fprintf('    BL: (%.1f, %.1f), BR: (%.1f, %.1f)\n', ...
            zone_data.X(nrows,1), zone_data.Y(nrows,1), zone_data.X(nrows,ncols), zone_data.Y(nrows,ncols));
    
    fprintf('  Corner errors:\n');
    fprintf('    Ax1Err: TL=%.6f, TR=%.6f, BL=%.6f, BR=%.6f\n', ...
            zone_data.Ax1Err(1,1), zone_data.Ax1Err(1,ncols), ...
            zone_data.Ax1Err(nrows,1), zone_data.Ax1Err(nrows,ncols));
    fprintf('    Ax2Err: TL=%.6f, TR=%.6f, BL=%.6f, BR=%.6f\n', ...
            zone_data.Ax2Err(1,1), zone_data.Ax2Err(1,ncols), ...
            zone_data.Ax2Err(nrows,1), zone_data.Ax2Err(nrows,ncols));
end

fprintf('\n=== ZONE LAYOUT ANALYSIS ===\n');
% Analyze expected zone layout
% Assuming 2x2 grid: CZ1=top-left, CZ2=top-right, CZ3=bottom-left, CZ4=bottom-right
fprintf('Expected 2x2 zone layout:\n');
fprintf('  CZ1 (top-left)    | CZ2 (top-right)\n');
fprintf('  CZ3 (bottom-left) | CZ4 (bottom-right)\n');

% Check overlaps between zones
fprintf('\n=== OVERLAP ANALYSIS ===\n');

% Check horizontal overlap (CZ1-CZ2 and CZ3-CZ4)
for row = 1:numRow
    left_zone = (row-1)*numCol + 1;
    right_zone = left_zone + 1;
    
    if right_zone <= length(all_zones)
        left_data = all_zones{left_zone};
        right_data = all_zones{right_zone};
        
        left_x_max = max(max(left_data.X));
        right_x_min = min(min(right_data.X));
        h_overlap = left_x_max - right_x_min;
        
        fprintf('Row %d horizontal overlap (CZ%d-CZ%d): %.3f mm\n', row, left_zone, right_zone, h_overlap);
        fprintf('  Left zone X max: %.1f, Right zone X min: %.1f\n', left_x_max, right_x_min);
    end
end

% Check vertical overlap (CZ1-CZ3 and CZ2-CZ4) 
for col = 1:numCol
    top_zone = col;
    bottom_zone = col + numCol;
    
    if bottom_zone <= length(all_zones)
        top_data = all_zones{top_zone};
        bottom_data = all_zones{bottom_zone};
        
        top_y_min = min(min(top_data.Y));
        bottom_y_max = max(max(bottom_data.Y));
        v_overlap = bottom_y_max - top_y_min;
        
        fprintf('Col %d vertical overlap (CZ%d-CZ%d): %.3f mm\n', col, top_zone, bottom_zone, v_overlap);
        fprintf('  Top zone Y min: %.1f, Bottom zone Y max: %.1f\n', top_y_min, bottom_y_max);
    end
end

fprintf('\n=== STITCHING SIMULATION ===\n');
fprintf('Note: This is a simplified stitching preview\n');
fprintf('Full stitching would require:\n');
fprintf('1. Master-slave relationships\n');
fprintf('2. Slope corrections\n');
fprintf('3. Offset corrections\n');
fprintf('4. Iterative refinement\n');

% Calculate combined range if zones were simply merged
fprintf('\n=== COMBINED RANGE ESTIMATE ===\n');
all_x = [];
all_y = [];
all_ax1_err = [];
all_ax2_err = [];

for i = 1:length(all_zones)
    zone = all_zones{i};
    all_x = [all_x; zone.X(:)];
    all_y = [all_y; zone.Y(:)];
    all_ax1_err = [all_ax1_err; zone.Ax1Err(:)];
    all_ax2_err = [all_ax2_err; zone.Ax2Err(:)];
end

fprintf('Combined coordinate ranges:\n');
fprintf('  X: %.1f to %.1f mm (span: %.1f mm)\n', min(all_x), max(all_x), max(all_x)-min(all_x));
fprintf('  Y: %.1f to %.1f mm (span: %.1f mm)\n', min(all_y), max(all_y), max(all_y)-min(all_y));

fprintf('Combined error ranges (before stitching):\n');
fprintf('  Ax1Err: %.6f to %.6f μm\n', min(all_ax1_err), max(all_ax1_err));
fprintf('  Ax2Err: %.6f to %.6f μm\n', min(all_ax2_err), max(all_ax2_err));

% Save debug output
fprintf('\n=== SAVING DEBUG OUTPUT ===\n');
fid = fopen(out_dat_file, 'w');
fprintf(fid, '%% Octave Multizone 2D Calibration Debug Results\n');
fprintf(fid, '%% Processed zones: %d\n', length(all_zones));
fprintf(fid, '%% \n');
fprintf(fid, '%% Individual zone summaries:\n');

for i = 1:length(all_zones)
    zone = all_zones{i};
    fprintf(fid, '%% Zone %d:\n', i);
    fprintf(fid, '%%   X range: %.1f to %.1f mm\n', min(min(zone.X)), max(max(zone.X)));
    fprintf(fid, '%%   Y range: %.1f to %.1f mm\n', min(min(zone.Y)), max(max(zone.Y)));
    fprintf(fid, '%%   Ax1Err range: %.6f to %.6f μm\n', min(min(zone.Ax1Err)), max(max(zone.Ax1Err)));
    fprintf(fid, '%%   Ax2Err range: %.6f to %.6f μm\n', min(min(zone.Ax2Err)), max(max(zone.Ax2Err)));
end

fprintf(fid, '%% \n');
fprintf(fid, '%% Combined ranges:\n');
fprintf(fid, '%%   X: %.1f to %.1f mm\n', min(all_x), max(all_x));
fprintf(fid, '%%   Y: %.1f to %.1f mm\n', min(all_y), max(all_y));
fprintf(fid, '%%   Ax1Err: %.6f to %.6f μm\n', min(all_ax1_err), max(all_ax1_err));
fprintf(fid, '%%   Ax2Err: %.6f to %.6f μm\n', min(all_ax2_err), max(all_ax2_err));
fprintf(fid, '%% \n');

% Sample data from each zone for comparison
for zone_idx = 1:length(all_zones)
    zone = all_zones{zone_idx};
    fprintf(fid, '%% Zone %d sample data (X, Y, Ax1Err, Ax2Err):\n', zone_idx);
    
    [nrows, ncols] = size(zone.X);
    sample_rows = 1:min(5, nrows);
    sample_cols = 1:min(5, ncols);
    
    for i = sample_rows
        for j = sample_cols
            fprintf(fid, '%%.6f, %.6f, %.6f, %.6f  %% Zone%d[%d,%d]\n', ...
                    zone.X(i,j), zone.Y(i,j), zone.Ax1Err(i,j), zone.Ax2Err(i,j), ...
                    zone_idx, i, j);
        end
    end
    fprintf(fid, '%%\n');
end

fclose(fid);

fprintf('Debug output saved to: %s\n', out_dat_file);
fprintf('\n=== DEBUG ANALYSIS COMPLETE ===\n');

% Display key findings
fprintf('\nKEY FINDINGS FOR PYTHON COMPARISON:\n');
fprintf('1. Zone coordinate ranges and error ranges shown above\n');
fprintf('2. Overlap analysis shows spatial relationships\n');
fprintf('3. Combined ranges show what stitched result should approximate\n');
fprintf('4. Individual zone corner values available for detailed comparison\n');
fprintf('\nNext: Run this script and compare with Python multizone output\n');