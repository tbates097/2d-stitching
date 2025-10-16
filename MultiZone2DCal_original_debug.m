% MultiZone2DCal_original_debug.m - Octave-compatible exact MATLAB algorithm with debug
% This is the EXACT original MATLAB algorithm converted to work in Octave with debug output

clear all
close all

fprintf('=== OCTAVE MULTIZONE 2D CALIBRATION - ORIGINAL ALGORITHM WITH DEBUG ===\n');

%%%%%%%%%%%%%%%% Set Calibration File Options %%%%%%%%%%%%%%%%%%%%
WriteCalFile = 1;  %0 = do not write cal file, 1 = write cal file
OutAxis3 = 0;      %0 = no gantry slave, 1 = gantry slave axis
OutAx3Value = 2;   %if OutAxis3 = 1, sets the master axis of the gantry.
                   %sign is negative if the encoder directions are
                   %opposite between the master and slave axes
CalFile = '642583-1-1-2D_octave_debug.cal';
UserUnit = 'METRIC';  % user units = 'METRIC' or 'ENGLISH'
                      % correction units are "user units"/1000

writeOutputFile = 1;
OutFile = '642583-1-1-2DAccuracy_octave_debug.dat';                      

%%%%%%%%%%%%%%%% Set Calibration Zone Parameters %%%%%%%%%%%%%%%%%%%%
numRow = 2;                 % number of calibration zone rows (how many zones in Axis 2 (Step axis) direction)
numCol = 2;                 % number of calibration zone columns (how many zones in Axis 1 (Scan axis) direction)
travelAx1 = ([-250 250]);      % full calibrated travel for Axis 1 (scan axis)
travelAx2 = ([-250 250]);      % full calibrated travel for Axis 2 (step axis)

fprintf('Configuration:\n');
fprintf('  Grid layout: %dx%d zones\n', numRow, numCol);
fprintf('  Travel ranges: Ax1=[%.1f to %.1f], Ax2=[%.1f to %.1f]\n', ...
        travelAx1(1), travelAx1(2), travelAx2(1), travelAx2(2));

%%%%%%%%%%%%%%%% GRAPH SUB-TITLE (CALIBRATION STATUS) %%%%%%%%%%%%%%%
sTitle = {'Uncalibrated'};

zscaling = 2;  % rounding increment for z scale in charts

   % set data file names for various zones
counter = 0;
for i = 1:numRow
    for j = 1:numCol
        counter = counter + 1;
        fName(i,j) = {sprintf('MATLAB Source/642583-1-1-CZ%u.dat', counter)};
    end
end

fprintf('\nZone files:\n');
for i = 1:numRow
    for j = 1:numCol
        fprintf('  Zone [%d,%d]: %s\n', i, j, char(fName(i,j)));
    end
end

%%%%%%%%%%%%%%%% Data Postprocessing %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
y_meas_dir = -1;   % slope due to mirror misalignment is always opposite sign
                   % between the axes when the laser and encoder read positive
                   % in the same direction

fprintf('\n=== STARTING MULTIZONE PROCESSING ===\n');
fprintf('y_meas_dir = %d\n', y_meas_dir);

