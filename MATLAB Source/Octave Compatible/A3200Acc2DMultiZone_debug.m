function data = A3200ACC2DMULTIZONE_DEBUG(InputFile, CalFile, OutAxis3, OutAx3Value, Units)
% A3200ACC2DMULTIZONE_DEBUG - Debug version with intermediate output logging
%
% This is a modified version of A3200Acc2DMultiZone.m that outputs intermediate
% values at each major processing step for verification against the step-by-step
% implementation.

% SECTION 1.0 CHECK INPUTS AND READ INPUT FILE HEADER
% ****************************************************

disp(' ')
disp('A3200ACC2DMULTIZONE_DEBUG.m - Debug version for verification');
disp(' ')

if nargin == 0
  disp('Press Enter to Close...')
  pause
else

fName = InputFile;
WriteCalFile = 0;  % Don't write cal files in debug mode

%if only input and output files are specified, set options to default values
if nargin == 2          
    OutAxis3 = 0;          % do not write third axis calibration
    OutAx3Value = 0;       % do not write third axis calibration
    Units = 0;             % use default units METRIC
end

%if third axis calibration is specified, but master of gantry axis is not, report an error
if nargin == 3 & OutAxis3 ~= 0
    err = sprintf('*****Not enough Inputs! OUTAX3VALUE required.  Type help StaticCal2D for more info *****');
	error(err);
end

%if units is specified, set value and check for incorrect entry
if nargin == 5
    if Units == 0
        UserUnit = 'METRIC';
    elseif Units == 1
        UserUnit = 'ENGLISH';
    else
        err = '*** Incorrect UNITS input parameter:  0 = METRIC, 1 = ENGLISH ***';
        error(err)
    end
else
    UserUnit = 'METRIC';
end
    
% read serial number, axes names, and axes numbers used during data collection from file header
fid = fopen( fName ); % open file for input

if( fid == -1 )
    err = sprintf('*****Could not find file %s!!!!*****', fName);
	errordlg(err);
end

% get serial number
ftxt = fgetl(fid);         % read a first line of text from the file (serial number)
for i =1:length(ftxt)
    if ftxt(i) == ':'
        SN = ftxt((i+2):length(ftxt));      % write serial number value
        break
    end
end

% get name, number, and program units sign of first axis
ftxt = fgetl(fid);          % read a line of text from the file
for i =1:length(ftxt)       % search for the start of the axis name (preceded by a colon)
    if ftxt(i) == ':'
        starttxt = i+2;
        break
    end
end
for i = starttxt:length(ftxt)
    if ftxt(i) == ';'       % search for the end of the axis name (followed by a semicolon)
        endtxt = i-1;
        break
    end
end
Ax1Name = ftxt(starttxt:endtxt);    % write the Axis 1 name value

% get axis number
for i =endtxt:length(ftxt)
    if ftxt(i) == ':'
        starttxt = i+2;
        break
    end
end
for i = starttxt:length(ftxt)
    if ftxt(i) == ';'       % search for the end of the axis number (followed by a semicolon)
        endtxt = i-1;
        break
    end
end
Ax1Num = str2num(ftxt(starttxt:endtxt));    % write the Axis 1 number value

%get program units sign of first axis
for i =endtxt:length(ftxt)
    if ftxt(i) == ':'
        starttxt = i+2;
        break
    end
end
for i = starttxt:length(ftxt)
    if ftxt(i) == ';'       % search for the end of the axis number (followed by a semicolon)
        endtxt = i-1;
        break
    end
    if i == length(ftxt)
        endtxt = length(ftxt);
    end
end
Ax1Sign = str2num(ftxt(starttxt:endtxt));

%get gantry axis value of first axis
starttxt = 0;
for i =endtxt:length(ftxt)
    if ftxt(i) == ':'
        starttxt = i+2;
        break
    end
end
if starttxt == 0
    Ax1Gantry = 0;  % old data files do not have a gantry entry line, so this sets value in that case
else
    Ax1Gantry = str2num(ftxt(starttxt:length(ftxt)));
end

