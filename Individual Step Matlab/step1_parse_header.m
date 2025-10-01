function config = step1_parse_header(InputFile)
% STEP1_PARSE_HEADER - Parse data file header and extract system configuration
% 
% This function extracts axis names, numbers, signs, gantry info, and other
% system parameters from the data file header
%
% INPUT:
%   InputFile - string, path to the data file
%
% OUTPUT:
%   config - structure containing all parsed configuration parameters

% Initialize output structure
config = struct();

% Open file for reading header
fid = fopen(InputFile);
if fid == -1
    error('Could not find file %s', InputFile);
end

% Parse serial number (first line)
ftxt = fgetl(fid);
for i = 1:length(ftxt)
    if ftxt(i) == ':'
        config.SN = ftxt((i+2):length(ftxt));
        break
    end
end

% Parse Axis 1 information (second line)
ftxt = fgetl(fid);
% Get axis name
for i = 1:length(ftxt)
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
config.Ax1Name = ftxt(starttxt:endtxt);

% Get axis number
for i = endtxt:length(ftxt)
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
config.Ax1Num = str2num(ftxt(starttxt:endtxt));

% Get program units sign
for i = endtxt:length(ftxt)
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
config.Ax1Sign = str2num(ftxt(starttxt:endtxt));

% Get slave axis value (if present) 
starttxt = 0;
for i = endtxt:length(ftxt)
    if ftxt(i) == ':'
        starttxt = i+2;
        break
    end
end
if starttxt == 0
    config.Ax1Gantry = 0;  % Old data files don't have slave entry
else
    config.Ax1Gantry = str2num(ftxt(starttxt:length(ftxt)));
end

% Parse Axis 2 information (third line)
ftxt = fgetl(fid);
% Get axis name
for i = 1:length(ftxt)
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
config.Ax2Name = ftxt(starttxt:endtxt);

% Get axis number
for i = endtxt:length(ftxt)
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
config.Ax2Num = str2num(ftxt(starttxt:endtxt));

% Get program units sign
for i = endtxt:length(ftxt)
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
config.Ax2Sign = str2num(ftxt(starttxt:endtxt));

% Get slave axis value (if present)
starttxt = 0;
for i = endtxt:length(ftxt)
    if ftxt(i) == ':'
        starttxt = i+2;
        break
    end
end
if starttxt == 0
    config.Ax2Gantry = 0;  % Old data files don't have slave entry
else
    config.Ax2Gantry = str2num(ftxt(starttxt:length(ftxt)));
end

% Parse user units (fourth line: %UserUnits: MM)
config.UserUnit = 'METRIC';  % Default
config.calDivisor = 1;       % Default
config.posUnit = 'mm';       % Default
config.errUnit = '\mum';     % Default

ftxt = fgetl(fid);  % Read UserUnits line
if ~isempty(ftxt) && length(ftxt) > 12 && strcmp(ftxt(1:12), '%UserUnits: ')
    temp = strtrim(ftxt(13:end));  % Extract units after "%UserUnits: "
    if strcmp(temp, 'UM')  % Micron program units
        config.calDivisor = 1000;
    elseif strcmp(temp, 'ENGLISH') || strcmp(temp, 'INCH')
        config.UserUnit = 'ENGLISH';
        config.posUnit = 'in';
        config.errUnit = 'mil';
    end
end

% Parse operator, model, temperatures, etc. (if present)
ftxt = fgetl(fid);
parse1 = strfind(ftxt, ':');
parse2 = strfind(ftxt, ';');
if length(ftxt) >= 9 && strcmp(ftxt(1:9), '%Operator')  % New data file format
    config.operator = ftxt((parse1(1)+2):(parse2(1)-1));
    config.model = ftxt((parse1(2)+2):(parse2(2)-1));
    config.airTemp = ftxt((parse1(3)+2):(parse2(3)-1));
    config.matTemp = ftxt((parse1(4)+2):(parse2(4)-1));
    config.expandCoef = ftxt((parse1(5)+2):(parse2(5)-1));
    config.comment = ftxt((parse1(6)+2):end);
else  % Old data files
    config.operator = '';
    config.model = '';
    config.airTemp = '';
    config.matTemp = '';
    config.expandCoef = '';
    config.comment = '';
end

% Get file date
fileInfo = dir(InputFile);
config.fileDate = fileInfo.date;

% Close file
fclose(fid);

% Display parsed configuration for verification
fprintf('\n=== PARSED CONFIGURATION ===\n');
fprintf('Serial Number: %s\n', config.SN);
fprintf('Axis 1: %s (Num: %d, Sign: %d, Gantry: %d)\n', ...
    config.Ax1Name, config.Ax1Num, config.Ax1Sign, config.Ax1Gantry);
fprintf('Axis 2: %s (Num: %d, Sign: %d, Gantry: %d)\n', ...
    config.Ax2Name, config.Ax2Num, config.Ax2Sign, config.Ax2Gantry);
fprintf('Units: %s (Divisor: %d)\n', config.UserUnit, config.calDivisor);
fprintf('Position Unit: %s, Error Unit: %s\n', config.posUnit, config.errUnit);
if ~isempty(config.operator)
    fprintf('Operator: %s, Model: %s\n', config.operator, config.model);
end
fprintf('File Date: %s\n', config.fileDate);
fprintf('=============================\n\n');

end
