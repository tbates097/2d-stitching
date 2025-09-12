clear all
close all

%%%%%%%%%%%%%%% Set working directory
% cd 'C:\Program Files\MATLAB704\work\D051219 2D Calibration Stitched'

%%%%%%%%%%%%%%%% Set Calibration File Options %%%%%%%%%%%%%%%%%%%%
WriteCalFile = 1;  %0 = do not write cal file, 1 = write cal file
OutAxis3 = 0;      %0 = no gantry slave, 1 = gantry slave axis
OutAx3Value = 0;   %if OutAxis3 = 1, sets the master axis of the gantry.
                   %sign is negative if the endcoder directions are
                   %opposite between the master and slave axes
CalFile = 'Matlab-Old.cal';
UserUnit = 'METRIC';  % user units = 'METRIC' or 'ENGLISH'
                      % correction units are "user units"/1000

writeOutputFile = 1;
OutFile = 'MATLAB_Old.dat';

%%%%%%%%%%%%%%%% Set Calibration Zone Parameters %%%%%%%%%%%%%%%%%%%%
numRow = 2;                 % number of calibration zone rows (how many zones in Axis 2 (Step axis) direction)
numCol = 2;                 % number of calibration zone columns (how many zones in Axis 1 (Scan axis) direction)
travelAx1 = ([-250 250]);      % full calibrated travel for Axis 1 (scan axis)
travelAx2 = ([-250 250]);      % full calibrated travel for Axis 2 (step axis)

%%%%%%%%%%%%%%%% GRAPH SUB-TITLE (CALIBRATION STATUS) %%%%%%%%%%%%%%%
sTitle = {'Uncalibrated'};

zscaling = 2;  % rounding increment for z scale in charts

   % set data file names for various zones
counter = 0;
for i = 1:numRow
    for j = 1:numCol
        counter = counter + 1;
        fName(i,j) = {sprintf('642583-1-1-CZ%u.dat', counter)};
    end
end

%%%%%%%%%%%%%%%% Data Postprocessing %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% The raw data for each zone is opened and processed individually for 2D
% accuracy and orthogonality with A3200Acc2DMultiZone_test.m.  A structure
% "data" is created which contains the position matrices, error matrices,
% axis names and numbers, stage serial number, and other system information.
%
% Data from the first zone is used as a reference for all subsequent zones.
% The mean slope and mean offset of the overlapping regions are used to
% match up the data. The stitching routing marches across the zones in the
% scan direction until the last zone of scan travel is reached.  Then the
% next row is processed, using the first zone of the previous row as a
% reference for slope and offset.
%
% For stitching, "master" and "slave" zones are defined.  After the
% overlapping region is determined, the slope of the slave straightness
% data is subtracted from the slave straightness.  Then, the slope and offset of the
% master straightness are added to the slave straightness data.  These
% corrections are made on both the scan and step axes straightess errors so
% that the orthogonality error between the axes is not distored

y_meas_dir = -1;   % slope due to mirror misalignment is always opposite sign
                   % between the axes when the laser and encoder read positive
                   % in the same direction

zoneCount = 0;
for i = 1:numRow
    for j = 1:numCol
        if (i == 1) && (j == 1)     % open data for the first zone
            data = A3200Acc2DMultiZone_test(char(fName(i,j)));
            zoneCount = zoneCount + 1;

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

            % determine the step size used to generate each calibration grid
            incAx1 = Ax1Master(1,2) - Ax1Master(1,1);
            incAx2 = Ax2Master(2,1) - Ax2Master(1,1);

            % initialize full travel matrices X, Y, Ax1Err, and Ax2Err
              % in this step, just generate empty (zero) vectors with the
              % correct size
            X = zeros(round((travelAx2(2)-travelAx2(1))/incAx2 + 1), ...
                round((travelAx1(2)-travelAx1(1))/incAx1 + 1));  %Axis1 Position
            Y = X;         %Axis 2 Position
            Ax1Err = X;    %Axis 1 Error with respect to X and Y
            Ax2Err = X;    %Axis 2 Error with respect to X and Y
            avgCount = X;  % 2d matrix to keep track of how many averages
                             %occur in the overlap regions

            Ax1size = size(Ax1Master);
            Ax2size = size(Ax2Master);
            arrayIndexAx1 = 1;  % offset index in Axis 1 direction for this zone
            arrayIndexAx2 = 1;  % offset index in Axis 2 direction for this zone
            rangeAx1 = arrayIndexAx1-1+(1:Ax1size(2));  % Ax1 range of full travel vectors that correspond to this zone
            rangeAx2 = arrayIndexAx2-1+(1:Ax2size(1));  % Ax2 range of full travel vectors that correspond to this zone

            % add this zone's positions and errors to the full travel
             % vectors.  update the average count variable so the average
             % can be taken later
            X(rangeAx2, rangeAx1) = X(rangeAx2, rangeAx1) + Ax1Master;
            Y(rangeAx2, rangeAx1) = Y(rangeAx2, rangeAx1) + Ax2Master;
            Ax1Err(rangeAx2, rangeAx1) = Ax1Err(rangeAx2, rangeAx1) + Ax1MasErr;
            Ax2Err(rangeAx2, rangeAx1) = Ax2Err(rangeAx2, rangeAx1) + Ax2MasErr;
            avgCount(rangeAx2, rangeAx1) = avgCount(rangeAx2, rangeAx1) + ones(size(Ax1Master));
            %%%%%% section end for processing the first zone
        else
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

            %clear the previous slave values
            clear Ax1Slave;
            clear Ax2Slave;
            clear Ax1SlaveErr
            clear Ax2SlaveErr
        end

        % if there is more than one column in the grid, march across the
        % columns, stitching the zones together
        if j ~= numCol

        % read the data for the next column zone and write into slave variables
        clear data    % clear the previous data structure
        data = A3200Acc2DMultiZone_test(char(fName(i,j+1)));
        zoneCount = zoneCount + 1;
        Ax1Slave = data.X;   % write Axis 1 position values to variable
        Ax2Slave = data.Y;   % write Axis 2 position values to variable
        Ax1SlaveErr = data.Ax1Err;  % write Axis 2 error values to variable
        Ax2SlaveErr = data.Ax2Err;  % write Axis 2 error values to variable
        overlapAx1 = max(max(Ax1Master))-min(min(Ax1Slave));  % determine overlap distance
        Ax1size = size(Ax1Master);
        airTemp(zoneCount) = str2double(data.airTemp);
        matTemp(zoneCount) = str2double(data.matTemp);
        comment(zoneCount) = {data.comment};
        fileDate{zoneCount} = {data.fileDate};

        % find number of matrix indeces in the overlap region
        k = 1;
        while Ax1Slave(1,k) < max(max(Ax1Master))
            k = k+1;
        end

        % set the index values of the master and slave overlap ranges
        mRange = ((Ax1size(2)-k+1): Ax1size(2));
        sRange = (1:k);

        % calculate the mean error curves in for ax1, ax2 in both the master and
         % slave overlap regions.  These are vectors, not scalars.
        Ax1MasErrMean = mean(Ax1MasErr(:,mRange),2);
        Ax2MasErrMean = mean(Ax2MasErr(:,mRange));
        Ax1SlaveErrMean = mean(Ax1SlaveErr(:,sRange),2);
        Ax2SlaveErrMean = mean(Ax2SlaveErr(:,sRange));

        % get best line fit coefficients for the mean straightness error for
         % both the master and slave zones.  Straightness error of the scan
         % axis is used.
         %straightness of the first axis (scan axis)
        mcoef2 = polyfit(Ax1Master(1,mRange), Ax2MasErrMean, 1);
        scoef2 = polyfit(Ax1Slave(1,sRange), Ax2SlaveErrMean,1);

        mcoef = polyfit(Ax2Master(:,1), Ax1MasErrMean, 1);
        scoef = polyfit(Ax2Slave(:,1), Ax1SlaveErrMean,1);


        % subtract the straightess slope of the slave from the slave and
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


        % subtract the accuracy scalar mean of the slave data from the slave and
         % then add the accuracy scalar mean of the master to the slave.
        Ax2SlaveErr = Ax2SlaveErr - mean(mean(Ax2SlaveErr(:,sRange))) + mean(mean(Ax2MasErr(:,mRange)));
        Ax1SlaveErr = Ax1SlaveErr - mean(mean(Ax1SlaveErr(:,sRange))) + mean(mean(Ax1MasErr(:,mRange)));

        % add this zone's positions and errors to the full travel
         % vectors.  update the average count variable so the average
         % can be taken later
        Ax1size = size(Ax1Slave);
        Ax2size = size(Ax2Slave);
        arrayIndexAx1 = round((Ax1Slave(1,1)-X(1,1))/incAx1 + 1);
        arrayIndexAx2 = round((Ax2Slave(1,1)-Y(1,1))/incAx2 + 1);
        rangeAx1 = (arrayIndexAx1-1+(1:Ax1size(2)));
        rangeAx2 = arrayIndexAx2-1+(1:Ax2size(1));
        X(rangeAx2, rangeAx1) = X(rangeAx2, rangeAx1) + Ax1Slave;
        Y(rangeAx2, rangeAx1) = Y(rangeAx2, rangeAx1) + Ax2Slave;
        Ax1Err(rangeAx2, rangeAx1) = Ax1Err(rangeAx2, rangeAx1) + Ax1SlaveErr;
        Ax2Err(rangeAx2, rangeAx1) = Ax2Err(rangeAx2, rangeAx1) + Ax2SlaveErr;
        avgCount(rangeAx2, rangeAx1) = avgCount(rangeAx2, rangeAx1) + ones(size(Ax1Slave));

        % temporary plots for troubleshooting
         % these overlay the individual zone plots so that goodness of fit can be
         % observed.

         % re-calculate the mean error curves in for ax1, ax2 in both the master and
         % slave overlap regions.  These are vectors, not scalars.  This is
         % for verification that correct slope was removed
        Ax1MasErrMean2 = mean(Ax1MasErr(:,mRange),2);
        Ax2MasErrMean2 = mean(Ax2MasErr(:,mRange));
        Ax1SlaveErrMean2 = mean(Ax1SlaveErr(:,sRange),2);
        Ax2SlaveErrMean2 = mean(Ax2SlaveErr(:,sRange));

        % overlap troubleshooting plots
          figure(100)
            subplot(121)
              sh = surf(Ax1Master, Ax2Master,Ax1MasErr);
              title('Figure 100, Axis1 Error Individual Zone Plots')
              hold on
              plot3(Ax1Master(:,mRange), Ax2Master(:,mRange),Ax1MasErr(:,mRange),'ok')
              xlabel('Ax1')
              ylabel('Ax2')
              % alpha(.5)
              set(sh,'edgecolor','b')