% get name and number of second axis
ftxt = fgetl(fid);        % read a line of text from the file
for i =1:length(ftxt)
    if ftxt(i) == ':'
        starttxt = i+2;
        break
    end
end
for i = starttxt:length(ftxt)
    if ftxt(i) == ';'
        endtxt = i-1;
        break
    end
end
Ax2Name = ftxt(starttxt:endtxt);

% get axis number
for i =endtxt:length(ftxt)
    if ftxt(i) == ':'
        starttxt = i+2;
        break
    end
end
for i = starttxt:length(ftxt)
    if ftxt(i) == ';'       % search for the end of the axis number (followed by a semicolon)
        endtxt = i-1;
        break
    end
end
Ax2Num = str2num(ftxt(starttxt:endtxt));    % write the Axis 2 number value

%get program units sign of second axis
for i =endtxt:length(ftxt)
    if ftxt(i) == ':'
        starttxt = i+2;
        break
    end
end
for i = starttxt:length(ftxt)
    if ftxt(i) == ';'       % search for the end of the axis number (followed by a semicolon)
        endtxt = i-1;
        break
    end
    if i == length(ftxt)
        endtxt = length(ftxt);
    end
end
Ax2Sign = str2num(ftxt(starttxt:endtxt));

%get gantry axis value of second axis
starttxt = 0;
for i =endtxt:length(ftxt)
    if ftxt(i) == ':'
        starttxt = i+2;
        break
    end
end
if starttxt == 0
    Ax2Gantry = 0;  % old data files do not have a gantry entry line, so this sets value in that case
else
    Ax2Gantry = str2num(ftxt(starttxt:length(ftxt)));
end

% read user units from the data file
UserUnit = 'METRIC';      %set default units as METRIC, then check for other cases
calDivisor = 1;           %error scaling for calibration table (mm = 1, um = 1000)
posUnit = 'mm';           %position units for charts
errUnit = '\mum';         %error units for charts

if starttxt ~= 0          %old data files do not have UserUnit header line
    ftxt = fgetl(fid);        % read a line of text from the file
    for i =1:length(ftxt)
        if ftxt(i) == ':'
            starttxt = i+2;
            break
        end
    end
    temp = ftxt(starttxt:end); 
    if strcmp(temp,'UM')      %micron program units case
        calDivisor = 1000;    %error scaling for position units and calibration table
    elseif strcmp(temp,'ENGLISH')
        UserUnit = 'ENGLISH'; %english (inch) units case
        posUnit = 'in';       %position units for charts
        errUnit = 'mil';      %error units for charts
    end
end

ftxt = fgetl(fid);           % read a line of text from the file
parse1 = strfind(ftxt,':');  % find all instances of :
parse2 = strfind(ftxt,';');  % find all instances of ;
if strcmp(ftxt(1:9),'%Operator')  % see if this is a new data file and get values
    operator = ftxt((parse1(1)+2):(parse2(1)-1));
    model = ftxt((parse1(2)+2):(parse2(2)-1));
    airTemp = ftxt((parse1(3)+2):(parse2(3)-1));
    matTemp = ftxt((parse1(4)+2):(parse2(4)-1));
    expandCoef = ftxt((parse1(5)+2):(parse2(5)-1));
    comment = ftxt((parse1(6)+2):end);
else  % or, for old data files, set new documentation variables to empty strings
    operator = '';
    model = '';
    airTemp = '';
    matTemp = '';
    expandCoef = '';
    comment = '';
end

% get date
fileInfo = dir(InputFile);
fileDate = fileInfo.date;

fclose(fid);