zoneCount = 0;                   
for i = 1:numRow
    fprintf('\n--- PROCESSING ROW %d ---\n', i);
    for j = 1:numCol
        fprintf('\n=== PROCESSING ZONE [%d,%d] ===\n', i, j);
        
        if (i == 1) && (j == 1)     % open data for the first zone
            fprintf('Processing first zone as master reference\n');
            data = A3200Acc2DMultiZone_Octave(char(fName(i,j)));
            zoneCount = zoneCount + 1;
            
            fprintf('DEBUG: Zone 1 loaded\n');
            fprintf('  X range: %.1f to %.1f mm\n', min(min(data.X)), max(max(data.X)));
            fprintf('  Y range: %.1f to %.1f mm\n', min(min(data.Y)), max(max(data.Y)));
            fprintf('  Ax1Err range: %.6f to %.6f μm\n', min(min(data.Ax1Err)), max(max(data.Ax1Err)));
            fprintf('  Ax2Err range: %.6f to %.6f μm\n', min(min(data.Ax2Err)), max(max(data.Ax2Err)));
            
            % set master axis for subsequent column comparison
            Ax1Master = data.X;    % master Axis 1 position -- scan axis
            Ax2Master = data.Y;    % master Axis 2 position -- step axis
            Ax1MasErr = data.Ax1Err;  % master Ax1 position error wrt Ax1 and Ax2 positions
            Ax2MasErr = data.Ax2Err;  % master Ax2 position error wrt Ax1 and Ax2 positions
            
            % set master axis for subsequent row comparison
            rowAx1Master = Ax1Master;   % master Axis 1 position -- scan axis
            rowAx2Master = Ax2Master;
            rowAx1MasErr = Ax1MasErr;
            rowAx2MasErr = Ax2MasErr;
            
            % read system parameters for axes names, numbers, serial number, etc.
            SN = data.SN;
            Ax1Name = data.Ax1Name;
            Ax2Name = data.Ax2Name;
            Ax1Num = data.Ax1Num;
            Ax2Num = data.Ax2Num;
            Ax1Sign = data.Ax1Sign;
            Ax2Sign = data.Ax2Sign;
            UserUnit = data.UserUnit;      
            calDivisor = data.calDivisor;          
            posUnit = data.posUnit;           
            errUnit = data.errUnit;
            Ax1Gantry = data.Ax1Gantry;
            Ax2Gantry = data.Ax2Gantry;
            Ax1SampDist = data.Ax1SampDist;
            Ax2SampDist = data.Ax2SampDist;
            operator = data.operator;       
            model = data.model;     
            airTemp = str2double(data.airTemp);
            matTemp = str2double(data.matTemp);
            expandCoef = data.expandCoef;
            comment = {data.comment};
            fileDate = {data.fileDate};
            
            fprintf('DEBUG: System parameters loaded\n');
            fprintf('  SN: %s, Ax1Name: %s, Ax2Name: %s\n', SN, Ax1Name, Ax2Name);
            
            % determine the step size used to generate each calibration grid
            incAx1 = Ax1Master(1,2) - Ax1Master(1,1);
            incAx2 = Ax2Master(2,1) - Ax2Master(1,1);
            
            fprintf('DEBUG: Grid increments: incAx1=%.6f, incAx2=%.6f\n', incAx1, incAx2);
            
            % initialize full travel matrices X, Y, Ax1Err, and Ax2Err
            % in this step, just generate empty (zero) vectors with the correct size
            X = zeros(round((travelAx2(2)-travelAx2(1))/incAx2 + 1), ...
                round((travelAx1(2)-travelAx1(1))/incAx1 + 1));  %Axis1 Position
            Y = X;         %Axis 2 Position
            Ax1Err = X;    %Axis 1 Error with respect to X and Y
            Ax2Err = X;    %Axis 2 Error with respect to X and Y
            avgCount = X;  % 2d matrix to keep track of how many averages 
                             %occur in the overlap regions
            
            fprintf('DEBUG: Initialized full travel matrices\n');
            fprintf('  Full grid size: %dx%d\n', size(X,1), size(X,2));
            
            Ax1size = size(Ax1Master);
            Ax2size = size(Ax2Master);
            arrayIndexAx1 = 1;  % offset index in Axis 1 direction for this zone
            arrayIndexAx2 = 1;  % offset index in Axis 2 direction for this zone
            rangeAx1 = arrayIndexAx1-1+(1:Ax1size(2));  % Ax1 range of full travel vectors that correspond to this zone
            rangeAx2 = arrayIndexAx2-1+(1:Ax2size(1));  % Ax2 range of full travel vectors that correspond to this zone
             
            fprintf('DEBUG: Zone 1 placement in full grid\n');
            fprintf('  arrayIndexAx1=%d, arrayIndexAx2=%d\n', arrayIndexAx1, arrayIndexAx2);
            fprintf('  rangeAx1: %d to %d, rangeAx2: %d to %d\n', ...
                    rangeAx1(1), rangeAx1(end), rangeAx2(1), rangeAx2(end));
            
            % add this zone's positions and errors to the full travel
            % vectors.  update the average count variable so the average
            % can be taken later
            X(rangeAx2, rangeAx1) = X(rangeAx2, rangeAx1) + Ax1Master;
            Y(rangeAx2, rangeAx1) = Y(rangeAx2, rangeAx1) + Ax2Master;
            Ax1Err(rangeAx2, rangeAx1) = Ax1Err(rangeAx2, rangeAx1) + Ax1MasErr;
            Ax2Err(rangeAx2, rangeAx1) = Ax2Err(rangeAx2, rangeAx1) + Ax2MasErr;
            avgCount(rangeAx2, rangeAx1) = avgCount(rangeAx2, rangeAx1) + ones(size(Ax1Master)); 
            
            fprintf('DEBUG: Zone 1 added to full travel matrices\n');
            %%%%%% section end for processing the first zone
        else
            fprintf('Converting previous slave to new master\n');
            % for all zones other than Zone 1, a previous slave zone
            % becomes the new master zone. 
            
            %clear the previous master values
            clear Ax1Master
            clear Ax2Master
            clear Ax1MasErr
            clear Ax2MasErr
            
            %convert the old slave values to master values
            Ax1Master = Ax1Slave;
            Ax2Master = Ax2Slave;
            Ax1MasErr = Ax1SlaveErr;
            Ax2MasErr = Ax2SlaveErr;
            
            fprintf('DEBUG: New master established\n');
            fprintf('  Master X range: %.1f to %.1f mm\n', min(min(Ax1Master)), max(max(Ax1Master)));
            fprintf('  Master Y range: %.1f to %.1f mm\n', min(min(Ax2Master)), max(max(Ax2Master)));
            
            %clear the previous slave values
            clear Ax1Slave;
            clear Ax2Slave;
            clear Ax1SlaveErr
            clear Ax2SlaveErr
        end
        
        % if there is more than one column in the grid, march across the
        % columns, stitching the zones together
        if j ~= numCol
            fprintf('\n--- COLUMN STITCHING: Zone [%d,%d] -> Zone [%d,%d] ---\n', i, j, i, j+1);
        
        % read the data for the next column zone and write into slave variables
        clear data    % clear the previous data structure
        data = A3200Acc2DMultiZone_Octave(char(fName(i,j+1)));
        zoneCount = zoneCount + 1;
        Ax1Slave = data.X;   % write Axis 1 position values to variable
        Ax2Slave = data.Y;   % write Axis 2 position values to variable
        Ax1SlaveErr = data.Ax1Err;  % write Axis 1 error values to variable
        Ax2SlaveErr = data.Ax2Err;  % write Axis 2 error values to variable
        
        fprintf('DEBUG: Slave zone loaded\n');
        fprintf('  Slave X range: %.1f to %.1f mm\n', min(min(Ax1Slave)), max(max(Ax1Slave)));
        fprintf('  Slave Y range: %.1f to %.1f mm\n', min(min(Ax2Slave)), max(max(Ax2Slave)));
        fprintf('  Slave Ax1Err range: %.6f to %.6f μm\n', min(min(Ax1SlaveErr)), max(max(Ax1SlaveErr)));
        fprintf('  Slave Ax2Err range: %.6f to %.6f μm\n', min(min(Ax2SlaveErr)), max(max(Ax2SlaveErr)));
        
        overlapAx1 = max(max(Ax1Master))-min(min(Ax1Slave));  % determine overlap distance
        Ax1size = size(Ax1Master);
        airTemp(zoneCount) = str2double(data.airTemp);
        matTemp(zoneCount) = str2double(data.matTemp);
        comment(zoneCount) = {data.comment};
        fileDate{zoneCount} = {data.fileDate};
        
        fprintf('DEBUG: Column overlap analysis\n');
        fprintf('  Master X_max: %.1f, Slave X_min: %.1f\n', max(max(Ax1Master)), min(min(Ax1Slave)));
        fprintf('  Overlap distance: %.3f mm\n', overlapAx1);
        
        % find number of matrix indices in the overlap region
        k = 1;
        while k <= size(Ax1Slave, 2) && Ax1Slave(1,k) < max(max(Ax1Master))
            k = k+1;
        end
        
        fprintf('DEBUG: Overlap indices calculation\n');
        fprintf('  k (overlap boundary index) = %d\n', k);
        
        % set the index values of the master and slave overlap ranges
        mRange = ((Ax1size(2)-k+2): Ax1size(2));
        sRange = (1:k-1);
        
        fprintf('DEBUG: Overlap ranges\n');
        fprintf('  Master overlap columns: %d to %d (count: %d)\n', mRange(1), mRange(end), length(mRange));
        fprintf('  Slave overlap columns: %d to %d (count: %d)\n', sRange(1), sRange(end), length(sRange));
        
        % calculate the mean error curves in for ax1, ax2 in both the master and 
         % slave overlap regions.  These are vectors, not scalars.
        Ax1MasErrMean = mean(Ax1MasErr(:,mRange),2);
        Ax2MasErrMean = mean(Ax2MasErr(:,mRange));
        Ax1SlaveErrMean = mean(Ax1SlaveErr(:,sRange),2);
        Ax2SlaveErrMean = mean(Ax2SlaveErr(:,sRange));
        
        fprintf('DEBUG: Overlap region mean errors calculated\n');
        fprintf('  Master overlap Ax1Err range: %.6f to %.6f μm\n', min(Ax1MasErrMean), max(Ax1MasErrMean));
        fprintf('  Master overlap Ax2Err range: %.6f to %.6f μm\n', min(Ax2MasErrMean), max(Ax2MasErrMean));
        fprintf('  Slave overlap Ax1Err range: %.6f to %.6f μm\n', min(Ax1SlaveErrMean), max(Ax1SlaveErrMean));
        fprintf('  Slave overlap Ax2Err range: %.6f to %.6f μm\n', min(Ax2SlaveErrMean), max(Ax2SlaveErrMean));
        
        % get best line fit coefficients for the mean straightness error for
         % both the master and slave zones.  
        mcoef2 = polyfit(Ax1Master(1,mRange), Ax2MasErrMean, 1);
        scoef2 = polyfit(Ax1Slave(1,sRange), Ax2SlaveErrMean,1);
        
        mcoef = polyfit(Ax2Master(:,1), Ax1MasErrMean, 1);
        scoef = polyfit(Ax2Slave(:,1), Ax1SlaveErrMean,1);
        
        fprintf('DEBUG: Slope coefficients calculated\n');
        fprintf('  Master Ax1 slope (mcoef): [%.6f, %.6f]\n', mcoef(1), mcoef(2));
        fprintf('  Slave Ax1 slope (scoef): [%.6f, %.6f]\n', scoef(1), scoef(2));
        fprintf('  Master Ax2 slope (mcoef2): [%.6f, %.6f]\n', mcoef2(1), mcoef2(2));
        fprintf('  Slave Ax2 slope (scoef2): [%.6f, %.6f]\n', scoef2(1), scoef2(2));
        
        % subtract the straightness slope of the slave from the slave and
         % then add the straightness slope of the master to the slave.  Do
         % this in both Ax1 and Ax2 straightnesses so that the orthogonality
         % measurement is not distorted.
        Ax1size = size(Ax1Slave); 
        for n = 1:Ax1size(1)
            Ax2SlaveErr(n,:) = Ax2SlaveErr(n,:)-polyval(y_meas_dir * scoef, Ax1Slave(1,:)) + polyval(y_meas_dir * mcoef,Ax1Slave(1,:));
        end
        
        for n = 1:Ax1size(2)
            Ax1SlaveErr(:,n) = Ax1SlaveErr(:,n)-polyval(scoef, Ax2Slave(:,1)) + polyval(mcoef,Ax2Slave(:,1));
        end

        fprintf('DEBUG: Slope corrections applied\n');
        
        % subtract the accuracy scalar mean of the slave data from the slave and
         % then add the accuracy scalar mean of the master to the slave.
        ax1_offset_correction = mean(mean(Ax1MasErr(:,mRange))) - mean(mean(Ax1SlaveErr(:,sRange)));
        ax2_offset_correction = mean(mean(Ax2MasErr(:,mRange))) - mean(mean(Ax2SlaveErr(:,sRange)));
        
        Ax2SlaveErr = Ax2SlaveErr + ax2_offset_correction;
        Ax1SlaveErr = Ax1SlaveErr + ax1_offset_correction;
        
        fprintf('DEBUG: Offset corrections applied\n');
        fprintf('  Ax1 offset correction: %.6f μm\n', ax1_offset_correction);
        fprintf('  Ax2 offset correction: %.6f μm\n', ax2_offset_correction);
        fprintf('  Slave after correction - Ax1Err range: %.6f to %.6f μm\n', min(min(Ax1SlaveErr)), max(max(Ax1SlaveErr)));
        fprintf('  Slave after correction - Ax2Err range: %.6f to %.6f μm\n', min(min(Ax2SlaveErr)), max(max(Ax2SlaveErr)));
        
        % add this zone's positions and errors to the full travel
         % vectors.  update the average count variable so the average
         % can be taken later        
        Ax1size = size(Ax1Slave);
        Ax2size = size(Ax2Slave);
        arrayIndexAx1 = round((Ax1Slave(1,1)-X(1,1))/incAx1 + 1);
        arrayIndexAx2 = round((Ax2Slave(1,1)-Y(1,1))/incAx2 + 1);
        rangeAx1 = (arrayIndexAx1-1+(1:Ax1size(2)));
        rangeAx2 = arrayIndexAx2-1+(1:Ax2size(1));
        
        fprintf('DEBUG: Adding corrected slave to full grid\n');
        fprintf('  arrayIndexAx1=%d, arrayIndexAx2=%d\n', arrayIndexAx1, arrayIndexAx2);
        fprintf('  rangeAx1: %d to %d, rangeAx2: %d to %d\n', ...
                rangeAx1(1), rangeAx1(end), rangeAx2(1), rangeAx2(end));
        
        X(rangeAx2, rangeAx1) = X(rangeAx2, rangeAx1) + Ax1Slave;
        Y(rangeAx2, rangeAx1) = Y(rangeAx2, rangeAx1) + Ax2Slave;
        Ax1Err(rangeAx2, rangeAx1) = Ax1Err(rangeAx2, rangeAx1) + Ax1SlaveErr;
        Ax2Err(rangeAx2, rangeAx1) = Ax2Err(rangeAx2, rangeAx1) + Ax2SlaveErr;
        avgCount(rangeAx2, rangeAx1) = avgCount(rangeAx2, rangeAx1) + ones(size(Ax1Slave));
        
        fprintf('DEBUG: Slave zone added to full travel matrices\n');
        
        end
    end  % end of column loop
    
    % now that all columns have been processed, jump to first column of next row.
    if i ~= numRow
        fprintf('\n--- ROW STITCHING: Row %d -> Row %d ---\n', i, i+1);
        clear data  % clear the previous data file from memory
        data = A3200Acc2DMultiZone_Octave(char(fName(i+1,1)));
        zoneCount = zoneCount + 1;
        Ax1Slave = data.X;  % store axis 1 position      
        Ax2Slave = data.Y;  % store axis 2 position
        Ax1SlaveErr = data.Ax1Err;  % store axis 1 error
        Ax2SlaveErr = data.Ax2Err;  % store axis 2 error
        airTemp(zoneCount) = str2double(data.airTemp);
        matTemp(zoneCount) = str2double(data.matTemp);
        comment(zoneCount) = {data.comment};
        fileDate(zoneCount) = {data.fileDate};
        
        fprintf('DEBUG: Row slave zone loaded\n');
        fprintf('  Slave X range: %.1f to %.1f mm\n', min(min(Ax1Slave)), max(max(Ax1Slave)));
        fprintf('  Slave Y range: %.1f to %.1f mm\n', min(min(Ax2Slave)), max(max(Ax2Slave)));
        
        % find overlap between this slave zone and the row master zone 
        overlapAx2 = max(max(rowAx2Master))-min(min(Ax2Slave)); 
        Ax2size = size(rowAx2Master);
        
        fprintf('DEBUG: Row overlap analysis\n');
        fprintf('  Row master Y_max: %.1f, Row slave Y_min: %.1f\n', max(max(rowAx2Master)), min(min(Ax2Slave)));
        fprintf('  Row overlap distance: %.3f mm\n', overlapAx2);
        
        % find number of matrix indices in the overlap region
        k = 1;
        while k <= size(Ax2Slave, 1) && Ax2Slave(k,1) < max(max(rowAx2Master))
            k = k+1;
        end
        
        fprintf('DEBUG: Row overlap indices\n');
        fprintf('  k (row overlap boundary) = %d\n', k);
        
        % set the index values of the master and slave overlap ranges
        mRange = ((Ax2size(1)-k+2): Ax2size(1));
        sRange = (1:k-1); 
        
        fprintf('DEBUG: Row overlap ranges\n');
        fprintf('  Row master overlap rows: %d to %d (count: %d)\n', mRange(1), mRange(end), length(mRange));
        fprintf('  Row slave overlap rows: %d to %d (count: %d)\n', sRange(1), sRange(end), length(sRange));
        
        % calculate the mean error curves in for ax1, ax2 in both the master and 
         % slave overlap regions.  These are vectors, not scalars.    
        Ax1MasErrMean = mean(rowAx1MasErr(mRange,:),2);  
        Ax2MasErrMean = mean(rowAx2MasErr(mRange,:));
        Ax1SlaveErrMean = mean(Ax1SlaveErr(sRange,:),2); 
        Ax2SlaveErrMean = mean(Ax2SlaveErr(sRange,:));
        
        fprintf('DEBUG: Row overlap mean errors calculated\n');
        fprintf('  Row master overlap Ax1Err range: %.6f to %.6f μm\n', min(Ax1MasErrMean), max(Ax1MasErrMean));
        fprintf('  Row master overlap Ax2Err range: %.6f to %.6f μm\n', min(Ax2MasErrMean), max(Ax2MasErrMean));
        fprintf('  Row slave overlap Ax1Err range: %.6f to %.6f μm\n', min(Ax1SlaveErrMean), max(Ax1SlaveErrMean));
        fprintf('  Row slave overlap Ax2Err range: %.6f to %.6f μm\n', min(Ax2SlaveErrMean), max(Ax2SlaveErrMean));
        
        % get best line fit coefficients for the mean straightness error    
        mcoef = polyfit(rowAx1Master(1,:), Ax2MasErrMean, 1);
        scoef = polyfit(Ax1Slave(1,:), Ax2SlaveErrMean,1);

        fprintf('DEBUG: Row slope coefficients\n');
        fprintf('  Row master Ax2 slope (mcoef): [%.6f, %.6f]\n', mcoef(1), mcoef(2));
        fprintf('  Row slave Ax2 slope (scoef): [%.6f, %.6f]\n', scoef(1), scoef(2));

        % subtract the straightness slope of the slave from the slave and
         % then add the straightness slope of the master to the slave.
        for n = 1:Ax2size(1)
            Ax2SlaveErr(n,:) = Ax2SlaveErr(n,:)-polyval(scoef, Ax1Slave(1,:)) + polyval(mcoef, Ax1Slave(1,:));
        end
        for n = 1:Ax2size(2)
            Ax1SlaveErr(:,n) = Ax1SlaveErr(:,n)-polyval(y_meas_dir * scoef, Ax2Slave(:,1)) + polyval(y_meas_dir * mcoef,Ax2Slave(:,1));
        end    

        fprintf('DEBUG: Row slope corrections applied\n');

        % subtract the straightness scalar mean of the slave data from the slave and
         % then add the straightness scalar mean of the master to the slave.    
        ax2_row_offset = mean(mean(rowAx2MasErr(mRange,:))) - mean(mean(Ax2SlaveErr(sRange,:)));
        ax1_row_offset = mean(mean(rowAx1MasErr(mRange,:))) - mean(mean(Ax1SlaveErr(sRange,:)));
        
        Ax2SlaveErr = Ax2SlaveErr + ax2_row_offset;
        Ax1SlaveErr = Ax1SlaveErr + ax1_row_offset;

        fprintf('DEBUG: Row offset corrections applied\n');
        fprintf('  Row Ax1 offset correction: %.6f μm\n', ax1_row_offset);
        fprintf('  Row Ax2 offset correction: %.6f μm\n', ax2_row_offset);

        % add this zone's positions and errors to the full travel vectors      
        Ax1size = size(Ax1Slave);
        Ax2size = size(Ax2Slave);
        arrayIndexAx1 = round((Ax1Slave(1,1)-X(1,1))/incAx1 + 1);
        arrayIndexAx2 = round((Ax2Slave(1,1)-Y(1,1))/incAx2 + 1);
        rangeAx1 = arrayIndexAx1-1+(1:Ax1size(2));
        rangeAx2 = arrayIndexAx2-1+(1:Ax2size(1));    
        
        fprintf('DEBUG: Adding row-corrected slave to full grid\n');
        fprintf('  arrayIndexAx1=%d, arrayIndexAx2=%d\n', arrayIndexAx1, arrayIndexAx2);
        
        X(rangeAx2, rangeAx1) = X(rangeAx2, rangeAx1) + Ax1Slave;
        Y(rangeAx2, rangeAx1) = Y(rangeAx2, rangeAx1) + Ax2Slave;
        Ax1Err(rangeAx2, rangeAx1) = Ax1Err(rangeAx2, rangeAx1) + Ax1SlaveErr;
        Ax2Err(rangeAx2, rangeAx1) = Ax2Err(rangeAx2, rangeAx1) + Ax2SlaveErr;
        avgCount(rangeAx2, rangeAx1) = avgCount(rangeAx2, rangeAx1) + ones(size(Ax1Slave));
                
        clear rowAx1Master
        clear rowAx2Master
        clear rowAx1MasErr
        clear rowAx2MasErr
        
        rowAx1Master = Ax1Slave;
        rowAx2Master = Ax2Slave;
        rowAx1MasErr = Ax1SlaveErr;
        rowAx2MasErr = Ax2SlaveErr;
        
        fprintf('DEBUG: Row master updated for next row\n');
    end
