% This script runs the single-zone analysis for debugging in Octave.

clear all;
close all;

% --- Main script execution ---
% Prompt for the input file and remove quotes if they exist
InputFile = input('Enter the path to the data file (.dat): ', 's');
InputFile = strrep(InputFile, '"', ''); % Strip quotes from path

% Call the processing function from the separate .m file
data_out = A3200Acc2DMultiZone_Octave(InputFile);

% --- SAVE DEBUG FILE ---
debug_filename = 'Octave_Debug_FinalError.txt';
disp(['Saving debug data to ' debug_filename]);
fid = fopen(debug_filename, 'w');
fprintf(fid, '# X_pos, Y_pos, Ax1_Err_Final, Ax2_Err_Final\n');
for i = 1:size(data_out.X, 1)
for j = 1:size(data_out.X, 2)
fprintf(fid, '%.4f, %.4f, %.8f, %.8f\n', data_out.X(i,j), data_out.Y(i,j), data_out.Ax1Err(i,j), data_out.Ax2Err(i,j));
end
end
fclose(fid);
disp('Debug file saved. Please compare with Python output.');
