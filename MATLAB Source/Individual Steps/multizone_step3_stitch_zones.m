function grid_system = multizone_step3_stitch_zones(setup, grid_system)
% MULTIZONE_STEP3_STITCH_ZONES - Process and stitch all zones in the multi-zone grid
%
% This function processes all zones beyond the first one, applying column and row
% stitching algorithms to create a seamless calibration map
%
% INPUT:
%   setup - structure from multizone_step1_setup containing configuration
%   grid_system - structure from multizone_step2_initialize_grid
%
% OUTPUT:
%   grid_system - updated structure with all zones processed and stitched

fprintf('Step 3: Processing and stitching all zones...\n');
fprintf('==============================================\n');

% Constants
y_meas_dir = -1;   % slope due to mirror misalignment is always opposite sign
                   % between axes when laser and encoder read positive in same direction

% Initialize master data for column and row stitching
colMaster = struct();  % Master for column stitching (within each row)
rowMaster = cell(setup.numRow, setup.numCol);  % Masters for row stitching

% Process all zones in row-major order
for i = 1:setup.numRow
    for j = 1:setup.numCol
        
        fprintf('----------------------------------------\n');
        fprintf('Processing Zone: Row %d, Col %d\n', i, j);
        
        % Skip first zone (already processed in Step 2)
        if (i == 1) && (j == 1)
            % First zone is already the master - just store references
            colMaster.X = grid_system.Ax1Master;
            colMaster.Y = grid_system.Ax2Master;
            colMaster.Ax1Err = grid_system.Ax1MasErr;
            colMaster.Ax2Err = grid_system.Ax2MasErr;
            rowMaster{i,j} = colMaster;
            
            fprintf('  First zone (already processed) - set as master\n');
            continue;
        end
        
        % Process current zone data
        zone_file = setup.zone_filenames{i,j};
        fprintf('  Loading: %s\n', zone_file);
        
        % Get zone data using single-zone pipeline
        config = step1_parse_header(zone_file);
        data_raw = step2_load_data(zone_file, config);
        grid_data = step3_create_grid(data_raw);
        slope_data = step4_calculate_slopes(grid_data);
        slave_data = step5_process_errors(grid_data, slope_data);
        
        % Store environmental data
        grid_system.airTemp(grid_system.zoneCount + 1) = str2double(config.airTemp);
        grid_system.matTemp(grid_system.zoneCount + 1) = str2double(config.matTemp);
        grid_system.comment{grid_system.zoneCount + 1} = config.comment;
        grid_system.fileDate{grid_system.zoneCount + 1} = config.fileDate;
        
        % Determine stitching type and master data
        if j > 1
            % Column stitching (same row, next column)
            fprintf('  Performing COLUMN stitching with previous zone\n');
            master = colMaster;
            stitch_type = 'column';
        else
            % Row stitching (next row, first column)
            fprintf('  Performing ROW stitching with zone from previous row\n');
            master = rowMaster{i-1,j};
            stitch_type = 'row';
        end
        
        % Apply stitching corrections
        slave_corrected = apply_stitching_corrections(master, slave_data, stitch_type, y_meas_dir);
        
        % Update masters for future stitching
        colMaster = slave_corrected;
        if (i > 1) && (j == 1)
            rowMaster{i,j} = slave_corrected;
        end
        
        % Calculate position in full grid for this zone
        arrayIndexAx1 = round((slave_corrected.X(1,1) - grid_system.X(1,1)) / grid_system.incAx1) + 1;
        arrayIndexAx2 = round((slave_corrected.Y(1,1) - grid_system.Y(1,1)) / grid_system.incAx2) + 1;
        
        slaveSize = size(slave_corrected.X);
        rangeAx1 = arrayIndexAx1:(arrayIndexAx1 + slaveSize(2) - 1);
        rangeAx2 = arrayIndexAx2:(arrayIndexAx2 + slaveSize(1) - 1);
        
        fprintf('  Adding to full grid at indices: Ax1=[%d:%d], Ax2=[%d:%d]\n', ...
                rangeAx1(1), rangeAx1(end), rangeAx2(1), rangeAx2(end));
        
        % Add corrected zone data to full travel matrices
        grid_system.X(rangeAx2, rangeAx1) = grid_system.X(rangeAx2, rangeAx1) + slave_corrected.X;
        grid_system.Y(rangeAx2, rangeAx1) = grid_system.Y(rangeAx2, rangeAx1) + slave_corrected.Y;
        grid_system.Ax1Err(rangeAx2, rangeAx1) = grid_system.Ax1Err(rangeAx2, rangeAx1) + slave_corrected.Ax1Err;
        grid_system.Ax2Err(rangeAx2, rangeAx1) = grid_system.Ax2Err(rangeAx2, rangeAx1) + slave_corrected.Ax2Err;
        grid_system.avgCount(rangeAx2, rangeAx1) = grid_system.avgCount(rangeAx2, rangeAx1) + ones(slaveSize);
        
        grid_system.zoneCount = grid_system.zoneCount + 1;
        fprintf('  Zone %d processed successfully\n', grid_system.zoneCount);
    end