end  % end of row loop

fprintf('\n=== FINALIZING STITCHED DATA ===\n');

% divide through by the avgCount to complete the average in the overlap regions
totalSize = size(X);
fprintf('DEBUG: Averaging overlap regions\n');
fprintf('  Total stitched grid size: %dx%d\n', totalSize(1), totalSize(2));

for i = 1:totalSize(1)
    for j = 1:totalSize(2)
        if avgCount(i,j) > 0
            X(i,j) = X(i,j)/avgCount(i,j);
            Y(i,j) = Y(i,j)/avgCount(i,j);
            Ax1Err(i,j) = Ax1Err(i,j)/avgCount(i,j);
            Ax2Err(i,j) = Ax2Err(i,j)/avgCount(i,j);
        end
    end
end

NumAx1Points = totalSize(2);
NumAx2Points = totalSize(1);

fprintf('DEBUG: Final stitched data before slope removal\n');
fprintf('  Combined X range: %.1f to %.1f mm\n', min(min(X)), max(max(X)));
fprintf('  Combined Y range: %.1f to %.1f mm\n', min(min(Y)), max(max(Y)));
fprintf('  Combined Ax1Err range: %.6f to %.6f μm\n', min(min(Ax1Err)), max(max(Ax1Err)));
fprintf('  Combined Ax2Err range: %.6f to %.6f μm\n', min(min(Ax2Err)), max(max(Ax2Err)));

