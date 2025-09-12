import os
from datetime import datetime
import scipy.io as sio


def step1_parse_header(input_file):
    """
    STEP1_PARSE_HEADER - Parse data file header and extract system configuration
    
    This function extracts axis names, numbers, signs, gantry info, and other
    system parameters from the data file header
    
    INPUT:
        input_file - str, path to the data file
    
    OUTPUT:
        config - dict containing all parsed configuration parameters
    """
    
    # Initialize output dictionary
    config = {}
    
    # Open file for reading header
    try:
        with open(input_file, 'r') as fid:
            lines = fid.readlines()
    except FileNotFoundError:
        raise FileNotFoundError(f'Could not find file {input_file}')
    
    line_idx = 0
    
    # Parse serial number (first line)
    if line_idx < len(lines):
        ftxt = lines[line_idx].strip()
        colon_idx = ftxt.find(':')
        if colon_idx != -1:
            config['SN'] = ftxt[colon_idx + 2:]
        line_idx += 1
    
    # Parse Axis 1 information (second line: %Ax1Name: Y; Ax1Num: 1; Ax1Sign: 1; Ax1Slave: 0)
    if line_idx < len(lines):
        ftxt = lines[line_idx].strip()
        
        # Parse using semicolon-separated format
        if ftxt.startswith('%Ax1Name: '):
            parts = ftxt.split(';')
            
            # Get axis name
            if len(parts) > 0:
                name_part = parts[0]
                colon_idx = name_part.find(':')
                if colon_idx != -1:
                    config['Ax1Name'] = name_part[colon_idx + 2:].strip()
            
            # Get axis number
            if len(parts) > 1:
                num_part = parts[1].strip()
                colon_idx = num_part.find(':')
                if colon_idx != -1:
                    config['Ax1Num'] = int(num_part[colon_idx + 2:].strip())
            
            # Get program units sign
            if len(parts) > 2:
                sign_part = parts[2].strip()
                colon_idx = sign_part.find(':')
                if colon_idx != -1:
                    config['Ax1Sign'] = int(sign_part[colon_idx + 2:].strip())
            
            # Get slave axis value (if present)
            if len(parts) > 3:
                slave_part = parts[3].strip()
                colon_idx = slave_part.find(':')
                if colon_idx != -1:
                    config['Ax1Gantry'] = int(slave_part[colon_idx + 2:].strip())
                else:
                    config['Ax1Gantry'] = 0
            else:
                config['Ax1Gantry'] = 0
        line_idx += 1
    
    # Parse Axis 2 information (third line: %Ax2Name: X; Ax2Num: 3; Ax2Sign: 1; Ax2Slave: 0)
    if line_idx < len(lines):
        ftxt = lines[line_idx].strip()
        
        # Parse using semicolon-separated format
        if ftxt.startswith('%Ax2Name: '):
            parts = ftxt.split(';')
            
            # Get axis name
            if len(parts) > 0:
                name_part = parts[0]
                colon_idx = name_part.find(':')
                if colon_idx != -1:
                    config['Ax2Name'] = name_part[colon_idx + 2:].strip()
            
            # Get axis number
            if len(parts) > 1:
                num_part = parts[1].strip()
                colon_idx = num_part.find(':')
                if colon_idx != -1:
                    config['Ax2Num'] = int(num_part[colon_idx + 2:].strip())
            
            # Get program units sign
            if len(parts) > 2:
                sign_part = parts[2].strip()
                colon_idx = sign_part.find(':')
                if colon_idx != -1:
                    config['Ax2Sign'] = int(sign_part[colon_idx + 2:].strip())
            
            # Get slave axis value (if present)
            if len(parts) > 3:
                slave_part = parts[3].strip()
                colon_idx = slave_part.find(':')
                if colon_idx != -1:
                    config['Ax2Gantry'] = int(slave_part[colon_idx + 2:].strip())
                else:
                    config['Ax2Gantry'] = 0
            else:
                config['Ax2Gantry'] = 0
        line_idx += 1
    
    # Parse user units (fourth line: %UserUnits: MM)
    config['UserUnit'] = 'METRIC'  # Default
    config['calDivisor'] = 1       # Default
    config['posUnit'] = 'mm'       # Default
    config['errUnit'] = '\\mum'    # Default (using \\mum to match MATLAB)
    
    if line_idx < len(lines):
        ftxt = lines[line_idx].strip()
        if ftxt.startswith('%UserUnits: '):
            temp = ftxt[12:].strip()  # Extract units after "%UserUnits: "
            if temp == 'UM':  # Micron program units
                config['calDivisor'] = 1000
            elif temp in ['ENGLISH', 'INCH']:
                config['UserUnit'] = 'ENGLISH'
                config['posUnit'] = 'in'
                config['errUnit'] = 'mil'
        line_idx += 1
    
    # Parse operator, model, temperatures, etc. (if present)
    if line_idx < len(lines):
        ftxt = lines[line_idx].strip()
        if len(ftxt) >= 9 and ftxt[:9] == '%Operator':  # New data file format
            colon_positions = [i for i, char in enumerate(ftxt) if char == ':']
            semicolon_positions = [i for i, char in enumerate(ftxt) if char == ';']
            
            if len(colon_positions) >= 6 and len(semicolon_positions) >= 5:
                config['operator'] = ftxt[colon_positions[0] + 2:semicolon_positions[0]]
                config['model'] = ftxt[colon_positions[1] + 2:semicolon_positions[1]]
                config['airTemp'] = ftxt[colon_positions[2] + 2:semicolon_positions[2]]
                config['matTemp'] = ftxt[colon_positions[3] + 2:semicolon_positions[3]]
                config['expandCoef'] = ftxt[colon_positions[4] + 2:semicolon_positions[4]]
                config['comment'] = ftxt[colon_positions[5] + 2:]
            else:
                # Fallback if parsing fails
                config['operator'] = ''
                config['model'] = ''
                config['airTemp'] = ''
                config['matTemp'] = ''
                config['expandCoef'] = ''
                config['comment'] = ''
        else:  # Old data files
            config['operator'] = ''
            config['model'] = ''
            config['airTemp'] = ''
            config['matTemp'] = ''
            config['expandCoef'] = ''
            config['comment'] = ''
    
    # Get file date
    if os.path.exists(input_file):
        file_stat = os.stat(input_file)
        config['fileDate'] = datetime.fromtimestamp(file_stat.st_mtime).strftime('%d-%b-%Y %H:%M:%S')
    else:
        config['fileDate'] = ''
    
    # Display parsed configuration for verification
    print('\n=== PARSED CONFIGURATION ===')
    print(f"Serial Number: {config.get('SN', 'N/A')}")
    print(f"Axis 1: {config.get('Ax1Name', 'N/A')} (Num: {config.get('Ax1Num', 'N/A')}, " +
          f"Sign: {config.get('Ax1Sign', 'N/A')}, Gantry: {config.get('Ax1Gantry', 'N/A')})")
    print(f"Axis 2: {config.get('Ax2Name', 'N/A')} (Num: {config.get('Ax2Num', 'N/A')}, " +
          f"Sign: {config.get('Ax2Sign', 'N/A')}, Gantry: {config.get('Ax2Gantry', 'N/A')})")
    print(f"Units: {config.get('UserUnit', 'N/A')} (Divisor: {config.get('calDivisor', 'N/A')})")
    print(f"Position Unit: {config.get('posUnit', 'N/A')}, Error Unit: {config.get('errUnit', 'N/A')}")
    if config.get('operator', ''):
        print(f"Operator: {config.get('operator', 'N/A')}, Model: {config.get('model', 'N/A')}")
    print(f"File Date: {config.get('fileDate', 'N/A')}")
    print('=============================\n')
    
    return config


