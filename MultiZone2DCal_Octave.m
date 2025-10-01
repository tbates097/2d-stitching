% This script manages the multi-zone stitching and saves debug files at each step.

clear all;
close all;

% --- Helper function for saving debug data ---
function save_debug_stitch_file(filename, X, Y, Ax1Err, Ax2Err, avg_count)
disp(['Saving debug data to ' filename]);
fid = fopen(filename, 'w');
fprintf(fid, '# X_pos, Y_pos, Ax1_Err, Ax2_Err\n');
for r = 1:size(X, 1)
for c = 1:size(X, 2)
if avg_count(r,c) > 0
fprintf(fid, '%.4f, %.4f, %.8f, %.8f\n', X(r,c), Y(r,c), Ax1Err(r,c), Ax2Err(r,c));
end
end
end
fclose(fid);
end

% --- Main script execution ---
numRow = input("Enter the number of calibration zone rows: ");
numCol = input("Enter the number of calibration zone columns: ");
travelAx1_min = input("Enter the minimum calibrated travel for Axis 1: ");
travelAx1_max = input("Enter the maximum calibrated travel for Axis 1: ");
travelAx2_min = input("Enter the minimum calibrated travel for Axis 2: ");
travelAx2_max = input("Enter the maximum calibrated travel for Axis 2: ");
travelAx1 = [travelAx1_min, travelAx1_max];
travelAx2 = [travelAx2_min, travelAx2_max];

disp("\nPlease provide the data file path for each zone:");
fName = cell(numRow, numCol);
for i = 1:numRow
for j = 1:numCol
prompt = sprintf("  - Enter file for Row %d, Column %d: ", i, j);
fpath = input(prompt, 's');
fName{i, j} = strrep(fpath, '"', '');
end
end

y_meas_dir = -1;

% Initialize variables
Ax1Err_full = [];
Ax2Err_full = [];
avg_count = [];
X_full = [];
Y_full = [];
stitched_data_info = struct();
col_master_data = struct();
row_master_data_list = cell(1, numCol);