%%%%%%%%%%%%%%%% Data Plotting - REMOVE BEST FIT SLOPE AND CALCULATE ORTHOGONALITY
fprintf('\n=== FINAL SLOPE REMOVAL AND ORTHOGONALITY ===\n');

% line fit the straightness error data with respect to the stage position
Ax1Coef = polyfit(Y(:,1), mean(Ax1Err,2),1);   % slope units microns/mm
Ax2Coef = polyfit(X(1,:),mean(Ax2Err),1);   % slope units microns/mm

fprintf('DEBUG: Final slope coefficients\n');
fprintf('  Final Ax1Coef: [%.6f, %.6f]\n', Ax1Coef(1), Ax1Coef(2));
fprintf('  Final Ax2Coef: [%.6f, %.6f]\n', Ax2Coef(1), Ax2Coef(2));

% create best fit line for X data, use X line for Y data (to calibrate in orthogonality)
Ax1Line = polyval(Ax1Coef, Y(:,1));
Ax2Line = polyval(y_meas_dir * Ax1Coef, X(1,:));

% create straightness data for orthogonality plots (remove best fit lines)
Ax1Orthog = mean(Ax1Err,2) - Ax1Line;
Ax2Orthog = mean(Ax2Err) - polyval(Ax2Coef, X(1,:));

