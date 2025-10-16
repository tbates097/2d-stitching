function data = A3200ACC2DMULTIZONE(InputFile, CalFile, OutAxis3, OutAx3Value, Units)
% A3200ACC2DMULTIZONE  Plot 2D accuracy measured using the A3200 Controller
% Octave-compatible version with debug output for comparison with Python
%
% This version:
% - Replaces GUI functions with command-line equivalents
% - Adds debug output for step-by-step comparison
% - Compatible with GNU Octave
%

if nargin == 0
  disp('Press Enter to Close...')
  pause
else

fName = InputFile;
WriteCalFile = 0;  

%if only input and output files are specified, set options to default values
if nargin == 2          
    OutAxis3 = 0;          
    OutAx3Value = 0;       
    Units = 0;             
end

%if third axis calibration is specified, but master of gantry axis is not, report an error
if nargin == 3 & OutAxis3 ~= 0
    error('*****Not enough Inputs! OUTAX3VALUE required.*****');
end

%if units is specified, set value and check for incorrect entry
if nargin == 5
    if Units == 0
        UserUnit = 'METRIC';
    elseif Units == 1
        UserUnit = 'ENGLISH';
    else
        error('*** Incorrect UNITS input parameter:  0 = METRIC, 1 = ENGLISH ***')
    end
else
    UserUnit = 'METRIC';
end
    
% read serial number, axes names, and axes numbers used during data collection from file header
fid = fopen( fName ); % open file for input

if( fid == -1 )
    error(sprintf('*****Could not find file %s!!!!*****', fName));
end

% get serial number
ftxt = fgetl(fid);         
for i =1:length(ftxt)
    if ftxt(i) == ':'
        SN = ftxt((i+2):length(ftxt));      
        break
    end
end

% get name, number, and program units sign of first axis
ftxt = fgetl(fid);          
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
Ax1Name = ftxt(starttxt:endtxt);    

% get axis number
for i =endtxt:length(ftxt)
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
Ax1Num = str2num(ftxt(starttxt:endtxt));    

%get program units sign of first axis
for i =endtxt:length(ftxt)
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
    Ax1Gantry = 0;  
else
    Ax1Gantry = str2num(ftxt(starttxt:length(ftxt)));
end

% get name and number of second axis
ftxt = fgetl(fid);        
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
    if ftxt(i) == ';'       
        endtxt = i-1;
        break
    end
end
Ax2Num = str2num(ftxt(starttxt:endtxt));    

%get program units sign of second axis
for i =endtxt:length(ftxt)
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
    Ax2Gantry = 0;  
else
    Ax2Gantry = str2num(ftxt(starttxt:length(ftxt)));
end

% read user units from the data file
UserUnit = 'METRIC';      
calDivisor = 1;           
posUnit = 'mm';           
errUnit = '\mum';         

if starttxt ~= 0          
    ftxt = fgetl(fid);        
    for i =1:length(ftxt)
        if ftxt(i) == ':'
            starttxt = i+2;
            break
        end
    end
    temp = ftxt(starttxt:end); 
    if strcmp(temp,'UM')      
        calDivisor = 1000;    
    elseif strcmp(temp,'ENGLISH')
        UserUnit = 'ENGLISH'; 
        posUnit = 'in';       
        errUnit = 'mil';      
    end
end

ftxt = fgetl(fid);           
parse1 = strfind(ftxt,':');  
parse2 = strfind(ftxt,';');  
if strcmp(ftxt(1:9),'%Operator')  
    operator = ftxt((parse1(1)+2):(parse2(1)-1));
    model = ftxt((parse1(2)+2):(parse2(2)-1));
    airTemp = ftxt((parse1(3)+2):(parse2(3)-1));
    matTemp = ftxt((parse1(4)+2):(parse2(4)-1));
    expandCoef = ftxt((parse1(5)+2):(parse2(5)-1));
    comment = ftxt((parse1(6)+2):end);
else  
    operator = '';
    model = '';
    airTemp = '';
    matTemp = '';
    expandCoef = '';
    comment = '';
end

% get date (Octave compatible)
if exist(InputFile, 'file')
    fileInfo = dir(InputFile);
    if ~isempty(fileInfo)
        fileDate = fileInfo(1).date;
    else
        fileDate = '';
    end
else
    fileDate = '';
end

fclose(fid);