% *** DEBUG OUTPUT: STEP 1 EQUIVALENT ***
fprintf('\n=== DEBUG STEP 1: HEADER PARSER ===\n');
fprintf('SerialNumber: %s\n', SN);
fprintf('Ax1Name: %s\n', Ax1Name);
fprintf('Ax1Num: %d\n', Ax1Num);
fprintf('Ax1Sign: %d\n', Ax1Sign);
fprintf('Ax1Gantry: %d\n', Ax1Gantry);
fprintf('Ax2Name: %s\n', Ax2Name);
fprintf('Ax2Num: %d\n', Ax2Num);
fprintf('Ax2Sign: %d\n', Ax2Sign);
fprintf('Ax2Gantry: %d\n', Ax2Gantry);
fprintf('UserUnit: %s\n', UserUnit);
fprintf('calDivisor: %d\n', calDivisor);
fprintf('posUnit: %s\n', posUnit);
fprintf('errUnit: %s\n', errUnit);
fprintf('operator: %s\n', operator);
fprintf('model: %s\n', model);
fprintf('airTemp: %s\n', airTemp);
fprintf('matTemp: %s\n', matTemp);
fprintf('expandCoef: %s\n', expandCoef);
fprintf('comment: %s\n', comment);
fprintf('fileDate: %s\n', fileDate);

y_meas_dir = -1;   % slope due to mirror misalignment is always opposite sign between the axes when the laser
                   % and encoder read positive in the same direction

% SECTION 2. LOAD TEST DATA **************************************************************

% change data file format and open file
s = load(fName);
% sort data for ascending step and scan positions
s = sortrows(s,[2 1]);

% load data from file
Ax1TestLoc = s(:,1);        % incremental counter, no units
Ax2TestLoc = s(:,2);        % incremental counter, no units
Ax1PosCmd = s(:,3) / calDivisor;         % for micron program units case, convert to mm
Ax2PosCmd = s(:,4) / calDivisor;         % for micron program units case, convert to mm
Ax1RelErr = s(:,5) / calDivisor;         % for micron program units case, convert to mm
Ax2RelErr = s(:,6) / calDivisor;         % for micron program units case, convert to mm

% SECTION 3. CALCULATE RELATIVE ERROR, NUMBER OF TEST POINTS, SAMPLE DISTANCE, AND MOVE DISTANCES *****

Ax1RelErr = (Ax1RelErr-mean(Ax1RelErr)) * 1000;   % convert to microns, subtract mean error
Ax2RelErr = (Ax2RelErr-mean(Ax2RelErr)) * 1000;   % convert to microns, subtract mean error

% calculate the number of test locations, the total move distances, and the step distances
NumAx1Points = max(Ax1TestLoc);
NumAx2Points = max(Ax2TestLoc);
Ax1MoveDist = max(Ax1PosCmd) - min(Ax1PosCmd);
Ax2MoveDist = max(Ax2PosCmd) - min(Ax2PosCmd);
Ax1SampDist = Ax1PosCmd(2) - Ax1PosCmd(1);
Ax2SampDist = Ax2PosCmd(NumAx1Points + 1) - Ax2PosCmd(1);

% Create position vectors for Ax1 and Ax2
Ax1Pos = Ax1PosCmd(1:NumAx1Points);
Ax2Pos = Ax2PosCmd(1:(NumAx1Points):(NumAx1Points*NumAx2Points));

% *** DEBUG OUTPUT: STEP 2 EQUIVALENT ***
fprintf('\n=== DEBUG STEP 2: RAW DATA LOADER ===\n');
fprintf('NumAx1Points: %d\n', NumAx1Points);
fprintf('NumAx2Points: %d\n', NumAx2Points);
fprintf('TotalDataPoints: %d\n', NumAx1Points * NumAx2Points);
fprintf('Ax1MoveDist: %.6f\n', Ax1MoveDist);
fprintf('Ax2MoveDist: %.6f\n', Ax2MoveDist);
fprintf('Ax1SampDist: %.6f\n', Ax1SampDist);
fprintf('Ax2SampDist: %.6f\n', Ax2SampDist);
fprintf('Ax1Pos_min: %.6f\n', min(Ax1Pos));
fprintf('Ax1Pos_max: %.6f\n', max(Ax1Pos));
fprintf('Ax2Pos_min: %.6f\n', min(Ax2Pos));
fprintf('Ax2Pos_max: %.6f\n', max(Ax2Pos));
fprintf('Ax1RelErr_um_min: %.6f\n', min(Ax1RelErr));
fprintf('Ax1RelErr_um_max: %.6f\n', max(Ax1RelErr));
fprintf('Ax2RelErr_um_min: %.6f\n', min(Ax2RelErr));
fprintf('Ax2RelErr_um_max: %.6f\n', max(Ax2RelErr));