% subtract the line fits from the Ax1 and Ax2 error data (remove mirror slope)
for i = 1:totalSize(2)
    Ax1Err(:,i) = Ax1Err(:,i) - Ax1Line;
end
for i = 1:totalSize(1)
    Ax2Err(i,:) = Ax2Err(i,:) - Ax2Line;
end

% calculate orthogonality
orthog = Ax1Coef(1) - y_meas_dir * Ax2Coef(1);
orthog = atan(orthog/1000) * 180/pi * 3600;  % arc sec

fprintf('DEBUG: Orthogonality calculated: %.6f arc-sec\n', orthog);

% CALCULATE THE VECTOR SUM ACCURACY ERROR
fprintf('\n=== FINAL ERROR PROCESSING ===\n');

% subtract error at origin of xy grid prior to vector sum calculation
zero_ref_ax1 = Ax1Err(1,1);
zero_ref_ax2 = Ax2Err(1,1);
Ax1Err = Ax1Err - zero_ref_ax1;
Ax2Err = Ax2Err - zero_ref_ax2;

fprintf('DEBUG: Zero-referencing applied\n');
fprintf('  Zero-ref offsets: Ax1=%.6f, Ax2=%.6f μm\n', zero_ref_ax1, zero_ref_ax2);

% calculate the total vector sum accuracy error
VectorErr = sqrt(Ax1Err.^2 + Ax2Err.^2);

