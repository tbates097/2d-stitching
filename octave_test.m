% Simple test script to verify Octave compatibility
fprintf('=== OCTAVE TEST ===\n');
fprintf('Octave version: %s\n', version);

% Test basic file operations
test_file = 'MATLAB Source/642583-1-1-CZ1.dat';
fprintf('Testing file access: %s\n', test_file);

if exist(test_file, 'file')
    fprintf('File exists: YES\n');
    
    % Try to read first few lines
    fid = fopen(test_file, 'r');
    if fid ~= -1
        fprintf('File opened successfully\n');
        for i = 1:5
            line = fgetl(fid);
            if ischar(line)
                fprintf('Line %d: %s\n', i, line);
            else
                break;
            end
        end
        fclose(fid);
    else
        fprintf('ERROR: Could not open file\n');
    end
else
    fprintf('File exists: NO\n');
    fprintf('Current directory: %s\n', pwd);
    fprintf('Directory contents:\n');
    dir
end

fprintf('Test completed\n');