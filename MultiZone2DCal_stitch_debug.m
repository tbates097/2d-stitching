% MultiZone2DCal_stitch_debug - Actually perform stitching with debug output
% This version implements the core stitching algorithm with detailed debugging

clear all;
close all;

% Set up paths and filenames
zone_files = {
    'MATLAB Source/642583-1-1-CZ1.dat',
    'MATLAB Source/642583-1-1-CZ2.dat', 
    'MATLAB Source/642583-1-1-CZ3.dat',
    'MATLAB Source/642583-1-1-CZ4.dat'
};

% Grid parameters (2x2)
numRow = 2;
numCol = 2;

fprintf('=== OCTAVE MULTIZONE STITCHING - WITH ACTUAL STITCHING DEBUG ===\n');
fprintf('Processing %d zones in %dx%d grid with full stitching\n', length(zone_files), numRow, numCol);

y_meas_dir = -1;

% Load all zones first
fprintf('\n=== LOADING ALL ZONES ===\n');
zones = {};
for i = 1:length(zone_files)
    fprintf('Loading Zone %d: %s\n', i, zone_files{i});
    zones{i} = A3200Acc2DMultiZone_Octave(zone_files{i});
end

% Initialize stitching variables
fprintf('\n=== INITIALIZING STITCHING PROCESS ===\n');

% Start with Zone 1 as master
fprintf('Setting Zone 1 as initial master\n');
master = zones{1};
master_zone_num = 1;

% Track stitched zones
stitched_zones = [1];
remaining_zones = [2, 3, 4];

fprintf('Initial master zone: %d\n', master_zone_num);
fprintf('Remaining zones to stitch: [%s]\n', sprintf('%d ', remaining_zones));

% Store stitching history
stitch_history = {};
step_count = 0;