% calculate peak to peak values
pkAx1 = max(max(Ax1Err))-min(min(Ax1Err));
pkAx2 = max(max(Ax2Err))-min(min(Ax2Err));

fprintf('\n=== FINAL RESULTS ===\n');
fprintf('Final stitched and processed ranges:\n');
fprintf('  X: %.1f to %.1f mm (span: %.1f mm)\n', min(min(X)), max(max(X)), max(max(X))-min(min(X)));
fprintf('  Y: %.1f to %.1f mm (span: %.1f mm)\n', min(min(Y)), max(max(Y)), max(max(Y))-min(min(Y)));
fprintf('  Ax1Err: %.6f to %.6f μm (pk-pk: %.6f μm)\n', min(min(Ax1Err)), max(max(Ax1Err)), pkAx1);
fprintf('  Ax2Err: %.6f to %.6f μm (pk-pk: %.6f μm)\n', min(min(Ax2Err)), max(max(Ax2Err)), pkAx2);
fprintf('  VectorErr: %.6f to %.6f μm\n', min(min(VectorErr)), max(max(VectorErr)));
fprintf('  Orthogonality: %.6f arc-sec\n', orthog);
fprintf('Total zones processed: %d\n', zoneCount);

% Save debug results
out_file = 'octave_original_multizone_debug.dat';
fid = fopen(out_file, 'w');
fprintf(fid, '%% MATLAB/Octave Original Multizone Algorithm Debug Results\n');
fprintf(fid, '%% Total zones processed: %d\n', zoneCount);
fprintf(fid, '%% Grid layout: %dx%d\n', numRow, numCol);
fprintf(fid, '%% \n');
fprintf(fid, '%% Final stitched results:\n');
fprintf(fid, '%%   X: %.1f to %.1f mm (span: %.1f mm)\n', min(min(X)), max(max(X)), max(max(X))-min(min(X)));
fprintf(fid, '%%   Y: %.1f to %.1f mm (span: %.1f mm)\n', min(min(Y)), max(max(Y)), max(max(Y))-min(min(Y)));
fprintf(fid, '%%   Ax1Err: %.6f to %.6f μm (pk-pk: %.6f μm)\n', min(min(Ax1Err)), max(max(Ax1Err)), pkAx1);
fprintf(fid, '%%   Ax2Err: %.6f to %.6f μm (pk-pk: %.6f μm)\n', min(min(Ax2Err)), max(max(Ax2Err)), pkAx2);
fprintf(fid, '%%   VectorErr: %.6f to %.6f μm\n', min(min(VectorErr)), max(max(VectorErr)));
fprintf(fid, '%%   Orthogonality: %.6f arc-sec\n', orthog);
fprintf(fid, '%%   Zero-ref offsets: Ax1=%.6f, Ax2=%.6f μm\n', zero_ref_ax1, zero_ref_ax2);
fclose(fid);

fprintf('\nDebug output saved to: %s\n', out_file);
fprintf('MATLAB/Octave original algorithm debug complete!\n');