% SECTION 4. CREATE 2D POSITION AND ERROR TABLES *******************************************************

% create 2D matrices for Ax1 and Ax2 position and laser data
[X,Y] = meshgrid(Ax1Pos, Ax2Pos);
SizeGrid = size(X);
%normalize position vectors for griddata command
%MJS 5Feb2018 - Changed the next two lines to max-min to fix a bug where
%all negative travel led to divide by zero.
maxAx1 = max(Ax1Pos)-min(Ax1Pos);
maxAx2 = max(Ax2Pos)-min(Ax2Pos);
Ax1Err = griddata(Ax1PosCmd/maxAx1, Ax2PosCmd/maxAx2, Ax1RelErr, X/maxAx1, Y/maxAx2);
Ax2Err = griddata(Ax1PosCmd/maxAx1, Ax2PosCmd/maxAx2, Ax2RelErr, X/maxAx1, Y/maxAx2);

% *** DEBUG OUTPUT: STEP 3 EQUIVALENT ***
fprintf('\n=== DEBUG STEP 3: GRID CREATOR ===\n');
fprintf('GridSize_rows: %d\n', SizeGrid(1));
fprintf('GridSize_cols: %d\n', SizeGrid(2));
fprintf('X_min: %.6f\n', min(min(X)));
fprintf('X_max: %.6f\n', max(max(X)));
fprintf('Y_min: %.6f\n', min(min(Y)));
fprintf('Y_max: %.6f\n', max(max(Y)));
fprintf('Ax1Err_min: %.6f\n', min(min(Ax1Err)));
fprintf('Ax1Err_max: %.6f\n', max(max(Ax1Err)));
fprintf('Ax2Err_min: %.6f\n', min(min(Ax2Err)));
fprintf('Ax2Err_max: %.6f\n', max(max(Ax2Err)));
fprintf('maxAx1: %.6f\n', maxAx1);
fprintf('maxAx2: %.6f\n', maxAx2);
fprintf('NaN_count_Ax1: %d\n', sum(sum(isnan(Ax1Err))));
fprintf('NaN_count_Ax2: %d\n', sum(sum(isnan(Ax2Err))));

% SECTION 5. REMOVE MIRROR SLOPE AND CALCULATE ORTHOGONALITY ******************************************

% line fit the straightness error data with respect to the stage position
Ax1Coef = polyfit(Y(:,1), mean(Ax1Err,2),1);   % slope units microns/mm
Ax2Coef = polyfit(X(1,:), mean(Ax2Err),1);   % slope units microns/mm

% create best fit line for X data, use X line for Y data (to calibrate in orthogonality)
Ax1Line = polyval(Ax1Coef, Y(:,1));
Ax2Line = polyval(y_meas_dir * Ax1Coef, X(1,:));

% create straightness data for orthogonality plots (remove best fit lines)
Ax1Orthog = mean(Ax1Err,2) - Ax1Line;
Ax2Orthog = mean(Ax2Err) - polyval(Ax2Coef, X(1,:));

% calculate orthogonality
orthog = Ax1Coef(1) - y_meas_dir * Ax2Coef(1);
orthog = atan(orthog/1000) * 180/pi * 3600;  % arc sec

% *** DEBUG OUTPUT: STEP 4 EQUIVALENT ***
fprintf('\n=== DEBUG STEP 4: SLOPE CALCULATOR ===\n');
fprintf('Ax1Coef_slope: %.12f\n', Ax1Coef(1));
fprintf('Ax1Coef_offset: %.12f\n', Ax1Coef(2));
fprintf('Ax2Coef_slope: %.12f\n', Ax2Coef(1));
fprintf('Ax2Coef_offset: %.12f\n', Ax2Coef(2));
fprintf('orthog_arcsec: %.12f\n', orthog);
fprintf('y_meas_dir: %d\n', y_meas_dir);
fprintf('Ax1Line_min: %.12f\n', min(Ax1Line));
fprintf('Ax1Line_max: %.12f\n', max(Ax1Line));
fprintf('Ax2Line_min: %.12f\n', min(Ax2Line));
fprintf('Ax2Line_max: %.12f\n', max(Ax2Line));
fprintf('Ax1Orthog_std: %.12f\n', std(Ax1Orthog));
fprintf('Ax2Orthog_std: %.12f\n', std(Ax2Orthog));
fprintf('mean_ax1_err_min: %.12f\n', min(mean(Ax1Err,2)));
fprintf('mean_ax1_err_max: %.12f\n', max(mean(Ax1Err,2)));
fprintf('mean_ax2_err_min: %.12f\n', min(mean(Ax2Err)));
fprintf('mean_ax2_err_max: %.12f\n', max(mean(Ax2Err)));
      