%               view([0 0 1])
            subplot(122)
              plot(Ax1MasErrMean2, Ax2Master(:,1), 'b')
              ttl(1) = {'Axis2 Avg Straightness Err in Overlap Zone'};
              ttl(2) = {'Black dots indicate overlap region'};
              title(ttl)
              hold on
              ylabel('Ax2 Position')
              xlabel('Straightness (Error in Ax1 Dir)')

          figure(200)
            subplot(121)
              sh = surf(Ax1Master, Ax2Master,Ax2MasErr);
              title('Figure 200, Axis2 Error Individual Zone Plots')
              hold on
              plot3(Ax1Master(:,mRange), Ax2Master(:,mRange),Ax2MasErr(:,mRange),'ok')
              xlabel('Ax1')
              ylabel('Ax2')
              % alpha(.5)
              set(sh,'edgecolor','b')
%               view([0 0 1])
            subplot(122)
              plot(Ax1Master(1,:), mean(Ax2MasErr), 'b')
              hold on
              ttl(1) = {'Axis1 Avg Overall Straightness Err'};
              ttl(2) = {'Black dots indicate overlap region'};
              title(ttl)
              hold on
              xlabel('Ax1 Position')
              ylabel('Straightness (Error in Ax2 Dir)')

          figure(100)
            subplot(121)
              sh= surf(Ax1Slave, Ax2Slave, Ax1SlaveErr);
              % alpha(.5)
              set(sh,'edgecolor','r')
            subplot(122)
              plot(Ax1SlaveErrMean2, Ax2Slave(:,1), 'r')
              plot(Ax1MasErrMean2, Ax2Master(:,1), 'ok')
              plot(Ax1SlaveErrMean2, Ax2Slave(:,1), 'ok')
%               legend('Master Zone', 'Slave Zone','location','eastoutside')
              set(100,'position',[ 75        75        1142         473])
              orient landscape
              if (i == 1) && (j == 1)
                  d = daspect;
                  [D,I] = max(d);
                  d(I) = D/2;
                  daspect(d)
              end
            subplot(121)  %activate surface plot

          figure(200)
            subplot(121)
              sh=surf(Ax1Slave, Ax2Slave, Ax2SlaveErr);
              % alpha(.5)
              set(sh,'edgecolor','r')
            subplot(122)
              plot(Ax1Slave(1,:), mean(Ax2SlaveErr), 'r')
              plot(Ax1Master(1,mRange), Ax2MasErrMean2, 'ok')
              plot(Ax1Slave(1,sRange), Ax2SlaveErrMean2, 'ok')
