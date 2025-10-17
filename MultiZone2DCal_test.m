<<<<<<< HEAD
d% MultiZone2DCal_test - Octave-compatible version for debugging
=======
% MultiZone2DCal_test - Octave-compatible version for debugging
>>>>>>> 1b00b7410a0cc79cd6530b4b3a616e5aa7f43a11
% This simplified version processes 4 zones and outputs debug information
% for comparison with Python implementation

clear all;
close all;

% Set up paths and filenames
zone_files = {
    'MATLAB Source/642583-1-1-CZ1.dat',
<<<<<<< HEAD
    'MATLAB Source/642583-1-1-CZ2.dat',
    'MATLAB Source/642583-1-1-CZ3.dat',
    'MATLAB Source/pwd642583-1-1-CZ4.dat'
=======
    'MATLAB Source/642583-1-1-CZ2.dat', 
    'MATLAB Source/642583-1-1-CZ3.dat',
    'MATLAB Source/642583-1-1-CZ4.dat'
>>>>>>> 1b00b7410a0cc79cd6530b4b3a616e5aa7f43a11
};

% Grid parameters
numRow = 2;
numCol = 2;

% Output files
out_cal_file = 'octave_multizone.cal';
out_dat_file = 'octave_multizone.dat';

fprintf('=== OCTAVE MULTIZONE 2D CALIBRATION TEST ===\n');
fprintf('Processing %d zones in %dx%d grid\n', length(zone_files), numRow, numCol);

y_meas_dir = -1;
zone_count = 0;

<<<<<<< HEAD
% Process zones in row-major order
=======
% Process zones in row-major order  
>>>>>>> 1b00b7410a0cc79cd6530b4b3a616e5aa7f43a11
for i = 1:numRow
    for j = 1:numCol
        zone_idx = (i-1)*numCol + j;
        zone_file = zone_files{zone_idx};
<<<<<<< HEAD

        fprintf('\n--- Processing Zone %d: Row %d, Col %d -> %s ---\n', zone_count+1, i, j, zone_file);

=======
        
        fprintf('\n--- Processing Zone %d: Row %d, Col %d -> %s ---\n', zone_count+1, i, j, zone_file);
        
>>>>>>> 1b00b7410a0cc79cd6530b4b3a616e5aa7f43a11
        if (i == 1) && (j == 1)  % First zone
            fprintf('Processing first zone as master reference\n');
            data = A3200ACC2DMULTIZONE(zone_file);
            zone_count = zone_count + 1;
<<<<<<< HEAD

            % Store master data
            Ax1Master = data.X;
            Ax2Master = data.Y;
            Ax1MasErr = data.Ax1Err;
            Ax2MasErr = data.Ax2Err;

=======
            
            % Store master data
            Ax1Master = data.X;
            Ax2Master = data.Y; 
            Ax1MasErr = data.Ax1Err;
            Ax2MasErr = data.Ax2Err;
            
>>>>>>> 1b00b7410a0cc79cd6530b4b3a616e5aa7f43a11
            % Store row master for next row
            rowAx1Master = Ax1Master;
            rowAx2Master = Ax2Master;
            rowAx1MasErr = Ax1MasErr;
            rowAx2MasErr = Ax2MasErr;
<<<<<<< HEAD

=======
            
>>>>>>> 1b00b7410a0cc79cd6530b4b3a616e5aa7f43a11
            % Store system info
            SN = data.SN;
            Ax1Name = data.Ax1Name;
            Ax2Name = data.Ax2Name;
            Ax1Num = data.Ax1Num;
            Ax2Num = data.Ax2Num;
            Ax1Sign = data.Ax1Sign;
            Ax2Sign = data.Ax2Sign;
<<<<<<< HEAD

=======
            
>>>>>>> 1b00b7410a0cc79cd6530b4b3a616e5aa7f43a11
        else
            % Convert previous slave to master if not first zone
            if exist('Ax1Slave', 'var')
                Ax1Master = Ax1Slave;
                Ax2Master = Ax2Slave;
                Ax1MasErr = Ax1SlaveErr;
                Ax2MasErr = Ax2SlaveErr;
            end
        end
