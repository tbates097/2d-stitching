function data = A3200Acc2DMultiZone_Octave(fName)
% This file contains the core processing logic.
% The function name now matches the filename for Octave compatibility.

y_meas_dir = -1;

% --- Section 1.0: Read Header ---
fid = fopen(fName);
if fid == -1, error('Could not find file %s!!!!', fName); end

header_lines = {};
while ~feof(fid)
    line = fgetl(fid);
    % Stop reading if the line is empty or does not start with '%'
    if isempty(strtrim(line)) || line(1) ~= '%', break; end
    header_lines{end+1} = line;
end
fclose(fid);

UserUnit = 'MM'; % Default
for i = 1:length(header_lines)
    % Replaced 'contains' with 'strfind' for Octave compatibility
    if ~isempty(strfind(header_lines{i}, 'UserUnits'))
        parts = strsplit(header_lines{i}, ':');
        if length(parts) > 1
            UserUnit = strtrim(parts{2});
        end
    end
end

calDivisor = 1;
if strcmp(UserUnit, 'UM'), calDivisor = 1000; end

% --- SECTION 2. LOAD TEST DATA ---
s = load(fName);
s = sortrows(s,[2 1]);

Ax1TestLoc = s(:,1);
Ax2TestLoc = s(:,2);
Ax1PosCmd = s(:,3) / calDivisor;
Ax2PosCmd = s(:,4) / calDivisor;
Ax1RelErr = s(:,5) / calDivisor;
Ax2RelErr = s(:,6) / calDivisor;

% --- SECTION 3. CALCULATE RELATIVE ERROR ---
Ax1RelErr = (Ax1RelErr - mean(Ax1RelErr)) * 1000;
Ax2RelErr = (Ax2RelErr - mean(Ax2RelErr)) * 1000;

% --- SECTION 4. CREATE 2D POSITION AND ERROR TABLES ---
NumAx1Points = max(s(:,1));
Ax1Pos = Ax1PosCmd(1:NumAx1Points);
Ax2Pos = Ax2PosCmd(1:(NumAx1Points):(NumAx1Points*max(s(:,2))));
[X,Y] = meshgrid(Ax1Pos, Ax2Pos);

Ax1Err = griddata(Ax1PosCmd, Ax2PosCmd, Ax1RelErr, X, Y, 'linear');
Ax2Err = griddata(Ax1PosCmd, Ax2PosCmd, Ax2RelErr, X, Y, 'linear');

% --- SECTION 5. REMOVE MIRROR SLOPE ---
valid_rows = all(!isnan(Ax1Err), 2);
Ax1Coef = polyfit(Y(valid_rows,1), mean(Ax1Err(valid_rows,:),2), 1);

valid_cols = all(!isnan(Ax2Err), 1);
Ax2Coef = polyfit(X(1,valid_cols), mean(Ax2Err(:,valid_cols)), 1);

Ax1Line = polyval(Ax1Coef, Y(:,1));
Ax2Line = polyval([y_meas_dir * Ax1Coef(1), y_meas_dir * Ax1Coef(2)], X(1,:));

for i = 1:size(X,2), Ax1Err(:,i) = Ax1Err(:,i) - Ax1Line; end
for i = 1:size(Y,1), Ax2Err(i,:) = Ax2Err(i,:) - Ax2Line; end

% This function returns the data BEFORE the origin-zeroing step.
data.Ax1Err = Ax1Err;
data.Ax2Err = Ax2Err;
data.X = X;
data.Y = Y;

end