% subrtract the line fits from the Ax1 and Ax2 error data (remove mirror slope)
for i = 1:SizeGrid(2)
    Ax1Err(:,i) = Ax1Err(:,i) - Ax1Line;
end
for i = 1:SizeGrid(1)
    Ax2Err(i,:) = Ax2Err(i,:) - Ax2Line;
end

% SECTION 6. CALCULATE THE VECTOR SUM ACCURACY ERROR ****************************************** 

% subtract error at origin of xy grid prior to vector sum calculation
Ax1Err = Ax1Err - Ax1Err(1,1);
Ax2Err = Ax2Err - Ax2Err(1,1);

% calculate the total vector sum accuracy error
VectorErr = sqrt(Ax1Err.^2 + Ax2Err.^2);

% calculate peak to peak values
pkAx1 = max(max(Ax1Err))-min(min(Ax1Err));
pkAx2 = max(max(Ax2Err))-min(min(Ax2Err));

% *** DEBUG OUTPUT: STEP 5 EQUIVALENT ***
fprintf('\n=== DEBUG STEP 5: ERROR PROCESSOR ===\n');
fprintf('Ax1Err_min: %.12f\n', min(min(Ax1Err)));
fprintf('Ax1Err_max: %.12f\n', max(max(Ax1Err)));
fprintf('Ax2Err_min: %.12f\n', min(min(Ax2Err)));
fprintf('Ax2Err_max: %.12f\n', max(max(Ax2Err)));
fprintf('VectorErr_min: %.12f\n', min(min(VectorErr)));
fprintf('VectorErr_max: %.12f\n', max(max(VectorErr)));
fprintf('pkAx1: %.12f\n', pkAx1);
fprintf('pkAx2: %.12f\n', pkAx2);
fprintf('maxVectorErr: %.12f\n', max(max(VectorErr)));
fprintf('rmsAx1: %.12f\n', std(Ax1Err(:)));
fprintf('rmsAx2: %.12f\n', std(Ax2Err(:)));
fprintf('rmsVector: %.12f\n', std(VectorErr(:)));
fprintf('Ax1amplitude: %.12f\n', pkAx1/2);
fprintf('Ax2amplitude: %.12f\n', pkAx2/2);
fprintf('orthog_arcsec: %.12f\n', orthog);

% Continue with original plotting code but don't show plots in debug mode
% (plots suppressed for clean debug output)

% Return the data structure as original function does
data.X = X;
data.Y = Y;
data.Ax1Err = Ax1Err;
data.Ax2Err = Ax2Err;
data.SN = SN;
data.Ax1Name = Ax1Name;
data.Ax2Name = Ax2Name;
data.Ax1Num = Ax1Num;
data.Ax2Num = Ax2Num;
data.Ax1Sign = Ax1Sign;
data.Ax2Sign = Ax2Sign;
data.UserUnit = UserUnit;      
data.calDivisor = calDivisor;          
data.posUnit = posUnit;           
data.errUnit = errUnit;
data.Ax1Gantry = Ax1Gantry;
data.Ax2Gantry = Ax2Gantry;
data.Ax1SampDist = Ax1SampDist;
data.Ax2SampDist = Ax2SampDist;
data.operator = operator;
data.model = model;
data.airTemp = airTemp;
data.matTemp = matTemp;
data.expandCoef = expandCoef;
data.comment = comment;
data.fileDate = fileDate;

fprintf('\n=== DEBUG OUTPUT COMPLETE ===\n');

end  %if nargin == 0 else