%               legend('Master Zone', 'Slave Zone','location','southoutside')
              set(200,'position',[ 150        150        1142         473])
              orient landscape
              if (i == 1) && (j == 1)
                  d = daspect;
                  [D,I] = max(d);
                  d(I) = D/2;
                  daspect(d)
              end
            subplot(121) %activate surface plot

        % clear temporary variables for next loop
        clear Ax1MasErrMean
        clear Ax2MasErrMean
        clear Ax1SlaveErrMean
        clear Ax2SlaveErrMean
        end
    end  % end of column loop

    % now that all columns have been processed, jump to first column of
    % next row.
    if i ~= numRow
    clear data  % clear the previous data file from memory
    data = A3200Acc2DMultiZone_test(char(fName(i+1,1)));
    zoneCount = zoneCount + 1;
    Ax1Slave = data.X;  % store axis 1 position
    Ax2Slave = data.Y;  % store axis 2 position
    Ax1SlaveErr = data.Ax1Err;  % store axis 1 error
    Ax2SlaveErr = data.Ax2Err;  % store axis 2 error
    airTemp(zoneCount) = str2double(data.airTemp);
    matTemp(zoneCount) = str2double(data.matTemp);
    comment(zoneCount) = {data.comment};
    fileDate(zoneCount) = {data.fileDate};

    % find overlap between this slave zone and the row master zone
    overlapAx2 = max(max(rowAx2Master))-min(min(Ax2Slave));
    Ax2size = size(rowAx2Master);

    % find number of matrix indeces in the overlap region.  The
    % straightness of the scan axis is still used for slope adjustments, so
    % the overlap regions for the rows are perpendicular to the overlap regions for the
    % columns.  This slave zone is compared to the row master zone
    k = 1;
    while Ax2Slave(k,1) < max(max(rowAx2Master))
        k = k+1;
    end

    % set the index values of the master and slave overlap ranges
    mRange = ((Ax2size(1)-k+1): Ax2size(1));
    sRange = (1:k);

    % calculate the mean error curves in for ax1, ax2 in both the master and
     % slave overlap regions.  These are vectors, not scalars.
    Ax1MasErrMean = mean(rowAx1MasErr(mRange,:),2);  %%% *************************
    Ax2MasErrMean = mean(rowAx2MasErr(mRange,:));
    Ax1SlaveErrMean = mean(Ax1SlaveErr(sRange,:),2); %%% *************************
    Ax2SlaveErrMean = mean(Ax2SlaveErr(sRange,:));

    % get best line fit coefficients for the mean straightness error for
     % both the master and slave zones.  Straightness error of the scan
     % axis is used.
    mcoef = polyfit(rowAx1Master(1,:), Ax2MasErrMean, 1);
    scoef = polyfit(Ax1Slave(1,:), Ax2SlaveErrMean,1);

    % subtract the straightess slope of the slave from the slave and
     % then add the straightness slope of the master to the slave.  Do
     % this in both Ax1 and Ax2 straightnesses so that the orhtogonality
     % measurement is not distorted.
    for n = 1:Ax2size(1)
        Ax2SlaveErr(n,:) = Ax2SlaveErr(n,:)-polyval(scoef, Ax1Slave(1,:)) + polyval(mcoef, Ax1Slave(1,:));
    end
    for n = 1:Ax2size(2)
        Ax1SlaveErr(:,n) = Ax1SlaveErr(:,n)-polyval(y_meas_dir * scoef, Ax2Slave(:,1)) + polyval(y_meas_dir * mcoef,Ax2Slave(:,1));
    end

    % subtract the straightess scalar mean of the slave data from the slave and
     % then add the straightess scalar mean of the master to the slave.
    Ax2SlaveErr = Ax2SlaveErr - mean(mean(Ax2SlaveErr(sRange,:))) + mean(mean(rowAx2MasErr(mRange,:)));
    Ax1SlaveErr = Ax1SlaveErr - mean(mean(Ax1SlaveErr(sRange,:))) + mean(mean(rowAx1MasErr(mRange,:)));

    % add this zone's positions and errors to the full travel
     % vectors.  update the average count variable so the average
     % can be taken later
    Ax1size = size(Ax1Slave);
    Ax2size = size(Ax2Slave);
    arrayIndexAx1 = round((Ax1Slave(1,1)-X(1,1))/incAx1 + 1);
    arrayIndexAx2 = round((Ax2Slave(1,1)-Y(1,1))/incAx2 + 1);
    rangeAx1 = arrayIndexAx1-1+(1:Ax1size(2));
    rangeAx2 = arrayIndexAx2-1+(1:Ax2size(1));
    X(rangeAx2, rangeAx1) = X(rangeAx2, rangeAx1) + Ax1Slave;
    Y(rangeAx2, rangeAx1) = Y(rangeAx2, rangeAx1) + Ax2Slave;
    Ax1Err(rangeAx2, rangeAx1) = Ax1Err(rangeAx2, rangeAx1) + Ax1SlaveErr;
    Ax2Err(rangeAx2, rangeAx1) = Ax2Err(rangeAx2, rangeAx1) + Ax2SlaveErr;
    avgCount(rangeAx2, rangeAx1) = avgCount(rangeAx2, rangeAx1) + ones(size(Ax1Slave));

     % re-calculate the mean error curves in for ax1, ax2 in both the master and
     % slave overlap regions.  These are vectors, not scalars.  This is
     % for verification that correct slope was removed
    Ax1MasErrMean2 = mean(rowAx1MasErr(mRange,:),2);  %%% *****************
    Ax2MasErrMean2 = mean(rowAx2MasErr(mRange,:));
    Ax1SlaveErrMean2 = mean(Ax1SlaveErr(sRange,:),2); %%% *****************
    Ax2SlaveErrMean2 = mean(Ax2SlaveErr(sRange,:));

    figure(300)
      subplot(121)
        sh = surf(rowAx1Master, rowAx2Master,rowAx1MasErr);
        title('Figure 300, Axis1 Error Individual Zone Plots')
        hold on
        xlabel('Ax1')
        ylabel('Ax2')
        % alpha(.5)
        set(sh,'edgecolor','b')
%         view([0 0 1])
      subplot(122)
        plot(mean(rowAx1MasErr,2), rowAx2Master(:,1));
        hold on
        plot(Ax1MasErrMean2, rowAx2Master(mRange,1),'ok')
        ttl(1) = {'Axis2 Avg Overall Straightness Err'};
        title(ttl)
        hold on
        ylabel('Ax2 Position')
        xlabel('Straightness (Error in Ax1 Dir)')

      subplot(121)
        sh = surf(Ax1Slave, Ax2Slave,Ax1SlaveErr);
        % alpha(.5)
        set(sh,'edgecolor','r')
        plot3(rowAx1Master(mRange,:), rowAx2Master(mRange,:),rowAx1MasErr(mRange,:),'ok')
      subplot(122)
        plot(mean(Ax1SlaveErr,2), Ax2Slave(:,1),'r')
        plot(Ax1SlaveErrMean2, Ax2Slave(sRange,1),'ok')
      set(300,'position',[ 200       200        1142         473])
      orient landscape
      if (i == 1)
          d = daspect;
          [D,I] = max(d);
          d(I) = D/2;
          daspect(d)
      end
      subplot(121)  % activate surface plot
      pause

    figure(400)
      subplot(121)
        sh = surf(rowAx1Master, rowAx2Master,rowAx2MasErr);
        title('Figure 400, Axis2 Error Individual Zone Plots')
        hold on
        xlabel('Ax1')
        ylabel('Ax2')
        % alpha(.5)
        set(sh,'edgecolor','b')
%         view([0 0 1])
      subplot(122)
        plot(rowAx1Master(1,:), Ax2MasErrMean2,'b')
        ttl(1) = {'Axis1 Avg Straightness Err in Overlap Zone'};
        title(ttl)
        hold on
        xlabel('Ax1 Position')
        ylabel('Straightness (Error in Ax2 Dir)')
        plot(rowAx1Master(1,:), Ax2MasErrMean2,'ok')

      subplot(121)
        sh = surf(Ax1Slave, Ax2Slave,Ax2SlaveErr);
        % alpha(.5)
        set(sh,'edgecolor','r')
        plot3(rowAx1Master(mRange,:), rowAx2Master(mRange,:),rowAx2MasErr(mRange,:),'ok')
      subplot(122)
        plot(Ax1Slave(1,:), Ax2SlaveErrMean2,'r')
        plot(Ax1Slave(1,:), Ax2SlaveErrMean2,'ok')
        if i == 1
            d = daspect;
            [D,I] = max(d);
            d(I) = D/2;
            daspect(d)
        end
      subplot(121) % activate surface plot
    set(400,'position',[ 300       300        1142         473])
    orient landscape

    pause

    clear rowAx1Master
    clear rowAx2Master
    clear rowAx1MasErr
    clear rowAx2MasErr

    rowAx1Master = Ax1Slave;
    rowAx2Master = Ax2Slave;
    rowAx1MasErr = Ax1SlaveErr;
    rowAx2MasErr = Ax2SlaveErr;

    end