end

fprintf('\n=== ZONE STITCHING SUMMARY ===\n');
fprintf('Total zones processed: %d\n', grid_system.zoneCount);
fprintf('Non-zero accumulation points: %d\n', sum(sum(grid_system.avgCount > 0)));
fprintf('Max accumulation count: %d\n', max(max(grid_system.avgCount)));
fprintf('==============================\n\n');

end


function slave_corrected = apply_stitching_corrections(master, slave, stitch_type, y_meas_dir)
% Apply stitching corrections to align slave zone with master zone
%
% INPUT:
%   master - master zone data structure
%   slave - slave zone data structure  
%   stitch_type - 'column' or 'row' stitching
%   y_meas_dir - measurement direction factor for orthogonality
%
% OUTPUT:
%   slave_corrected - corrected slave zone data

slave_corrected = slave;  % Copy slave data

if strcmp(stitch_type, 'column')
    % Column stitching: stitching adjacent zones in same row (Axis 1 direction)
    
    % Find overlap regions
    master_overlap_idx = find(master.X(1,:) >= min(min(slave.X)));
    slave_overlap_idx = find(slave.X(1,:) <= max(max(master.X)));
    
    if isempty(master_overlap_idx) || isempty(slave_overlap_idx)
        fprintf('    Warning: No overlap found for column stitching\n');
        return;
    end
    
    fprintf('    Overlap: Master cols %d-%d, Slave cols %d-%d\n', ...
            master_overlap_idx(1), master_overlap_idx(end), ...
            slave_overlap_idx(1), slave_overlap_idx(end));
    
    % Calculate mean error curves in overlap regions for Ax1
    master_ax1_mean = mean(master.Ax1Err(:, master_overlap_idx), 2);
    slave_ax1_mean = mean(slave.Ax1Err(:, slave_overlap_idx), 2);
    
    % Fit linear slopes to mean curves
    master_coef_ax1 = polyfit(master.Y(:,1), master_ax1_mean, 1);
    slave_coef_ax1 = polyfit(slave.Y(:,1), slave_ax1_mean, 1);
    
    fprintf('    Ax1 slope correction: Master=%.6f, Slave=%.6f um/mm\n', ...
            master_coef_ax1(1), slave_coef_ax1(1));
    
    % Apply Ax1 slope corrections to all columns
    for n = 1:size(slave.X, 2)
        slave_corrected.Ax1Err(:, n) = slave_corrected.Ax1Err(:, n) - ...
                                      polyval(slave_coef_ax1, slave.Y(:,1)) + ...
                                      polyval(master_coef_ax1, slave.Y(:,1));
    end
    
    % Apply Ax2 orthogonality correction (coupled to Ax1)
    master_coef_ax2_orth = y_meas_dir * master_coef_ax1;
    slave_coef_ax2_orth = y_meas_dir * slave_coef_ax1;
    
    for n = 1:size(slave.Y, 1)
        slave_corrected.Ax2Err(n, :) = slave_corrected.Ax2Err(n, :) - ...
                                      polyval(slave_coef_ax2_orth, slave.X(n,:)) + ...
                                      polyval(master_coef_ax2_orth, slave.X(n,:));
    end
    
    % Apply offset corrections to match mean levels in overlap regions
    master_ax1_offset = mean(mean(master.Ax1Err(:, master_overlap_idx)));
    slave_ax1_offset = mean(mean(slave_corrected.Ax1Err(:, slave_overlap_idx)));
    ax1_correction = master_ax1_offset - slave_ax1_offset;
    
    master_ax2_offset = mean(mean(master.Ax2Err(:, master_overlap_idx)));
    slave_ax2_offset = mean(mean(slave_corrected.Ax2Err(:, slave_overlap_idx)));
    ax2_correction = master_ax2_offset - slave_ax2_offset;
    
    slave_corrected.Ax1Err = slave_corrected.Ax1Err + ax1_correction;
    slave_corrected.Ax2Err = slave_corrected.Ax2Err + ax2_correction;
    
    fprintf('    Offset corrections: Ax1=%.3f, Ax2=%.3f um\n', ax1_correction, ax2_correction);
    