<<<<<<< HEAD

=======
        
>>>>>>> 1b00b7410a0cc79cd6530b4b3a616e5aa7f43a11
        % Process subsequent zones
        if j ~= numCol  % Not last column - do column stitching
            fprintf('Column stitching: processing next column zone\n');
            slave_data = A3200ACC2DMULTIZONE(zone_files{zone_idx + 1});
            zone_count = zone_count + 1;
<<<<<<< HEAD

=======
            
>>>>>>> 1b00b7410a0cc79cd6530b4b3a616e5aa7f43a11
            Ax1Slave = slave_data.X;
            Ax2Slave = slave_data.Y;
            Ax1SlaveErr = slave_data.Ax1Err;
            Ax2SlaveErr = slave_data.Ax2Err;
<<<<<<< HEAD

            % Find overlap
            overlap_ax1 = max(max(Ax1Master)) - min(min(Ax1Slave));
            fprintf('  Column overlap distance: %.3f mm\n', overlap_ax1);

=======
            
            % Find overlap
            overlap_ax1 = max(max(Ax1Master)) - min(min(Ax1Slave));
            fprintf('  Column overlap distance: %.3f mm\n', overlap_ax1);
            
>>>>>>> 1b00b7410a0cc79cd6530b4b3a616e5aa7f43a11
            % Find overlap indices (simplified)
            Ax1size = size(Ax1Master);
            k = 1;
            while k <= size(Ax1Slave, 2) && Ax1Slave(1,k) < max(max(Ax1Master))
                k = k + 1;
            end
<<<<<<< HEAD

            if k > 1
                m_range = (Ax1size(2)-k+2):Ax1size(2);  % Master overlap columns
                s_range = 1:(k-1);  % Slave overlap columns

                fprintf('  Overlap ranges: Master cols %d-%d, Slave cols %d-%d\n', ...
                        m_range(1), m_range(end), s_range(1), s_range(end));

=======
            
            if k > 1
                m_range = (Ax1size(2)-k+2):Ax1size(2);  % Master overlap columns
                s_range = 1:(k-1);  % Slave overlap columns
                
                fprintf('  Overlap ranges: Master cols %d-%d, Slave cols %d-%d\n', ...
                        m_range(1), m_range(end), s_range(1), s_range(end));
                
>>>>>>> 1b00b7410a0cc79cd6530b4b3a616e5aa7f43a11
                % Calculate mean errors in overlap region
                Ax1MasErrMean = mean(Ax1MasErr(:, m_range), 2);
                Ax2MasErrMean = mean(Ax2MasErr(:, m_range), 1);
                Ax1SlaveErrMean = mean(Ax1SlaveErr(:, s_range), 2);
                Ax2SlaveErrMean = mean(Ax2SlaveErr(:, s_range), 1);
<<<<<<< HEAD

                % Fit slopes
                mcoef = polyfit(Ax2Master(:,1), Ax1MasErrMean, 1);
                scoef = polyfit(Ax2Slave(:,1), Ax1SlaveErrMean, 1);
                mcoef2 = polyfit(Ax1Master(1,:), Ax2MasErrMean, 1);
                scoef2 = polyfit(Ax1Slave(1,:), Ax2SlaveErrMean, 1);

                fprintf('  Ax1 slope correction: Master=%.6f, Slave=%.6f\n', mcoef(1), scoef(1));
                fprintf('  Ax2 slope correction: Master=%.6f, Slave=%.6f\n', mcoef2(1), scoef2(1));

=======
                
                % Fit slopes
                mcoef = polyfit(Ax2Master(:,1), Ax1MasErrMean, 1);
                scoef = polyfit(Ax2Slave(:,1), Ax1SlaveErrMean, 1);
                mcoef2 = polyfit(Ax1Master(1,:), Ax2MasErrMean, 1);  
                scoef2 = polyfit(Ax1Slave(1,:), Ax2SlaveErrMean, 1);
                
                fprintf('  Ax1 slope correction: Master=%.6f, Slave=%.6f\n', mcoef(1), scoef(1));
                fprintf('  Ax2 slope correction: Master=%.6f, Slave=%.6f\n', mcoef2(1), scoef2(1));
                