end  % end of row loop


% divide through by the avgCount to complete the average in the overlap
% regions
totalSize = size(X);
for i = 1:totalSize(1)
    for j = 1:totalSize(2)
        X(i,j) = X(i,j)/avgCount(i,j);
        Y(i,j) = Y(i,j)/avgCount(i,j);
        Ax1Err(i,j) = Ax1Err(i,j)/avgCount(i,j);
        Ax2Err(i,j) = Ax2Err(i,j)/avgCount(i,j);
    end
end

NumAx1Points = totalSize(2);
NumAx2Points = totalSize(1);

%%%%%%%%%%%%%%%% Data Plotting %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% REMOVE BEST FIT SLOPE AND CALCULATE ORTHOGONALITY ******************

% line fit the straightness error data with respect to the stage position
Ax1Coef = polyfit(Y(:,1), mean(Ax1Err,2),1);   % slope units microns/mm
Ax2Coef = polyfit(X(1,:),mean(Ax2Err),1);   % slope units microns/mm

% create best fit line for X data, use X line for Y data (to calibrate in orthogonality)
Ax1Line = polyval(Ax1Coef, Y(:,1));
Ax2Line = polyval(y_meas_dir * Ax1Coef, X(1,:));

% create straightness data for orthogonality plots (remove best fit lines)
Ax1Orthog = mean(Ax1Err,2) - Ax1Line;
Ax2Orthog = mean(Ax2Err) - polyval(Ax2Coef, X(1,:));

% subrtract the line fits from the Ax1 and Ax2 error data (remove mirror slope)
for i = 1:totalSize(2)
    Ax1Err(:,i) = Ax1Err(:,i) - Ax1Line;
end
for i = 1:totalSize(1)
    Ax2Err(i,:) = Ax2Err(i,:) - Ax2Line;
end

% calculate orthogonality

orthog = Ax1Coef(1) - y_meas_dir * Ax2Coef(1);
orthog = atan(orthog/1000) * 180/pi * 3600;  % arc sec

% CALCULATE THE VECTOR SUM ACCURACY ERROR ******************************************

% subtract error at origin of xy grid prior to vector sum calculation
Ax1Err = Ax1Err - Ax1Err(1,1);
Ax2Err = Ax2Err - Ax2Err(1,1);

% calculate the total vector sum accuracy error
VectorErr = sqrt(Ax1Err.^2 + Ax2Err.^2);

% calculate peak to peak values
pkAx1 = max(max(Ax1Err))-min(min(Ax1Err));
pkAx2 = max(max(Ax2Err))-min(min(Ax2Err));

% SECTION 7. PLOT THE RESULTS ************************************************************************
% set visibility of overlap graphs so that they can't be closed
set(100,'Handlevisibility','off')
set(200,'Handlevisibility','off')
%set(300,'Handlevisibility','off')
%set(400,'Handlevisibility','off')

close all;

% set visibility of overlap graphs so that they can be closed
set(100,'Handlevisibility','on')
set(200,'Handlevisibility','on')
%set(300,'Handlevisibility','on')
%set(400,'Handlevisibility','on')

% plot the results
  %SUMMARY PLOT
clear ttl
g=figure;
figName = 'Results Summary';
set(g,'Position',[270 160 730 555],'PaperPositionMode','manual','Name',figName)

% axis 1 direction error
subplot(221)
% calculate offset such that the max and min are symmetric about zero
offset = mean([max(max(Ax1Err)) min(min(Ax1Err))]);
amplitude = max(max(Ax1Err- offset));
Ax1amplitude = amplitude;
surf(X,Y,Ax1Err- offset)
shading interp
ttl(1) = {sprintf('%s Direction Error', Ax1Name)};
title(ttl)
labx = sprintf('%s (%s)', Ax1Name, posUnit);
laby = sprintf('%s (%s)', Ax2Name, posUnit);
xlabel(labx)
ylabel(laby)
txt = sprintf('(%s)', errUnit);
zlabel(txt)
view([-1 -1 .5])
set(gca,'PlotBoxAspectRatio', [1 1 .5])
axlim = axis;
% set x and y plot limits to be 20% larger than the data set.  Set the tick
% marks to match the data set.
Ax1MoveDist = X(1,end)-X(1,1);
Ax2MoveDist = Y(end,1)-Y(1,1);
xlimits=([(min(min(X))-0.1*Ax1MoveDist) (max(max(X))+0.1*Ax1MoveDist)]);
xticks = (min(min(X)):(Ax1MoveDist/5):max(max(X)));
ylimits=([(min(min(Y))-0.1*Ax2MoveDist) (max(max(Y))+0.1*Ax2MoveDist)]);
yticks = (min(min(Y)):(Ax2MoveDist/5):max(max(Y)));
% round z limits up to the nearest micron;
maxz = max(abs(axlim(5:6)));
zscaling = 1;  % rounding increment for z scale
maxz = ceil(maxz/zscaling)*zscaling;
axlim(5:6) = ([-maxz maxz]);
ax = gca;
set(ax, 'XLim', (xlimits), 'YLim', (ylimits),'ZLim',(axlim(5:6)),'XTick',xticks,'YTick',yticks);

% axis 2 direction error
subplot(222)
% calculate offset such that the max and min are symmetric about zero
offset = mean([max(max(Ax2Err)) min(min(Ax2Err))]);
amplitude = max(max(Ax2Err- offset));
Ax2amplitude = amplitude;
surf(X,Y,Ax2Err- offset)
shading interp
ttl(1) = {sprintf('%s Direction Error', Ax2Name)};
title(ttl)
labx = sprintf('%s (%s)', Ax1Name, posUnit);
laby = sprintf('%s (%s)', Ax2Name, posUnit);
xlabel(labx)
ylabel(laby)
txt = sprintf('(%s)', errUnit);
zlabel(txt)
view([-1 -1 .5])
set(gca,'PlotBoxAspectRatio', [1 1 .5])
axlim = axis;
maxz = max(abs(axlim(5:6)));
% round z limits up to the nearest micron;
maxz = ceil(maxz/zscaling)*zscaling;
axlim(5:6) = ([-maxz maxz]);
ax = gca;
set(ax, 'XLim', (xlimits), 'YLim', (ylimits),'ZLim',(axlim(5:6)),'XTick',xticks,'YTick',yticks);

% vector sum
subplot(223)
amplitude = max(max(VectorErr));
surf(X,Y,VectorErr)
shading interp
ttl(1) = {sprintf('%s-%s Vector Sum', Ax1Name, Ax2Name)};
title(ttl)
xlabel(labx)
ylabel(laby)
txt = sprintf('(%s)', errUnit);
zlabel(txt)
clear txt
view([-1 -1 .5])
set(gca,'PlotBoxAspectRatio', [1 1 .5])
axlim = axis;
% round z limits up to the nearest micron;
maxz = max(abs(axlim(5:6)));
maxz = ceil(maxz/zscaling)*zscaling;
axlim(5:6) = ([0 maxz]);
ax = gca;
set(ax, 'XLim', (xlimits), 'YLim', (ylimits),'ZLim',(axlim(5:6)),'XTick',xticks,'YTick',yticks);