% DEBUG OUTPUT - Header parsing
fprintf('=== DEBUG: Header Parsing ===\n');
fprintf('SN: %s\n', SN);
fprintf('Ax1Name: %s, Ax1Num: %d, Ax1Sign: %d, Ax1Gantry: %d\n', Ax1Name, Ax1Num, Ax1Sign, Ax1Gantry);
fprintf('Ax2Name: %s, Ax2Num: %d, Ax2Sign: %d, Ax2Gantry: %d\n', Ax2Name, Ax2Num, Ax2Sign, Ax2Gantry);
fprintf('UserUnit: %s, calDivisor: %d\n', UserUnit, calDivisor);

y_meas_dir = -1;   

% SECTION 2. LOAD TEST DATA 
% change data file format and open file
s = load(fName);
% sort data for ascending step and scan positions
s = sortrows(s,[2 1]);

% DEBUG OUTPUT - Raw data loading
fprintf('\n=== DEBUG: Raw Data Loading ===\n');
fprintf('Data shape: %d x %d\n', size(s,1), size(s,2));
fprintf('First 5 data points:\n');
for i=1:min(5,size(s,1))
    fprintf('  %.1f %.1f %.6f %.6f %.6f %.6f\n', s(i,1), s(i,2), s(i,3), s(i,4), s(i,5), s(i,6));
end

% load data from file
Ax1TestLoc = s(:,1);        
Ax2TestLoc = s(:,2);        
Ax1PosCmd = s(:,3) / calDivisor;         
Ax2PosCmd = s(:,4) / calDivisor;         
Ax1RelErr = s(:,5) / calDivisor;         
Ax2RelErr = s(:,6) / calDivisor;         

% SECTION 3. CALCULATE RELATIVE ERROR, NUMBER OF TEST POINTS, SAMPLE DISTANCE, AND MOVE DISTANCES 

Ax1RelErr = (Ax1RelErr-mean(Ax1RelErr)) * 1000;   
Ax2RelErr = (Ax2RelErr-mean(Ax2RelErr)) * 1000;   

% DEBUG OUTPUT - Error processing
fprintf('\n=== DEBUG: Error Processing ===\n');
fprintf('Ax1RelErr range: %.6f to %.6f um\n', min(Ax1RelErr), max(Ax1RelErr));
fprintf('Ax2RelErr range: %.6f to %.6f um\n', min(Ax2RelErr), max(Ax2RelErr));

% calculate the number of test locations, the total move distances, and the step distances
NumAx1Points = max(Ax1TestLoc);
NumAx2Points = max(Ax2TestLoc);
Ax1MoveDist = max(Ax1PosCmd) - min(Ax1PosCmd);
Ax2MoveDist = max(Ax2PosCmd) - min(Ax2PosCmd);
Ax1SampDist = Ax1PosCmd(2) - Ax1PosCmd(1);
Ax2SampDist = Ax2PosCmd(NumAx1Points + 1) - Ax2PosCmd(1);

fprintf('Grid: %dx%d points\n', NumAx1Points, NumAx2Points);
fprintf('Ax1 range: %.1f to %.1f mm (dist: %.1f)\n', min(Ax1PosCmd), max(Ax1PosCmd), Ax1MoveDist);
fprintf('Ax2 range: %.1f to %.1f mm (dist: %.1f)\n', min(Ax2PosCmd), max(Ax2PosCmd), Ax2MoveDist);
fprintf('Sample distances: Ax1=%.6f, Ax2=%.6f\n', Ax1SampDist, Ax2SampDist);

% SECTION 4. CREATE 2D POSITION AND ERROR TABLES 

% Create position vectors for Ax1 and Ax2
Ax1Pos = Ax1PosCmd(1:NumAx1Points);
Ax2Pos = Ax2PosCmd(1:(NumAx1Points):(NumAx1Points*NumAx2Points));

% create 2D matrices for Ax1 and Ax2 position and laser data
[X,Y] = meshgrid(Ax1Pos, Ax2Pos);
SizeGrid = size(X);
%normalize position vectors for griddata command
maxAx1 = max(Ax1Pos)-min(Ax1Pos);
maxAx2 = max(Ax2Pos)-min(Ax2Pos);
Ax1Err = griddata(Ax1PosCmd/maxAx1, Ax2PosCmd/maxAx2, Ax1RelErr, X/maxAx1, Y/maxAx2);
Ax2Err = griddata(Ax1PosCmd/maxAx1, Ax2PosCmd/maxAx2, Ax2RelErr, X/maxAx1, Y/maxAx2);