>>>>>>> 1b00b7410a0cc79cd6530b4b3a616e5aa7f43a11
                % Apply slope corrections
                Ax1size = size(Ax1Slave);
                for n = 1:Ax1size(1)
                    Ax2SlaveErr(n,:) = Ax2SlaveErr(n,:) - polyval(y_meas_dir * scoef, Ax1Slave(1,:)) + polyval(y_meas_dir * mcoef, Ax1Slave(1,:));
                end
                for n = 1:Ax1size(2)
                    Ax1SlaveErr(:,n) = Ax1SlaveErr(:,n) - polyval(scoef, Ax2Slave(:,1)) + polyval(mcoef, Ax2Slave(:,1));
                end
<<<<<<< HEAD

                % Apply offset corrections
                ax1_correction = mean(mean(Ax1MasErr(:, m_range))) - mean(mean(Ax1SlaveErr(:, s_range)));
                ax2_correction = mean(mean(Ax2MasErr(:, m_range))) - mean(mean(Ax2SlaveErr(:, s_range)));

                Ax1SlaveErr = Ax1SlaveErr + ax1_correction;
                Ax2SlaveErr = Ax2SlaveErr + ax2_correction;

                fprintf('  Offset corrections: Ax1=%.6f, Ax2=%.6f\n', ax1_correction, ax2_correction);
            end

            % Advance to next column
            j = j + 1;
        end

=======
                
                % Apply offset corrections
                ax1_correction = mean(mean(Ax1MasErr(:, m_range))) - mean(mean(Ax1SlaveErr(:, s_range)));
                ax2_correction = mean(mean(Ax2MasErr(:, m_range))) - mean(mean(Ax2SlaveErr(:, s_range)));
                
                Ax1SlaveErr = Ax1SlaveErr + ax1_correction;
                Ax2SlaveErr = Ax2SlaveErr + ax2_correction;
                
                fprintf('  Offset corrections: Ax1=%.6f, Ax2=%.6f\n', ax1_correction, ax2_correction);
            end
            
            % Advance to next column
            j = j + 1;
        end
        
>>>>>>> 1b00b7410a0cc79cd6530b4b3a616e5aa7f43a11
        % Row stitching (simplified for this test)
        if (i > 1) && (j == 1)  % First column of non-first row
            fprintf('Row stitching: would process row transition here\n');
            % Implementation would go here for full version
        end
    end
end

fprintf('\n=== MULTIZONE PROCESSING COMPLETE ===\n');
fprintf('Processed %d zones\n', zone_count);

% Save a simple output file for comparison
fprintf('Writing simplified output file: %s\n', out_dat_file);
if exist('Ax1SlaveErr', 'var') && exist('Ax2SlaveErr', 'var')
    fid = fopen(out_dat_file, 'w');
    fprintf(fid, '%% Octave Multizone 2D Calibration Test Results\n');
    fprintf(fid, '%% Zones processed: %d\n', zone_count);
    fprintf(fid, '%% Final zone error ranges:\n');
    fprintf(fid, '%%   Ax1Err: %.6f to %.6f\n', min(min(Ax1SlaveErr)), max(max(Ax1SlaveErr)));
    fprintf(fid, '%%   Ax2Err: %.6f to %.6f\n', min(min(Ax2SlaveErr)), max(max(Ax2SlaveErr)));
    fprintf(fid, '%% Sample points from final zone:\n');
<<<<<<< HEAD

=======
    
>>>>>>> 1b00b7410a0cc79cd6530b4b3a616e5aa7f43a11
    for i = 1:min(10, size(Ax1Slave,1))
        for j = 1:min(10, size(Ax1Slave,2))
            fprintf(fid, '%.6f, %.6f, %.6f, %.6f\n', ...
                    Ax1Slave(i,j), Ax2Slave(i,j), Ax1SlaveErr(i,j), Ax2SlaveErr(i,j));
        end
    end
    fclose(fid);
end

<<<<<<< HEAD
fprintf('\nTest completed!\n');
=======
fprintf('\nTest completed!\n');
>>>>>>> 1b00b7410a0cc79cd6530b4b3a616e5aa7f43a11