% exaggerated orthogonality plot
%   exaggeration level is determined so that the plotted slope of the X-axis leg is no more
%   than half of the length of the y-axis leg.
subplot(224)
% first, see how bad the slope is
tempAx1Err = mean(Ax1Err,2);
tempAx2Err = mean(Ax2Err);
% determine exaggeration level
tempCoef = polyfit(X(1,:), tempAx2Err,1);
legLength = abs(tempCoef(1)*Ax1MoveDist);
legRatio = 0.5*Ax2MoveDist/legLength;  % ratio of (y travel)/2 to slope displacement
if legRatio > 1 && legRatio < 10
    % set exaggeration so that Y displacement of X line is about 1/2 of Y travel
    exaggeration = round(legRatio/0.5)*0.5;
elseif legRatio < 1
    % for very bad errors, don't exaggerate the error
    exaggeration = 1;
else
    % for very good errors, max out the exageration at 10 so that the plot looks like a right angle
    exaggeration = 10;
end
% create exaggerated error vectors
tempAx1Err = (tempAx1Err-tempAx1Err(1))*exaggeration;
tempAx2Err = (tempAx2Err-tempAx2Err(1))*exaggeration;
% line fit the exaggerated data
tempCoef1 = polyfit(Y(:,1), tempAx1Err,1);
tempCoef2 = polyfit(X(1,:), tempAx2Err,1);
tempFit1 = polyval(tempCoef1, Y(:,1));
tempFit2 = polyval(tempCoef2, X(1,:));
% subtract offsets so the plot is always a right angle in the NE quadrant
offset1 = tempFit1(1);
offset2 = tempFit2(1);
tempAx1Err = tempAx1Err - offset1;
tempAx2Err = tempAx2Err - offset2;
tempFit1 = tempFit1 - offset1;
tempFit2 = tempFit2 - offset2;
% create plot
plot(tempAx1Err, Y(:,1)-Y(1,1), '.','color',[0.5 0.5 0.5])
hold on
plot(tempFit1, Y(:,1)-Y(1,1),'r','linewidth',2)
plot(X(1,:)-X(1,1),tempAx2Err, '.','color',[0.5 0.5 0.5])
plot(X(1,:)-X(1,1),tempFit2, 'b','linewidth',2)
grid on;
title(sprintf('Orthogonality (Exaggerated %1.0fx)', exaggeration*1000))
% units are specifically not plotted in graph labels due to the combination of position (mm)
% and exaggerated error (microns * exaggeration)
xlabel(sprintf('%s Direction', Ax1Name))
ylabel(sprintf('%s Direction', Ax2Name))
% set axis limits to be 20% larger than the data set so that the right
% angle can be visualized
alim = axis;
tmp = alim(2)-alim(1);
tmpXTick = get(gca,'XTick');
tmpXLim = [(alim(1)-tmp*0.1) (alim(2)+tmp*0.1)];
set(gca,'XLim',tmpXLim,'XTick',tmpXTick)
tmp = alim(4)-alim(3);
tmpYLim = [(alim(3)-tmp*0.1) (alim(4)+tmp*0.1)];
tmpYTick = get(gca,'YTick');
set(gca,'YLim',tmpYLim,'YTick',tmpYTick)
clear tmp tmpXLim tmpXTick tmpYLim tmpYTick alim
axis square

orient landscape

%create footer in Figure 1



% % plot the results
%   %SUMMARY PLOT
% clear ttl
% g=figure;
% figName = 'Results Summary';
% set(g,'Position',[270 160 730 555],'PaperPositionMode','manual','Name',figName)
% subplot(221)
% offset = mean([max(max(Ax1Err)) min(min(Ax1Err))]);
% amplitude = max(max(Ax1Err- offset));
% surf(X,Y,Ax1Err- offset)
% shading interp
% ttl(1) = {sprintf('%s Error: {\\pm}%1.2f%s', Ax1Name, amplitude, errUnit)};
% title(ttl)
% labx = sprintf('%s (%s)', Ax1Name, posUnit);
% laby = sprintf('%s (%s)', Ax2Name, posUnit);
% xlabel(labx)
% ylabel(laby)
% txt = sprintf('(%s)', errUnit);
% zlabel(txt)
% view([-1 -1 .5])
% set(gca,'PlotBoxAspectRatio', [1 1 .5])
% axlim = axis;
% maxz = max(abs(axlim(5:6)));
%
% maxz = ceil(maxz/zscaling)*zscaling;
% axlim(5:6) = ([-maxz maxz]);
% ax = gca;
% set(ax, 'XLim', [(travelAx1(1)-incAx1) (travelAx1(2)+incAx1)], 'YLim',[(travelAx2(1)-incAx2) (travelAx2(2)+incAx2)],'ZLim',(axlim(5:6)));
% set(ax, 'XTick', (travelAx1(1):(travelAx1(2)-travelAx1(1))/5:travelAx1(2)), 'YTick',(travelAx2(1):(travelAx2(2)-travelAx2(1))/5:travelAx2(2)),'ZLim',(axlim(5:6)));
% axlim = axis;
%
% subplot(222)
% offset = mean([max(max(Ax2Err)) min(min(Ax2Err))]);
% amplitude = max(max(Ax2Err- offset));
% surf(X,Y,Ax2Err- offset)
% shading interp
% ttl(1) = {sprintf('%s Error: {\\pm}%1.2f%s', Ax2Name, amplitude, errUnit)};
% title(ttl)
% labx = sprintf('%s (%s)', Ax1Name, posUnit);
% laby = sprintf('%s (%s)', Ax2Name, posUnit);
% xlabel(labx)
% ylabel(laby)
% txt = sprintf('(%s)', errUnit);
% zlabel(txt)
% view([-1 -1 .5])
% set(gca,'PlotBoxAspectRatio', [1 1 .5])
% temp = axis;
% axis(axlim);
% maxz = max(abs(temp(5:6)));
% % zscaling = 1;  % rounding increment for z scale
% maxz = ceil(maxz/zscaling)*zscaling;
% axlim(5:6) = ([-maxz maxz]);
% ax = gca;
% set(ax, 'XLim', (axlim(1:2)), 'YLim', (axlim(3:4)),'ZLim',(axlim(5:6)));
% set(ax, 'XTick', (travelAx1(1):(travelAx1(2)-travelAx1(1))/5:travelAx1(2)), 'YTick',(travelAx2(1):(travelAx2(2)-travelAx2(1))/5:travelAx2(2)),'ZLim',(axlim(5:6)));
%
% subplot(212)
% amplitude = max(max(VectorErr));
% surf(X,Y,VectorErr)
% shading interp
% ttl(1) = {sprintf('%s%s Error: %1.2f%s, Orthogonality: %1.2fsec', Ax1Name, Ax2Name, amplitude, errUnit, orthog)};
% title(ttl)
% xlabel(labx)
% ylabel(laby)
% txt = sprintf('(%s)', errUnit);
% zlabel(txt)
% clear txt
% view([-1 -1 .5])
% set(gca,'PlotBoxAspectRatio', [1 1 .5])
% temp = axis;
% maxz = max(abs(temp(5:6)));
% maxz = ceil(maxz/zscaling)*zscaling;
% axlim(5:6) = ([0 maxz]);
% ax = gca;
% set(ax, 'XLim', (axlim(1:2)), 'YLim', (axlim(3:4)),'ZLim',(axlim(5:6)));
% set(ax, 'XTick', (travelAx1(1):(travelAx1(2)-travelAx1(1))/5:travelAx1(2)), 'YTick',(travelAx2(1):(travelAx2(2)-travelAx2(1))/5:travelAx2(2)),'ZLim',(axlim(5:6)));
% zTextLoc = axlim(5)-(axlim(6)-axlim(5))/2;
% text (axlim(1), axlim(3),  zTextLoc, 'Aerotech Confidential', 'HorizontalAlignment', 'Center',...
%     'Color', 'r', 'FontSize', 10, 'FontWeight', 'bold');
%
% clear ttl
% ttl(1)={sprintf('%s 2D Accuracy Test Summary', SN)};
% ttl(2)=sTitle;
% suptitle(ttl)
% orient landscape
% % clear ttl