% DEBUG OUTPUT - Grid creation
fprintf('\n=== DEBUG: Grid Creation ===\n');
fprintf('Grid shape: %dx%d\n', SizeGrid(1), SizeGrid(2));
fprintf('X corners: TL=%.1f, TR=%.1f, BL=%.1f, BR=%.1f\n', X(1,1), X(1,end), X(end,1), X(end,end));
fprintf('Y corners: TL=%.1f, TR=%.1f, BL=%.1f, BR=%.1f\n', Y(1,1), Y(1,end), Y(end,1), Y(end,end));
fprintf('Ax1Err corners: TL=%.6f, TR=%.6f, BL=%.6f, BR=%.6f\n', Ax1Err(1,1), Ax1Err(1,end), Ax1Err(end,1), Ax1Err(end,end));
fprintf('Ax2Err corners: TL=%.6f, TR=%.6f, BL=%.6f, BR=%.6f\n', Ax2Err(1,1), Ax2Err(1,end), Ax2Err(end,1), Ax2Err(end,end));

% SECTION 5. REMOVE MIRROR SLOPE AND CALCULATE ORTHOGONALITY 

% line fit the straightness error data with respect to the stage position
Ax1Coef = polyfit(Y(:,1), mean(Ax1Err,2),1);   % slope units microns/mm
Ax2Coef = polyfit(X(1,:), mean(Ax2Err),1);   % slope units microns/mm

% create best fit line for X data, use X line for Y data (to calibrate in orthogonality)
Ax1Line = polyval(Ax1Coef, Y(:,1));
Ax2Line = polyval(y_meas_dir * Ax1Coef, X(1,:));

% create straightness data for orthogonality plots (remove best fit lines)
Ax1Orthog = mean(Ax1Err,2) - Ax1Line;
Ax2Orthog = mean(Ax2Err) - polyval(Ax2Coef, X(1,:));

% subrtract the line fits from the Ax1 and Ax2 error data (remove mirror slope)
for i = 1:SizeGrid(2)
    Ax1Err(:,i) = Ax1Err(:,i) - Ax1Line;
end
for i = 1:SizeGrid(1)
    Ax2Err(i,:) = Ax2Err(i,:) - Ax2Line;
end

% calculate orthogonality
orthog = Ax1Coef(1) - y_meas_dir * Ax2Coef(1);
orthog = atan(orthog/1000) * 180/pi * 3600;  % arc sec

% DEBUG OUTPUT - Slope calculation
fprintf('\n=== DEBUG: Slope Calculation ===\n');
fprintf('Ax1Coef: [%.6f %.6f]\n', Ax1Coef(1), Ax1Coef(2));
fprintf('Ax2Coef: [%.6f %.6f]\n', Ax2Coef(1), Ax2Coef(2));
fprintf('Orthogonality: %.6f arc-sec\n', orthog);
fprintf('Ax1Line range: %.6f to %.6f\n', min(Ax1Line), max(Ax1Line));
fprintf('Ax2Line range: %.6f to %.6f\n', min(Ax2Line), max(Ax2Line));

% SECTION 6. CALCULATE THE VECTOR SUM ACCURACY ERROR 

% subtract error at origin of xy grid prior to vector sum calculation
Ax1Err = Ax1Err - Ax1Err(1,1);
Ax2Err = Ax2Err - Ax2Err(1,1);

% calculate the total vector sum accuracy error
VectorErr = sqrt(Ax1Err.^2 + Ax2Err.^2);

% DEBUG OUTPUT - Final processing 
fprintf('\n=== DEBUG: Final Error Processing ===\n');
fprintf('Zero-referencing offsets: Ax1=%.6f, Ax2=%.6f\n', Ax1Err(1,1), Ax2Err(1,1));
fprintf('After zero-ref, Ax1Err range: %.6f to %.6f\n', min(min(Ax1Err)), max(max(Ax1Err)));
fprintf('After zero-ref, Ax2Err range: %.6f to %.6f\n', min(min(Ax2Err)), max(max(Ax2Err)));
fprintf('VectorErr range: %.6f to %.6f\n', min(min(VectorErr)), max(max(VectorErr)));

% NOTE: Skipping plotting sections for Octave compatibility
% Original MATLAB plotting code would go here...

end  %if nargin == 0 else

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

% DEBUG OUTPUT - Final data structure
fprintf('\n=== DEBUG: Final Data Structure ===\n');
fprintf('data.X shape: %dx%d\n', size(data.X,1), size(data.X,2));
fprintf('data.Y shape: %dx%d\n', size(data.Y,1), size(data.Y,2));
fprintf('data.Ax1Err shape: %dx%d\n', size(data.Ax1Err,1), size(data.Ax1Err,2));
fprintf('data.Ax2Err shape: %dx%d\n', size(data.Ax2Err,1), size(data.Ax2Err,2));

endfunction