else  % row stitching
    % Row stitching: stitching zones in next row (Axis 2 direction)
    
    % Find overlap regions
    master_overlap_idx = find(master.Y(:,1) >= min(min(slave.Y)));
    slave_overlap_idx = find(slave.Y(:,1) <= max(max(master.Y)));
    
    if isempty(master_overlap_idx) || isempty(slave_overlap_idx)
        fprintf('    Warning: No overlap found for row stitching\n');
        return;
    end
    
    fprintf('    Overlap: Master rows %d-%d, Slave rows %d-%d\n', ...
            master_overlap_idx(1), master_overlap_idx(end), ...
            slave_overlap_idx(1), slave_overlap_idx(end));
    
    % Calculate mean error curves in overlap regions for Ax2
    master_ax2_mean = mean(master.Ax2Err(master_overlap_idx, :), 1);
    slave_ax2_mean = mean(slave.Ax2Err(slave_overlap_idx, :), 1);
    
    % Fit linear slopes to mean curves
    master_coef_ax2 = polyfit(master.X(1,:), master_ax2_mean, 1);
    slave_coef_ax2 = polyfit(slave.X(1,:), slave_ax2_mean, 1);
    
    fprintf('    Ax2 slope correction: Master=%.6f, Slave=%.6f um/mm\n', ...
            master_coef_ax2(1), slave_coef_ax2(1));
    
    % Apply Ax2 slope corrections to all rows
    for n = 1:size(slave.Y, 1)
        slave_corrected.Ax2Err(n, :) = slave_corrected.Ax2Err(n, :) - ...
                                      polyval(slave_coef_ax2, slave.X(n,:)) + ...
                                      polyval(master_coef_ax2, slave.X(n,:));
    end
    
    % Apply offset corrections to match mean levels in overlap regions  
    master_ax1_offset = mean(mean(master.Ax1Err(master_overlap_idx, :)));
    slave_ax1_offset = mean(mean(slave_corrected.Ax1Err(slave_overlap_idx, :)));
    ax1_correction = master_ax1_offset - slave_ax1_offset;
    
    master_ax2_offset = mean(mean(master.Ax2Err(master_overlap_idx, :)));
    slave_ax2_offset = mean(mean(slave_corrected.Ax2Err(slave_overlap_idx, :)));
    ax2_correction = master_ax2_offset - slave_ax2_offset;
    
    slave_corrected.Ax1Err = slave_corrected.Ax1Err + ax1_correction;
    slave_corrected.Ax2Err = slave_corrected.Ax2Err + ax2_correction;
    
    fprintf('    Offset corrections: Ax1=%.3f, Ax2=%.3f um\n', ax1_correction, ax2_correction);
end

end