% Axis 1 Direction Error
g=figure;
figName = sprintf('%s Direction Error', Ax1Name);
set(g,'Position',[270 160 730 555],'PaperPositionMode','manual','Name',figName)
offset = mean([max(max(Ax1Err)) min(min(Ax1Err))]);
amplitude = max(max(Ax1Err- offset));
surf(X,Y,Ax1Err- offset)
colorbar
shading interp
ttl(3) = sTitle;
ttl(1) = {sprintf('%s Direction 2D Accuracy Error',Ax1Name)};
ttl(2) = {sprintf('Error: {\\pm}%1.1f%s, SN: %s', amplitude, errUnit, SN)};
title(ttl, 'FontWeight','bold')
labx = sprintf('%s Position (%s)', Ax1Name, posUnit);
laby = sprintf('%s Position (%s)', Ax2Name, posUnit);
xlabel(labx)
ylabel(laby)
txt = sprintf('%s Accuracy Error (%s)', Ax1Name, errUnit);
zlabel(txt)
view([-1 -1 .5])
set(gca,'PlotBoxAspectRatio', [1 1 .5])
axlim = axis;
maxz = max(abs(axlim(5:6)));
% zscaling = 1;  % rounding increment for z scale
maxz = ceil(maxz/zscaling)*zscaling;
axlim(5:6) = ([-maxz maxz]);
ax = gca;
set(ax, 'XLim', (axlim(1:2)), 'YLim', (axlim(3:4)),'ZLim',(axlim(5:6)));
zTextLoc = axlim(5)-(axlim(6)-axlim(5))/2;
text (axlim(1), axlim(3),  zTextLoc, 'Aerotech Confidential', 'HorizontalAlignment', 'Center',...
    'Color', 'r', 'FontSize', 10, 'FontWeight', 'bold');
orient landscape

% Axis 2 Direction Error
g=figure;
figName = sprintf('%s Direction Error', Ax2Name);
set(g,'Position',[300 130 730 555],'PaperPositionMode','manual','Name',figName)
offset = mean([max(max(Ax2Err)) min(min(Ax2Err))]);
amplitude = max(max(Ax2Err- offset));
surf(X,Y,Ax2Err-offset)
shading interp
colorbar
ttl(1) = {sprintf('%s Direction 2D Accuracy Error',Ax2Name)};
ttl(2) = {sprintf('Error: {\\pm}%1.1f%s, SN: %s', amplitude, errUnit, SN)};
title(ttl, 'FontWeight','bold')
xlabel(labx)
ylabel(laby)
txt = sprintf('%s Accuracy Error (%s)', Ax2Name, errUnit);
zlabel(txt)
view([-1 -1 .5])
set(gca,'PlotBoxAspectRatio', [1 1 .5])
axlim = axis;
maxz = max(abs(axlim(5:6)));
maxz = ceil(maxz/zscaling)*zscaling;
axlim(5:6) = ([-maxz maxz]);
ax = gca;
set(ax, 'XLim', (axlim(1:2)), 'YLim', (axlim(3:4)),'ZLim',(axlim(5:6)));
zTextLoc = axlim(5)-(axlim(6)-axlim(5))/2;
text (axlim(1), axlim(3),  zTextLoc, 'Aerotech Confidential', 'HorizontalAlignment', 'Center',...
    'Color', 'r', 'FontSize', 10, 'FontWeight', 'bold');
orient landscape

% Vector Sum Error
g=figure;
figName = sprintf('%s%s Vector Error', Ax1Name,Ax2Name);
set(g,'Position',[330 100 730 555],'PaperPositionMode','manual','Name',figName)
amplitude = max(max(VectorErr));
surf(X,Y,VectorErr)
shading interp
colorbar
ttl(1) = {sprintf('%s%s Vector Sum 2D Accuracy Error', Ax1Name, Ax2Name)};
ttl(2) = {sprintf('Error: %1.1f%s, SN: %s', amplitude, errUnit, SN)};
title(ttl, 'FontWeight','bold')
xlabel(labx)
ylabel(laby)
txt = sprintf('Accuracy Error (%s)', errUnit);
zlabel(txt)
clear txt
view([-1 -1 .5])
set(gca,'PlotBoxAspectRatio', [1 1 .5])
axlim = axis;
maxz = max(abs(axlim(5:6)));
maxz = ceil(maxz/zscaling)*zscaling;
axlim(5:6) = ([0 maxz]);
ax = gca;
set(ax, 'XLim', (axlim(1:2)), 'YLim', (axlim(3:4)),'ZLim',(axlim(5:6)));
zTextLoc = axlim(5)-(axlim(6)-axlim(5))/2;
text (axlim(1), axlim(3),  zTextLoc, 'Aerotech Confidential', 'HorizontalAlignment', 'Center',...
    'Color', 'r', 'FontSize', 10, 'FontWeight', 'bold');
orient landscape

% Orthogonality Error
g=figure;
figName = sprintf('Orthogonality Error');
set(g,'Position',[360 70 730 555],'PaperPositionMode','manual','Name',figName)
subplot(211)
plot(X(1,:), Ax2Orthog,'.-')
ax1 = gca;
axlim = axis;
axlim(4) = max(abs(axlim(3:4)));
axlim(4) = ceil(axlim(4)/.5)*0.5;
axlim(3) = -axlim(4);
ylim(axlim(3:4))
grid on
ttl(1) = {sprintf('%s%s Orthogonality, SN: %s', Ax1Name, Ax2Name, SN)};
ttl(2) = {sprintf('Orthogonality = %1.1f sec', orthog)};
title(ttl, 'FontWeight','bold')
labx = sprintf('%s Position (%s)', Ax1Name, posUnit);
xlabel(labx)
laby = sprintf('%s Avg Straightness ( %s)', Ax1Name, errUnit);
ylabel(laby)
txt(1) = {sprintf('Raw Slope: %1.3f %s/%s', Ax2Coef(1), errUnit, posUnit)};
text(mean(axlim(1:2)), axlim(3)*0.9, txt, 'HorizontalAlignment','center');
subplot(212)
plot(Y(:,1), Ax1Orthog,'.-')
labx = sprintf('%s Position (%s)', Ax2Name, posUnit);
xlabel(labx)
laby = sprintf('%s Avg Straightness ( %s)', Ax2Name, errUnit);
ylabel(laby);
grid on
axlim = axis;
axlim(4) = max(abs(axlim(3:4)));
axlim(4) = ceil(axlim(4)/.5)*0.5;
axlim(3) = -axlim(4);
ylim(axlim(3:4))
txt(1) = {sprintf('Raw Slope: %1.3f %s/%s', y_meas_dir * Ax1Coef(1), errUnit, posUnit)};
text(mean(axlim(1:2)), axlim(3)*0.9, txt, 'HorizontalAlignment','center');
yTextLoc = axlim(3)-(axlim(4)-axlim(3))/4;
text(mean(axlim(1:2)), yTextLoc, 'Aerotech Confidential', 'HorizontalAlignment', 'Center',...
    'Color', 'r', 'FontSize', 10, 'FontWeight', 'bold');