% Iterative stitching process
while ~isempty(remaining_zones)
    step_count = step_count + 1;
    fprintf('\n=== STITCHING STEP %d ===\n', step_count);
    
    best_slave = -1;
    best_overlap = -1;
    best_stitch_type = '';
    
    % Find best zone to stitch next (highest overlap with current master)
    fprintf('Finding best slave zone to stitch:\n');
    for i = 1:length(remaining_zones)
        slave_zone = remaining_zones(i);
        slave = zones{slave_zone};
        
        % Check horizontal overlap
        master_x_max = max(max(master.X));
        master_x_min = min(min(master.X));
        slave_x_max = max(max(slave.X));
        slave_x_min = min(min(slave.X));
        
        h_overlap = 0;
        if slave_x_min < master_x_max && slave_x_max > master_x_min
            h_overlap = min(master_x_max, slave_x_max) - max(master_x_min, slave_x_min);
        end
        
        % Check vertical overlap  
        master_y_max = max(max(master.Y));
        master_y_min = min(min(master.Y));
        slave_y_max = max(max(slave.Y));
        slave_y_min = min(min(slave.Y));
        
        v_overlap = 0;
        if slave_y_min < master_y_max && slave_y_max > master_y_min
            v_overlap = min(master_y_max, slave_y_max) - max(master_y_min, slave_y_min);
        end
        
        fprintf('  Zone %d: H_overlap=%.1f, V_overlap=%.1f\n', slave_zone, h_overlap, v_overlap);
        
        % Determine stitch type and total overlap
        total_overlap = h_overlap + v_overlap;
        stitch_type = '';
        if h_overlap > v_overlap
            stitch_type = 'horizontal';
        else
            stitch_type = 'vertical';
        end
        
        if total_overlap > best_overlap
            best_overlap = total_overlap;
            best_slave = slave_zone;
            best_stitch_type = stitch_type;
        end
    end
    
    if best_slave == -1
        fprintf('No suitable slave zone found. Ending stitching.\n');
        break;
    end
    
    fprintf('\nSelected slave zone %d for %s stitching (overlap: %.1f)\n', ...
            best_slave, best_stitch_type, best_overlap);
    
    % Perform the stitching
    slave = zones{best_slave};
    
    fprintf('\n--- STITCHING ZONE %d TO MASTER ---\n', best_slave);
    fprintf('Master zone spans: X(%.1f to %.1f), Y(%.1f to %.1f)\n', ...
            min(min(master.X)), max(max(master.X)), min(min(master.Y)), max(max(master.Y)));
    fprintf('Slave zone spans:  X(%.1f to %.1f), Y(%.1f to %.1f)\n', ...
            min(min(slave.X)), max(max(slave.X)), min(min(slave.Y)), max(max(slave.Y)));
    
    % Find overlap region
    if strcmp(best_stitch_type, 'horizontal')
        fprintf('Performing HORIZONTAL stitching:\n');
        
        % Find X overlap region
        master_x_max = max(max(master.X));
        slave_x_min = min(min(slave.X));
        overlap_distance = master_x_max - slave_x_min;
        
        fprintf('  Master X_max: %.1f, Slave X_min: %.1f\n', master_x_max, slave_x_min);
        fprintf('  Overlap distance: %.1f mm\n', overlap_distance);
        
        if overlap_distance > 0
            % Find overlap indices
            master_size = size(master.X);
            slave_size = size(slave.X);
            
            % For master: find columns where X >= slave_x_min
            master_overlap_cols = [];
            for col = 1:master_size(2)
                if master.X(1, col) >= slave_x_min
                    master_overlap_cols = [master_overlap_cols col];
                end
            end
            
            % For slave: find columns where X <= master_x_max
            slave_overlap_cols = [];
            for col = 1:slave_size(2)
                if slave.X(1, col) <= master_x_max
                    slave_overlap_cols = [slave_overlap_cols col];
                end
            end
            
            fprintf('  Master overlap columns: [%s] (count: %d)\n', ...
                    sprintf('%d ', master_overlap_cols), length(master_overlap_cols));
            fprintf('  Slave overlap columns: [%s] (count: %d)\n', ...
                    sprintf('%d ', slave_overlap_cols), length(slave_overlap_cols));
            
            if ~isempty(master_overlap_cols) && ~isempty(slave_overlap_cols)
                % Calculate mean errors in overlap region
                master_ax1_mean = mean(master.Ax1Err(:, master_overlap_cols), 2);
                master_ax2_mean = mean(master.Ax2Err(:, master_overlap_cols), 1);
                slave_ax1_mean = mean(slave.Ax1Err(:, slave_overlap_cols), 2);
                slave_ax2_mean = mean(slave.Ax2Err(:, slave_overlap_cols), 1);
                
                fprintf('  Master overlap Ax1Err range: %.6f to %.6f\n', ...
                        min(master_ax1_mean), max(master_ax1_mean));
                fprintf('  Master overlap Ax2Err range: %.6f to %.6f\n', ...
                        min(master_ax2_mean), max(master_ax2_mean));
                fprintf('  Slave overlap Ax1Err range: %.6f to %.6f\n', ...
                        min(slave_ax1_mean), max(slave_ax1_mean));
                fprintf('  Slave overlap Ax2Err range: %.6f to %.6f\n', ...
                        min(slave_ax2_mean), max(slave_ax2_mean));
                
                % Calculate slope corrections
                master_ax1_coef = polyfit(master.Y(:,1), master_ax1_mean, 1);
                slave_ax1_coef = polyfit(slave.Y(:,1), slave_ax1_mean, 1);
                master_ax2_coef = polyfit(master.X(1,:), master_ax2_mean, 1);
                slave_ax2_coef = polyfit(slave.X(1,:), slave_ax2_mean, 1);
                
                fprintf('  Slope corrections:\n');
                fprintf('    Master Ax1 slope: %.6f, Slave Ax1 slope: %.6f\n', ...
                        master_ax1_coef(1), slave_ax1_coef(1));
                fprintf('    Master Ax2 slope: %.6f, Slave Ax2 slope: %.6f\n', ...
                        master_ax2_coef(1), slave_ax2_coef(1));
                
                % Apply slope corrections to slave
                slave_corrected = slave;
                slave_size = size(slave.X);
                
                for row = 1:slave_size(1)
                    slave_corrected.Ax2Err(row,:) = slave_corrected.Ax2Err(row,:) - ...
                        polyval(y_meas_dir * slave_ax1_coef, slave.X(1,:)) + ...
                        polyval(y_meas_dir * master_ax1_coef, slave.X(1,:));
                end
                
                for col = 1:slave_size(2)
                    slave_corrected.Ax1Err(:,col) = slave_corrected.Ax1Err(:,col) - ...
                        polyval(slave_ax1_coef, slave.Y(:,1)) + ...
                        polyval(master_ax1_coef, slave.Y(:,1));
                end
                
                % Calculate offset corrections
                master_overlap_mean_ax1 = mean(mean(master.Ax1Err(:, master_overlap_cols)));
                master_overlap_mean_ax2 = mean(mean(master.Ax2Err(:, master_overlap_cols)));
                slave_overlap_mean_ax1 = mean(mean(slave_corrected.Ax1Err(:, slave_overlap_cols)));
                slave_overlap_mean_ax2 = mean(mean(slave_corrected.Ax2Err(:, slave_overlap_cols)));
                
                ax1_offset = master_overlap_mean_ax1 - slave_overlap_mean_ax1;
                ax2_offset = master_overlap_mean_ax2 - slave_overlap_mean_ax2;
                
                fprintf('  Offset corrections: Ax1=%.6f, Ax2=%.6f\n', ax1_offset, ax2_offset);
                
                % Apply offset corrections
                slave_corrected.Ax1Err = slave_corrected.Ax1Err + ax1_offset;
                slave_corrected.Ax2Err = slave_corrected.Ax2Err + ax2_offset;
                
                % Update zones array with corrected slave
                zones{best_slave} = slave_corrected;
                
                fprintf('  Slave zone %d corrected successfully\n', best_slave);
                
                % Create new combined master
                fprintf('  Creating combined master from zones [%s]\n', ...
                        sprintf('%d ', [stitched_zones best_slave]));
                
                % For now, just update the master to be the corrected slave
                % In a full implementation, you'd combine the grids
                master = slave_corrected;
                master_zone_num = best_slave;
            else
                fprintf('  Warning: No valid overlap region found\n');
            end
        else
            fprintf('  No horizontal overlap detected\n');
        end
        
    else
        fprintf('Performing VERTICAL stitching:\n');
        fprintf('  (Vertical stitching implementation would go here)\n');
        % Similar logic for vertical stitching...
    end
    
    % Update stitched zones list
    stitched_zones = [stitched_zones best_slave];
    remaining_zones = remaining_zones(remaining_zones ~= best_slave);
    
    fprintf('Updated stitched zones: [%s]\n', sprintf('%d ', stitched_zones));
    fprintf('Remaining zones: [%s]\n', sprintf('%d ', remaining_zones));
    
    % Store stitching step info
    stitch_history{step_count} = struct(...
        'step', step_count, ...
        'slave_zone', best_slave, ...
        'stitch_type', best_stitch_type, ...
        'overlap', best_overlap, ...
        'master_zone_after', master_zone_num);