for i = 1:numRow
for j = 1:numCol
fprintf('----------------------------------------\n');
fprintf('Processing Zone: Row %d, Col %d (%s)\n', i, j, fName{i,j});

    slave_data = A3200Acc2DMultiZone_Octave(char(fName{i,j}));

    if (i == 1) && (j == 1)
        stitched_data_info = slave_data;

        incAx1 = slave_data.X(1,2) - slave_data.X(1,1);
        incAx2 = slave_data.Y(2,1) - slave_data.Y(1,1);

        x_vec = travelAx1(1):incAx1:travelAx1(2);
        y_vec = (travelAx2(1):incAx2:travelAx2(2))';
        [X_full, Y_full] = meshgrid(x_vec, y_vec);

        Ax1Err_full = zeros(size(X_full));
        Ax2Err_full = zeros(size(X_full));
        avg_count = zeros(size(X_full));

        col_master_data = slave_data;
        row_master_data_list{j} = slave_data;
    else
        if j > 1 % --- Column stitch ---
            master_data = col_master_data;
        else % --- Row stitch (j == 1) ---
            master_data = row_master_data_list{j};
        end

        if j > 1
            master_overlap_indices = find(master_data.X(1,:) >= min(min(slave_data.X)));
            slave_overlap_indices = find(slave_data.X(1,:) <= max(max(master_data.X)));

            ax1_master_mean_overlap = mean(master_data.Ax1Err(:, master_overlap_indices), 2);
            ax1_slave_mean_overlap = mean(slave_data.Ax1Err(:, slave_overlap_indices), 2);

            mcoef_ax1 = polyfit(master_data.Y(:,1), ax1_master_mean_overlap, 1);
            scoef_ax1 = polyfit(slave_data.Y(:,1), ax1_slave_mean_overlap, 1);

            for n = 1:size(slave_data.X, 2)
                slave_data.Ax1Err(:, n) = slave_data.Ax1Err(:, n) - polyval(scoef_ax1, slave_data.Y(:, 1)) + polyval(mcoef_ax1, slave_data.Y(:, 1));
            end

            mcoef_ax2_from_ax1 = y_meas_dir * mcoef_ax1;
            scoef_ax2_from_ax1 = y_meas_dir * scoef_ax1;

            for n = 1:size(slave_data.Y, 1)
                slave_data.Ax2Err(n, :) = slave_data.Ax2Err(n, :) - polyval(scoef_ax2_from_ax1, slave_data.X(n, :)) + polyval(mcoef_ax2_from_ax1, slave_data.X(n, :));
            end

            slave_data.Ax2Err = slave_data.Ax2Err + (mean(mean(master_data.Ax2Err(:, master_overlap_indices))) - mean(mean(slave_data.Ax2Err(:, slave_overlap_indices))));
            slave_data.Ax1Err = slave_data.Ax1Err + (mean(mean(master_data.Ax1Err(:, master_overlap_indices))) - mean(mean(slave_data.Ax1Err(:, slave_overlap_indices))));
        else % Row stitch
            master_overlap_indices = find(master_data.Y(:,1) >= min(min(slave_data.Y)));
            slave_overlap_indices = find(slave_data.Y(:,1) <= max(max(master_data.Y)));

            ax2_master_mean_overlap = mean(master_data.Ax2Err(master_overlap_indices, :), 1);
            ax2_slave_mean_overlap = mean(slave_data.Ax2Err(slave_overlap_indices, :), 1);

            mcoef_ax2 = polyfit(master_data.X(1,:), ax2_master_mean_overlap, 1);
            scoef_ax2 = polyfit(slave_data.X(1,:), ax2_slave_mean_overlap, 1);

            for n = 1:size(slave_data.Y, 1)
                slave_data.Ax2Err(n, :) = slave_data.Ax2Err(n, :) - polyval(scoef_ax2, slave_data.X(n, :)) + polyval(mcoef_ax2, slave_data.X(n, :));
            end

            slave_data.Ax1Err = slave_data.Ax1Err + (mean(mean(master_data.Ax1Err(master_overlap_indices, :))) - mean(mean(slave_data.Ax1Err(slave_overlap_indices, :))));
            slave_data.Ax2Err = slave_data.Ax2Err + (mean(mean(master_data.Ax2Err(master_overlap_indices, :))) - mean(mean(slave_data.Ax2Err(slave_overlap_indices, :))));
        end

        col_master_data = slave_data;
        if (i > 1 && j==1)
            row_master_data_list{j} = slave_data;
        end
    end

    [~, x_start_idx] = min(abs(X_full(1,:) - slave_data.X(1,1)));
    [~, y_start_idx] = min(abs(Y_full(:,1) - slave_data.Y(1,1)));
    [rows, cols] = size(slave_data.X);

    Ax1Err_full(y_start_idx:y_start_idx+rows-1, x_start_idx:x_start_idx+cols-1) = Ax1Err_full(y_start_idx:y_start_idx+rows-1, x_start_idx:x_start_idx+cols-1) + slave_data.Ax1Err;
    Ax2Err_full(y_start_idx:y_start_idx+rows-1, x_start_idx:x_start_idx+cols-1) = Ax2Err_full(y_start_idx:y_start_idx+rows-1, x_start_idx:x_start_idx+cols-1) + slave_data.Ax2Err;
    avg_count(y_start_idx:y_start_idx+rows-1, x_start_idx:x_start_idx+cols-1) = avg_count(y_start_idx:y_start_idx+rows-1, x_start_idx:x_start_idx+cols-1) + 1;

    if ~((i == 1) && (j == 1))
        debug_filename = sprintf('Octave_Stitch_Step_R%dC%d.txt', i, j);
        non_zero_avg = avg_count;
        non_zero_avg(non_zero_avg == 0) = 1;
        save_debug_stitch_file(debug_filename, X_full, Y_full, Ax1Err_full ./ non_zero_avg, Ax2Err_full ./ non_zero_avg, avg_count);
    end
end

end
disp('Stitching debug process complete.');