orient landscape

% reorient figures on screen so SUMMARY plot is on top
figure(4)
figure(3)
figure(2)
figure(400)
figure(300)
figure(200)
figure(100)
figure(1)

printFigs = 1;
button = questdlg('Save the Plots to File?','Print to File (*.png)','Yes');
if strcmp(button,'Yes')
    printFigs = 1;
else
    printFigs = 0;
end

if printFigs
    % Set prefix for plot files.  If A3200\Plots directory exists, save the
    % files in that location.  If not, save in the current program
    % directory
    if isdir('C:\A3200\Plots')
        pPrefix = sprintf('C:\\A3200\\Plots\\%s', SN);
    else
        pPrefix = SN;
    end

    p = dir(sprintf('%s-2DSummary-*.png',pPrefix));             %find existing plots
    pFile(1) = {sprintf('%s-2DSummary-%u.png',pPrefix,length(p)+1)}; %create new plot file name
    pList(1) = {sprintf('Summary: %s',char(pFile(1)))};
    pList(2) = {' '};

    p = dir(sprintf('%s-Ax1Err-*.png',pPrefix));             %find existing plots
    pFile(2) = {sprintf('%s-Ax1Err-%u.png',pPrefix,length(p)+1)}; %create new plot file name
    pList(3) = {sprintf('Axis 1 Error: %s',char(pFile(2)))};
    pList(4) = {' '};

    p = dir(sprintf('%s-Ax2Err-*.png',pPrefix));             %find existing plots
    pFile(3) = {sprintf('%s-Ax2Err-%u.png',pPrefix,length(p)+1)}; %create new plot file name
    pList(5) = {sprintf('Axis 2 Error: %s', char(pFile(3)))};
    pList(6) = {' '};

    p = dir(sprintf('%s-VectorErr-*.png',pPrefix));             %find existing plots
    pFile(4) = {sprintf('%s-VectorErr-%u.png',pPrefix,length(p)+1)}; %create new plot file name
    pList(7) = {sprintf('Vector Sum Error: %s', char(pFile(4)))};
    pList(8) = {' '};

    p = dir(sprintf('%s-Orthog-*.png',pPrefix));             %find existing plots
    pFile(5) = {sprintf('%s-Orthog-%u.png',pPrefix,length(p)+1)}; %create new plot file name
    pList(9) = {sprintf('Orthogonality Error: %s', char(pFile(5)))};

    % Axis 1 Error Plot
    clear txt
    txt = 'Plotting Figures to File...';
    h = waitbar(0,txt,'Name','Print Status');
    eval(['print -f1 -r300 -dpng ' char(pFile(1))])                   %print to PNG image
    % Axis 1 Error Plot
    waitbar(.2,h)
    eval(['print -f2 -r300 -dpng ' char(pFile(2))])                   %print to PNG image
    % Axis 2 Error Plot
    waitbar(.4,h)
    eval(['print -f3 -r300 -dpng ' char(pFile(3))])                   %print to PNG image
    % Vector Error Plot
    waitbar(0.6,h)
    eval(['print -f4 -r300 -dpng ' char(pFile(4))])                      %print to PNG image
    % Orthog Plot
    waitbar(0.8,h)
    eval(['print -f5 -r300 -dpng ' char(pFile(5))])                   %print to PNG image
    waitbar(1.0,h)
    close(h)

    % display file names
    pause(0.3)
    h=msgbox(pList,'Plot Job Complete','help');
    uiwait(h);

end

% optional sampling of straightness plots
if 0
    XPlots = find(rem(Y(:,1),175)==0);
    numXPlots = length(XPlots);
    figure
for i = 1:numXPlots
    subplot(numXPlots,1,i)
    plot(X(XPlots(i),:), detrend(Ax2Err(XPlots(i),:)-mean(Ax2Err(XPlots(i),:))),'b.-')
    ylim([-1 1])
%     xlabel(sprintf('%s Position (mm)',char(data.Ax2Name)))
    ylabel('Straightness (um)')
    clear ttl
    ttl = sprintf('%s Axis Straightness (No Brake), %s', char(data.Ax1Name), SN);
    legend(sprintf('Y = %1.1fmm',Y(1,XPlots(i))))
    grid on
    xlim([0 max(X(XPlots(i),:))])
    if i == numXPlots
        xlabel('mm')
    end
    suptitle(ttl)
    orient tall
end

YPlots = find(rem(X(1,:),100)==0);
numYPlots = length(YPlots);
figure
for i = 1:numYPlots
    subplot(numYPlots,1,i)
    plot(Y(:,YPlots(i)), Ax1Err(:,i)-mean(Ax1Err(:,YPlots(i))),'r.-')
    ylim([-1 1])
%     xlabel(sprintf('%s Position (mm)',char(data.Ax1Name)))
    ylabel('um')
    clear ttl
    ttl = sprintf('%s Axis Straightness (No Brake), %s',char(data.Ax2Name), SN);
    legend(sprintf('X = %1.1fmm',X(1,YPlots(i))))
    grid on
    xlim([0 max(Y(:,YPlots(i)))])
    if i == numYPlots
        xlabel('mm')
    end
    suptitle(ttl)
    orient tall
end
end


% SECTION 8. GENERATE CALIBRATION FILE ***********************************************************
% % Axis 1 direction is left to right in the table.  Axis 2 direction is
% top to bottom

if WriteCalFile

%check for existing calibration file
    p = dir(CalFile);             %find existing plots
        if length(p) > 0
        clear txt
        txt = sprintf('File %s already exists.  Overwrite?',CalFile);
        pause(0.3)
        button = questdlg(txt,'WARNING: File Already Exists','No');
        if strcmp(button,'No')
                WriteCalFile = 0;
        end
    end
end

if WriteCalFile

% Create signed calibration error tables
% Ax1cal = -Ax1Sign * round(Ax1Err*10000)/10000;    % units microns, precision to nm/10
% Ax2cal = -Ax2Sign * round(Ax2Err*10000)/10000;    % units microns, precision to nm/10

% Create signed calibration error tables (version 1.06 and later)
%   create cal tables such that the calibration table will be surrounded by
%   zeros.  This will allow smooth transition into and out of the
%   calibration table when the motion system moves through travel.
sizeCal = size(Ax1Err);

  % create matrices  filled zeros