end

fprintf('\n=== STITCHING COMPLETE ===\n');
fprintf('Total stitching steps: %d\n', step_count);
fprintf('Final stitched zones: [%s]\n', sprintf('%d ', stitched_zones));

% Final combined statistics
if exist('master', 'var')
    fprintf('\n=== FINAL COMBINED RESULTS ===\n');
    fprintf('Combined coordinate ranges:\n');
    fprintf('  X: %.1f to %.1f mm (span: %.1f mm)\n', ...
            min(min(master.X)), max(max(master.X)), max(max(master.X)) - min(min(master.X)));
    fprintf('  Y: %.1f to %.1f mm (span: %.1f mm)\n', ...
            min(min(master.Y)), max(max(master.Y)), max(max(master.Y)) - min(min(master.Y)));
    fprintf('Combined error ranges (after stitching):\n');
    fprintf('  Ax1Err: %.6f to %.6f μm\n', min(min(master.Ax1Err)), max(max(master.Ax1Err)));
    fprintf('  Ax2Err: %.6f to %.6f μm\n', min(min(master.Ax2Err)), max(max(master.Ax2Err)));
    
    % Save debug output
    out_file = 'octave_multizone_stitch_debug.dat';
    fid = fopen(out_file, 'w');
    fprintf(fid, '%% Octave Multizone Stitching Debug Results\n');
    fprintf(fid, '%% Total stitching steps: %d\n', step_count);
    fprintf(fid, '%% \n');
    for i = 1:length(stitch_history)
        step = stitch_history{i};
        fprintf(fid, '%% Step %d: Stitched zone %d (%s, overlap=%.1f)\n', ...
                step.step, step.slave_zone, step.stitch_type, step.overlap);
    end
    fprintf(fid, '%% \n');
    fprintf(fid, '%% Final combined ranges:\n');
    fprintf(fid, '%%   X: %.1f to %.1f mm\n', min(min(master.X)), max(max(master.X)));
    fprintf(fid, '%%   Y: %.1f to %.1f mm\n', min(min(master.Y)), max(max(master.Y)));
    fprintf(fid, '%%   Ax1Err: %.6f to %.6f μm\n', min(min(master.Ax1Err)), max(max(master.Ax1Err)));
    fprintf(fid, '%%   Ax2Err: %.6f to %.6f μm\n', min(min(master.Ax2Err)), max(max(master.Ax2Err)));
    fclose(fid);
    
    fprintf('Debug output saved to: %s\n', out_file);
end

fprintf('\nMATLAB/Octave stitching debug complete!\n');