% Convert debug files to Python-readable format
% This script loads the debug .mat files and re-saves them in v7 format
% which can be read by Python's scipy.io.loadmat

clear all;

% List of files to convert
files_to_convert = {
    'matlab_multizone_debug.mat',
    '642583-1-1-CZ1_zone_debug.mat',
    '642583-1-1-CZ2_zone_debug.mat',
    '642583-1-1-CZ3_zone_debug.mat',
    '642583-1-1-CZ4_zone_debug.mat'
};

fprintf('Converting debug files to Python-compatible format...\n');

for i = 1:length(files_to_convert)
    input_file = files_to_convert{i};
    
    if exist(input_file, 'file')
        fprintf('Converting %s...\n', input_file);
        
        % Load the file
        try
            data = load(input_file);
            
            % Create output filename
            [filepath, name, ext] = fileparts(input_file);
            output_file = fullfile(filepath, [name '_v7' ext]);
            
            % Get all variable names from the loaded data
            var_names = fieldnames(data);
            
            % Save in v7 format (compatible with Python)
            if length(var_names) > 0
                save(output_file, '-struct', 'data', '-v7');
                fprintf('  -> Saved as %s\n', output_file);
            else
                fprintf('  -> Warning: No data found in %s\n', input_file);
            end
            
        catch ME
            fprintf('  -> Error loading %s: %s\n', input_file, ME.message);
        end
    else
        fprintf('File not found: %s\n', input_file);
    end
end

fprintf('Conversion complete!\n');