Ax1cal = zeros((sizeCal(1)+2), (sizeCal(2)+2));  % add extra rows and columns for surrounding zeros
Ax2cal = Ax1cal;
  % populate middle of matrices with measured data
Ax1cal((2:(end-1)) , (2:(end-1))) = -Ax1Sign * round(Ax1Err * 10000)/10000;    % units microns, precision to nm/10
Ax2cal((2:(end-1)) , (2:(end-1))) = -Ax2Sign * round(Ax2Err * 10000)/10000;    % units microns, precision to nm/10
% update the variables NumAxPoints to include the new rows and columns of
% zeros surrounding the measurement data
NumAx1Points = NumAx1Points + 2;
NumAx2Points = NumAx2Points + 2;

% determine the number of gantry axes
numGantry = 0;
if Ax1Gantry ~= 0
    numGantry = 1;
end
if Ax2Gantry ~= 0
    numGantry = numGantry + 1;
end

% if numGantry == 0 && OutAxis3 ~= 0  % case of old data file without gantry header info
%     numGantry = 1;
% end

if numGantry > 1
    numTables = 2;
else
    numTables = 1;
end

fp = fopen(CalFile,'wt+');
for N = 1:numTables
if numGantry == 0
    OutAxis3 = 0;
else
    if N == 1
        if Ax1Gantry ~= 0
            OutAxis3 = abs(Ax1Gantry);
            OutAx3Value = sign(Ax1Gantry)*Ax1Num;
        elseif Ax2Gantry ~= 0
            OutAxis3 = abs(Ax2Gantry);
            OutAx3Value = sign(Ax2Gantry)*Ax2Num;
        end
    else
        OutAxis3 = abs(Ax2Gantry);
        OutAx3Value = sign(Ax2Gantry)*Ax2Num;
    end
end

% write cal file header based on options set in the inputs and also based
% on stage test location
fprintf(fp,':START2D %u %u %u %u %1.3f %1.3f %u \n', Ax2Num, Ax1Num, Ax1Num, Ax2Num,...
    Ax2Sign * Ax2SampDist * calDivisor , Ax1Sign * Ax1SampDist * calDivisor, NumAx1Points);
if OutAxis3 ~= 0
    ColumnMultiple = 3;               % number of columns per test location  (3 for three axis compensation)
    if (X(1,1) == 0) && (Y(1,1) == 0)
        fprintf(fp,':START2D OUTAXIS3=%u POSUNIT=%s CORUNIT=%s/%u \n', OutAxis3, UserUnit, UserUnit, 1000/calDivisor);
    else
        fprintf(fp,':START2D OUTAXIS3=%u POSUNIT=%s CORUNIT=%s/%u OFFSETROW = %1.3f OFFSETCOL = %1.3f \n', ...
            OutAxis3, UserUnit, UserUnit, 1000/calDivisor, -Ax2Sign * (Y(1,1)-Ax2SampDist) * calDivisor, -Ax1Sign * (X(1,1)-Ax1SampDist) * calDivisor);
    end
else
    ColumnMultiple = 2;               % number of columns per test location  (2 for two axis compensation)
    if (X(1,1) == 0) && (Y(1,1) == 0)
        fprintf(fp,':START2D POSUNIT=%s CORUNIT=%s/%u \n', UserUnit, UserUnit, 1000/calDivisor);
    else
        fprintf(fp,':START2D POSUNIT=%s CORUNIT=%s/%u OFFSETROW = %1.3f OFFSETCOL = %1.3f \n', ...
            UserUnit, UserUnit, 1000/calDivisor, -Ax2Sign * (Y(1,1)-Ax2SampDist) * calDivisor, -Ax1Sign * (X(1,1)-Ax1SampDist) * calDivisor);
    end
end

fprintf(fp,'\n');

for i = 1:NumAx2Points
    count = 0;
    for j = 1:ColumnMultiple:(ColumnMultiple*NumAx1Points)
        count = count+1;

        % create matrix CalTable to store calibration values
        if numTables > 1 & N == 1
            CalTable(i,j) = Ax1cal(i,count);           % axis 1 correction in 1st cal table
            CalTable(i,j+1) = 0;                       % zero correction of ax2 for 1st cal table
        elseif numTables > 1 & N == 2
            CalTable(i,j) = 0;                          % zero correction of ax1 for 2nd cal table
            CalTable(i,j+1) = Ax2cal(i,count);          % axis 2 correction in 2nd cal table
        else
            CalTable(i,j) = Ax1cal(i,count);           % Ax 1 correction -- one cal table only
            CalTable(i,j+1) = Ax2cal(i,count);         % Ax 2 correctoin -- one cal table only
        end
        if OutAxis3 ~= 0
            sign3 = sign(OutAx3Value);
            if abs(OutAx3Value) == (Ax1Num)
                CalTable(i,j+2) = sign3 * Ax1cal(i,count);     % Axis 3 correction same as Axis 1
            elseif abs(OutAx3Value) == (Ax2Num)
                CalTable(i,j+2) = sign3 * Ax2cal(i,count);     % Axis 3 correction same as Axis 2
            end
        end

        % write values in CalTable to file
        fprintf(fp,'%1.4f\t',CalTable(i,j));           % write cal value for the first axis
        if ColumnMultiple == 2                         % if no third axis value, check to see if this point is in the last column
            if j == (ColumnMultiple*NumAx1Points - 1)
                fprintf(fp,'%1.4f\n',CalTable(i,j+1));
            else
                fprintf(fp,'%1.4f\t',CalTable(i,j+1));
            end
        else
            fprintf(fp,'%1.4f\t',CalTable(i,j+1));     % if there is third axis cal value, write cal value for the second axis
            if j==(3*NumAx1Points - 2)                 % check to see if this point is in the last column
                fprintf(fp,'%1.4f\n',CalTable(i,j+2));
            else
                fprintf(fp,'%1.4f\t',CalTable(i,j+2));
            end
        end
    end
end
fprintf(fp,'\n');
fprintf(fp,':END');

if N < numTables
    fprintf(fp,'\n');
    fprintf(fp,'\n');
end

end  % for N = 1:numTables loop

fclose(fp);

clear txt
txt = sprintf('Calibration file name is %s',CalFile);
pause(0.3)
helpdlg(txt,'Calibration File Status')

end  %if WriteCalFile

% WRITE TEXT FILE OF ERRORS FOR CUSTOMER
if writeOutputFile
% write cal file header based on options set in the inputs and also based on stage test location
fp = fopen(OutFile,'wt+');
fprintf(fp,'% %s Position (mm), %s Position (mm), %s Direction Error (micron), %s Direction Error (mm) \n', Ax1Name, Ax2Name, Ax1Name, Ax2Name);
fprintf(fp,'% \n');
for i = 1:totalSize(1)
    count = 0;
    for j = 1:totalSize(2)
        % write values to file
        fprintf(fp,'%1.4f, %1.4f, %1.4f, %1.4f\n',X(i,j), Y(i,j), Ax1Err(i,j)-offset1, Ax2Err(i,j)-offset2);           % write cal value for the first axis
    end
end

fclose(fp);

clear txt
txt = sprintf('Output file name is %s',OutFile);
pause(0.3)
helpdlg(txt,'Output File Status')

end  %if writeOutputFile