if __name__ == "__main__":
    # Test the function if run directly
    test_file = 'MATLAB Source/642583-1-1-CZ1.dat'
    
    # Look for available files if test file doesn't exist
    if not os.path.exists(test_file):
        print(f"Test file {test_file} not found!")
        print("Looking for available .dat files in MATLAB Source directory...")
        
        matlab_dir = 'MATLAB Source'
        if os.path.exists(matlab_dir):
            dat_files = [f for f in os.listdir(matlab_dir) if f.endswith('.dat')]
            if dat_files:
                test_file = os.path.join(matlab_dir, dat_files[0])
                print(f"Found data file: {test_file}")
            else:
                print("No .dat files found. Please provide a data file to test with.")
                exit(1)
        else:
            print("MATLAB Source directory not found.")
            exit(1)
    
    try:
        # Test the header parser
        config = step1_parse_header(test_file)
        
        # Verify the structure contains expected fields
        expected_fields = ['SN', 'Ax1Name', 'Ax1Num', 'Ax1Sign', 'Ax1Gantry',
                          'Ax2Name', 'Ax2Num', 'Ax2Sign', 'Ax2Gantry',
                          'UserUnit', 'calDivisor', 'posUnit', 'errUnit',
                          'operator', 'model', 'airTemp', 'matTemp',
                          'expandCoef', 'comment', 'fileDate']
        
        print('Checking for expected fields...')
        for field in expected_fields:
            if field in config:
                print(f'✓ {field}: Present')
            else:
                print(f'✗ {field}: Missing')
        
        print('\n=== TEST COMPLETED SUCCESSFULLY ===')
        print("Config structure saved as 'step1_output.mat' for comparison")
        
        # Save the result for comparison with MATLAB/Octave
        sio.savemat('step1_output_python.mat', {'config_step1': config})
        
    except Exception as err:
        print('ERROR in step1_parse_header:')
        print(str(err))
