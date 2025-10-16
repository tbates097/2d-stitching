#!/usr/bin/env python3
import os
import sys
import argparse
from datetime import datetime
from copy import deepcopy

import numpy as np
try:
    import matplotlib.pyplot as plt
    HAS_MPL = True
except Exception:
    HAS_MPL = False

import scipy.io as sio
from scipy.interpolate import griddata


# -----------------------------
# Single-zone pipeline helpers
# -----------------------------

def step1_parse_header(input_file):
    """
    Parse data file header and extract system configuration.
    Preserves logic from step1_parse_header.py
    """
    config = {}
    try:
        with open(input_file, 'r') as fid:
            lines = fid.readlines()
    except FileNotFoundError:
        raise FileNotFoundError(f'Could not find file {input_file}')

    line_idx = 0

    # Serial number (first line)
    if line_idx < len(lines):
        ftxt = lines[line_idx].strip()
        colon_idx = ftxt.find(':')
        if colon_idx != -1:
            config['SN'] = ftxt[colon_idx + 2:]
        line_idx += 1

    # Axis 1 line
    if line_idx < len(lines):
        ftxt = lines[line_idx].strip()
        if ftxt.startswith('%Ax1Name: '):
            parts = ftxt.split(';')
            if len(parts) > 0:
                name_part = parts[0]
                colon_idx = name_part.find(':')
                if colon_idx != -1:
                    config['Ax1Name'] = name_part[colon_idx + 2:].strip()
            if len(parts) > 1:
                num_part = parts[1].strip()
                colon_idx = num_part.find(':')
                if colon_idx != -1:
                    config['Ax1Num'] = int(num_part[colon_idx + 2:].strip())
            if len(parts) > 2:
                sign_part = parts[2].strip()
                colon_idx = sign_part.find(':')
                if colon_idx != -1:
                    config['Ax1Sign'] = int(sign_part[colon_idx + 2:].strip())
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

    # Axis 2 line
    if line_idx < len(lines):
        ftxt = lines[line_idx].strip()
        if ftxt.startswith('%Ax2Name: '):
            parts = ftxt.split(';')
            if len(parts) > 0:
                name_part = parts[0]
                colon_idx = name_part.find(':')
                if colon_idx != -1:
                    config['Ax2Name'] = name_part[colon_idx + 2:].strip()
            if len(parts) > 1:
                num_part = parts[1].strip()
                colon_idx = num_part.find(':')
                if colon_idx != -1:
                    config['Ax2Num'] = int(num_part[colon_idx + 2:].strip())
            if len(parts) > 2:
                sign_part = parts[2].strip()
                colon_idx = sign_part.find(':')
                if colon_idx != -1:
                    config['Ax2Sign'] = int(sign_part[colon_idx + 2:].strip())
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

    # User units defaults
    config['UserUnit'] = 'METRIC'
    config['calDivisor'] = 1
    config['posUnit'] = 'mm'
    config['errUnit'] = '\\mum'

    if line_idx < len(lines):
        ftxt = lines[line_idx].strip()
        if ftxt.startswith('%UserUnits: '):
            temp = ftxt[12:].strip()
            if temp == 'UM':
                config['calDivisor'] = 1000
            elif temp in ['ENGLISH', 'INCH']:
                config['UserUnit'] = 'ENGLISH'
                config['posUnit'] = 'in'
                config['errUnit'] = 'mil'
        line_idx += 1

    # Operator/model/temps/comment (new format)
    if line_idx < len(lines):
        ftxt = lines[line_idx].strip()
        if len(ftxt) >= 9 and ftxt[:9] == '%Operator':
            colon_positions = [i for i, ch in enumerate(ftxt) if ch == ':']
            semicolon_positions = [i for i, ch in enumerate(ftxt) if ch == ';']
            if len(colon_positions) >= 6 and len(semicolon_positions) >= 5:
                config['operator'] = ftxt[colon_positions[0] + 2:semicolon_positions[0]]
                config['model'] = ftxt[colon_positions[1] + 2:semicolon_positions[1]]
                config['airTemp'] = ftxt[colon_positions[2] + 2:semicolon_positions[2]]
                config['matTemp'] = ftxt[colon_positions[3] + 2:semicolon_positions[3]]
                config['expandCoef'] = ftxt[colon_positions[4] + 2:semicolon_positions[4]]
                config['comment'] = ftxt[colon_positions[5] + 2:]
            else:
                config['operator'] = ''
                config['model'] = ''
                config['airTemp'] = ''
                config['matTemp'] = ''
                config['expandCoef'] = ''
                config['comment'] = ''
        else:
            config['operator'] = ''
            config['model'] = ''
            config['airTemp'] = ''
            config['matTemp'] = ''
            config['expandCoef'] = ''
            config['comment'] = ''

    # File date
    if os.path.exists(input_file):
        file_stat = os.stat(input_file)
        config['fileDate'] = datetime.fromtimestamp(file_stat.st_mtime).strftime('%d-%b-%Y %H:%M:%S')
    else:
        config['fileDate'] = ''

    return config


def step2_load_data(input_file, config):
    """
    Load and sort raw measurement data from file.
    Preserves logic from step2_load_data.py
    """
    data_raw = {}
    with open(input_file, 'r') as f:
        lines = f.readlines()

    data_start = 0
    for i, line in enumerate(lines):
        line = line.strip()
        if line and not line.startswith('%') and not line.startswith('#'):
            try:
                float(line.split()[0])
                data_start = i
                break
            except (ValueError, IndexError):
                continue

    s = np.loadtxt(input_file, skiprows=data_start)

    sort_indices = np.lexsort((s[:, 0], s[:, 1]))
    s = s[sort_indices]

    data_raw['Ax1TestLoc'] = s[:, 0].astype(int)
    data_raw['Ax2TestLoc'] = s[:, 1].astype(int)
    data_raw['Ax1PosCmd'] = s[:, 2] / config['calDivisor']
    data_raw['Ax2PosCmd'] = s[:, 3] / config['calDivisor']
    data_raw['Ax1RelErr'] = s[:, 4] / config['calDivisor']
    data_raw['Ax2RelErr'] = s[:, 5] / config['calDivisor']

    data_raw['Ax1RelErr_um'] = (data_raw['Ax1RelErr'] - np.mean(data_raw['Ax1RelErr'])) * 1000
    data_raw['Ax2RelErr_um'] = (data_raw['Ax2RelErr'] - np.mean(data_raw['Ax2RelErr'])) * 1000

    data_raw['NumAx1Points'] = int(np.max(data_raw['Ax1TestLoc']))
    data_raw['NumAx2Points'] = int(np.max(data_raw['Ax2TestLoc']))
    data_raw['Ax1MoveDist'] = np.max(data_raw['Ax1PosCmd']) - np.min(data_raw['Ax1PosCmd'])
    data_raw['Ax2MoveDist'] = np.max(data_raw['Ax2PosCmd']) - np.min(data_raw['Ax2PosCmd'])

    if data_raw['NumAx1Points'] > 1:
        data_raw['Ax1SampDist'] = data_raw['Ax1PosCmd'][1] - data_raw['Ax1PosCmd'][0]
    else:
        data_raw['Ax1SampDist'] = 0.0

    if data_raw['NumAx2Points'] > 1:
        data_raw['Ax2SampDist'] = data_raw['Ax2PosCmd'][data_raw['NumAx1Points']] - data_raw['Ax2PosCmd'][0]
    else:
        data_raw['Ax2SampDist'] = 0.0

    data_raw['Ax1Pos'] = data_raw['Ax1PosCmd'][:data_raw['NumAx1Points']]
    data_raw['Ax2Pos'] = data_raw['Ax2PosCmd'][::data_raw['NumAx1Points']][:data_raw['NumAx2Points']]

    return data_raw


def step3_create_grid(data_raw):
    """
    Create 2D position and error matrices using direct grid reconstruction.
    Since measurement data is already on a complete rectangular grid,
    we can use direct reshape operations instead of interpolation.
    This eliminates interpolation artifacts and matches MATLAB behavior.
    """
    grid_data = {}
    
    # Create position meshgrids (same as before)
    X, Y = np.meshgrid(data_raw['Ax1Pos'], data_raw['Ax2Pos'])
    grid_data['X'] = X
    grid_data['Y'] = Y
    grid_data['SizeGrid'] = X.shape
    
    # Get grid dimensions
    num_ax1_points = len(data_raw['Ax1Pos'])
    num_ax2_points = len(data_raw['Ax2Pos'])
    
    # Verify that data is on a complete rectangular grid
    expected_points = num_ax1_points * num_ax2_points
    actual_points = len(data_raw['Ax1RelErr_um'])
    
    if actual_points != expected_points:
        print(f"Warning: Expected {expected_points} points but got {actual_points}. Using interpolation fallback.")
        # Fallback to original interpolation method
        maxAx1 = np.max(data_raw['Ax1PosCmd']) - np.min(data_raw['Ax1PosCmd'])
        maxAx2 = np.max(data_raw['Ax2PosCmd']) - np.min(data_raw['Ax2PosCmd'])
        if maxAx1 == 0:
            maxAx1 = 1.0
        if maxAx2 == 0:
            maxAx2 = 1.0
        
        points = np.column_stack((data_raw['Ax1PosCmd'] / maxAx1, data_raw['Ax2PosCmd'] / maxAx2))
        xi = np.column_stack((X.flatten() / maxAx1, Y.flatten() / maxAx2))
        
        ax1_err_flat = griddata(points, data_raw['Ax1RelErr_um'], xi, method='linear')
        grid_data['Ax1Err'] = ax1_err_flat.reshape(X.shape)
        
        ax2_err_flat = griddata(points, data_raw['Ax2RelErr_um'], xi, method='linear')
        grid_data['Ax2Err'] = ax2_err_flat.reshape(X.shape)
        
        grid_data['maxAx1'] = maxAx1
        grid_data['maxAx2'] = maxAx2
    else:
        # Direct grid reconstruction - data is already gridded!
        print(f"Data is on complete {num_ax1_points}x{num_ax2_points} grid. Using direct reshape (no interpolation).")
        
        # Reshape error data directly to match the grid structure  
        # Data scans Ax1 (36 points) for each Ax2 value (36 rows)
        # So reshape to (num_ax2_points, num_ax1_points) = (36 rows, 36 cols)
        grid_data['Ax1Err'] = data_raw['Ax1RelErr_um'].reshape(num_ax2_points, num_ax1_points)
        grid_data['Ax2Err'] = data_raw['Ax2RelErr_um'].reshape(num_ax2_points, num_ax1_points)
        
        # Store normalization factors for compatibility (though not used for direct reshape)
        maxAx1 = np.max(data_raw['Ax1PosCmd']) - np.min(data_raw['Ax1PosCmd'])
        maxAx2 = np.max(data_raw['Ax2PosCmd']) - np.min(data_raw['Ax2PosCmd'])
        if maxAx1 == 0:
            maxAx1 = 1.0
        if maxAx2 == 0:
            maxAx2 = 1.0
        grid_data['maxAx1'] = maxAx1
        grid_data['maxAx2'] = maxAx2
    
    return grid_data


def step4_calculate_slopes(grid_data):
    """
    Calculate straightness slopes and orthogonality.
    Preserves logic from step4_calculate_slopes.py
    """
    slope_data = {}
    y_meas_dir = -1

    mean_ax1_err = np.mean(grid_data['Ax1Err'], axis=1)
    mean_ax2_err = np.mean(grid_data['Ax2Err'], axis=0)

    slope_data['Ax1Coef'] = np.polyfit(grid_data['Y'][:, 0], mean_ax1_err, 1)
    slope_data['Ax2Coef'] = np.polyfit(grid_data['X'][0, :], mean_ax2_err, 1)

    slope_data['Ax1Line'] = np.polyval(slope_data['Ax1Coef'], grid_data['Y'][:, 0])
    slope_data['Ax2Line'] = np.polyval(y_meas_dir * slope_data['Ax1Coef'], grid_data['X'][0, :])

    slope_data['Ax1Orthog'] = mean_ax1_err - slope_data['Ax1Line']
    slope_data['Ax2Orthog'] = mean_ax2_err - np.polyval(slope_data['Ax2Coef'], grid_data['X'][0, :])

    orthog_slope = slope_data['Ax1Coef'][0] - y_meas_dir * slope_data['Ax2Coef'][0]
    slope_data['orthog'] = np.arctan(orthog_slope / 1000) * 180 / np.pi * 3600

    slope_data['y_meas_dir'] = y_meas_dir
    slope_data['mean_ax1_err'] = mean_ax1_err
    slope_data['mean_ax2_err'] = mean_ax2_err

    return slope_data


def step5_process_errors(grid_data, slope_data):
    """
    Remove slopes and calculate vector sum accuracy error.
    Preserves logic from step5_process_errors.py
    """
    processed_data = {}
    processed_data['X'] = grid_data['X'].copy()
    processed_data['Y'] = grid_data['Y'].copy()
    processed_data['SizeGrid'] = grid_data['SizeGrid']

    processed_data['Ax1Err'] = grid_data['Ax1Err'].copy()
    processed_data['Ax2Err'] = grid_data['Ax2Err'].copy()

    for i in range(processed_data['SizeGrid'][1]):
        processed_data['Ax1Err'][:, i] = processed_data['Ax1Err'][:, i] - slope_data['Ax1Line']
    for i in range(processed_data['SizeGrid'][0]):
        processed_data['Ax2Err'][i, :] = processed_data['Ax2Err'][i, :] - slope_data['Ax2Line']

    processed_data['Ax1Err'] = processed_data['Ax1Err'] - processed_data['Ax1Err'][0, 0]
    processed_data['Ax2Err'] = processed_data['Ax2Err'] - processed_data['Ax2Err'][0, 0]

    processed_data['VectorErr'] = np.sqrt(processed_data['Ax1Err']**2 + processed_data['Ax2Err']**2)

    processed_data['pkAx1'] = np.max(processed_data['Ax1Err']) - np.min(processed_data['Ax1Err'])
    processed_data['pkAx2'] = np.max(processed_data['Ax2Err']) - np.min(processed_data['Ax2Err'])
    processed_data['maxVectorErr'] = np.max(processed_data['VectorErr'])

    processed_data['rmsAx1'] = np.std(processed_data['Ax1Err'], ddof=1)
    processed_data['rmsAx2'] = np.std(processed_data['Ax2Err'], ddof=1)
    processed_data['rmsVector'] = np.std(processed_data['VectorErr'], ddof=1)

    processed_data['Ax1amplitude'] = processed_data['pkAx1'] / 2
    processed_data['Ax2amplitude'] = processed_data['pkAx2'] / 2

    processed_data['slope_data'] = slope_data.copy()

    return processed_data

def step5_process_errors_multizone(grid_data, slope_data):
    """Process errors for multizone stitching - preserves absolute reference.
    
    This variant of step5 does NOT apply zero-referencing to preserve
    the absolute error references that multizone stitching depends on.
    Zero-referencing is applied later after all stitching is complete.
    """
    processed_data = deepcopy(grid_data)
    
    # Add slope calculation results
    processed_data.update(slope_data)
    
    # Remove best-fit lines (slope errors) from error data
    for i in range(processed_data['SizeGrid'][1]):
        processed_data['Ax1Err'][:, i] = processed_data['Ax1Err'][:, i] - slope_data['Ax1Line']
    for i in range(processed_data['SizeGrid'][0]):
        processed_data['Ax2Err'][i, :] = processed_data['Ax2Err'][i, :] - slope_data['Ax2Line']

    # DO NOT apply zero-referencing here for multizone stitching
    # This will be applied later after stitching is complete
    
    processed_data['VectorErr'] = np.sqrt(processed_data['Ax1Err']**2 + processed_data['Ax2Err']**2)

    processed_data['pkAx1'] = np.max(processed_data['Ax1Err']) - np.min(processed_data['Ax1Err'])
    processed_data['pkAx2'] = np.max(processed_data['Ax2Err']) - np.min(processed_data['Ax2Err'])
    processed_data['maxVectorErr'] = np.max(processed_data['VectorErr'])

    processed_data['rmsAx1'] = np.std(processed_data['Ax1Err'], ddof=1)
    processed_data['rmsAx2'] = np.std(processed_data['Ax2Err'], ddof=1)
    processed_data['rmsVector'] = np.std(processed_data['VectorErr'], ddof=1)

    processed_data['Ax1amplitude'] = processed_data['pkAx1'] / 2
    processed_data['Ax2amplitude'] = processed_data['pkAx2'] / 2

    processed_data['slope_data'] = slope_data.copy()

    return processed_data


# -------------------------------------
# Multizone stitching helpers (ported)
# -------------------------------------

def apply_stitching_corrections(master, slave, stitch_type, y_meas_dir, diag=False, dump_dir=None):
    """Apply stitching corrections to align a slave zone with the master zone (MATLAB-compatible)."""
    slave_corrected = deepcopy(slave)

    if stitch_type == 'column':
        # EXACT MATLAB overlap detection algorithm (from MultiZone2DCal.m lines 182-190)
        master_x = master['X'][0, :]
        slave_x = slave['X'][0, :]
        
        # MATLAB: Find how many slave columns have X < max(master X)
        max_master_x = np.max(master['X'])
        k = 0
        for col_idx in range(slave_x.shape[0]):
            if slave_x[col_idx] < max_master_x:
                k += 1
            else:
                break
        
        if k == 0:
            print('    Warning: No overlap found for column stitching')
            return slave_corrected
        
        # MATLAB: mRange = ((Ax1size(2)-k+1): Ax1size(2))
        #         sRange = (1:k)
        # Convert to Python 0-based indexing:
        master_size = master_x.shape[0] 
        m_range = np.arange(master_size - k, master_size)  # Right k columns of master
        s_range = np.arange(k)  # Left k columns of slave
        
        if len(m_range) == 0 or len(s_range) == 0:
            print('    Warning: Empty overlap ranges')
            return slave_corrected
            
        print(f'    Overlap: Master cols {m_range[0]}-{m_range[-1]}, Slave cols {s_range[0]}-{s_range[-1]} (k={k})')

        # Mean Ax1 error across overlap columns (vector vs Y)
        master_ax1_mean = np.mean(master['Ax1Err'][:, m_range], axis=1)
        slave_ax1_mean = np.mean(slave['Ax1Err'][:, s_range], axis=1)

        # Fit Ax1 straightness vs Y
        master_coef_ax1 = np.polyfit(master['Y'][:, 0], master_ax1_mean, 1)
        slave_coef_ax1 = np.polyfit(slave['Y'][:, 0], slave_ax1_mean, 1)
        print(f'    Ax1 slope correction: Master={master_coef_ax1[0]:.6f}, Slave={slave_coef_ax1[0]:.6f} um/mm')
        if diag:
            # Detailed diagnostics: overlap size and means
            pre_ax1_master_mean = float(np.mean(master['Ax1Err'][:, m_range]))
            pre_ax1_slave_mean = float(np.mean(slave['Ax1Err'][:, s_range]))
            pre_ax2_master_mean = float(np.mean(master['Ax2Err'][:, m_range]))
            pre_ax2_slave_mean = float(np.mean(slave['Ax2Err'][:, s_range]))
            print(f'      Overlap size (cols): {len(m_range)}')
            print(f'      Pre-correction overlap means:')
            print(f'        Ax1 master={pre_ax1_master_mean:.6f}, slave={pre_ax1_slave_mean:.6f} (diff={pre_ax1_master_mean-pre_ax1_slave_mean:.6f})')
            print(f'        Ax2 master={pre_ax2_master_mean:.6f}, slave={pre_ax2_slave_mean:.6f} (diff={pre_ax2_master_mean-pre_ax2_slave_mean:.6f})')
            print(f'      Ax1 polyfit (slope, intercept): master=({master_coef_ax1[0]:.6f}, {master_coef_ax1[1]:.6f}), '
                  f'slave=({slave_coef_ax1[0]:.6f}, {slave_coef_ax1[1]:.6f})')

        # Apply Ax1 slope corrections across all columns of slave
        y_vec_slave = slave['Y'][:, 0]
        for n in range(slave['X'].shape[1]):
            slave_corrected['Ax1Err'][:, n] = (
                slave_corrected['Ax1Err'][:, n]
                - np.polyval(slave_coef_ax1, y_vec_slave)
                + np.polyval(master_coef_ax1, y_vec_slave)
            )

        # Apply Ax2 orthogonality correction (coupled to Ax1 slope)
        master_coef_ax2_orth = y_meas_dir * master_coef_ax1
        slave_coef_ax2_orth = y_meas_dir * slave_coef_ax1
        for n in range(slave['Y'].shape[0]):
            slave_corrected['Ax2Err'][n, :] = (
                slave_corrected['Ax2Err'][n, :]
                - np.polyval(slave_coef_ax2_orth, slave['X'][n, :])
                + np.polyval(master_coef_ax2_orth, slave['X'][n, :])
            )

        # Scalar offset corrections across overlap columns
        ax1_correction = np.mean(master['Ax1Err'][:, m_range]) - np.mean(slave_corrected['Ax1Err'][:, s_range])
        ax2_correction = np.mean(master['Ax2Err'][:, m_range]) - np.mean(slave_corrected['Ax2Err'][:, s_range])
        if diag:
            print(f'      Offsets to apply (pre-apply): Ax1={ax1_correction:.6f}, Ax2={ax2_correction:.6f}')
        slave_corrected['Ax1Err'] += ax1_correction
        slave_corrected['Ax2Err'] += ax2_correction
        if diag:
            post_ax1_master_mean = float(np.mean(master['Ax1Err'][:, m_range]))
            post_ax1_slave_mean = float(np.mean(slave_corrected['Ax1Err'][:, s_range]))
            post_ax2_master_mean = float(np.mean(master['Ax2Err'][:, m_range]))
            post_ax2_slave_mean = float(np.mean(slave_corrected['Ax2Err'][:, s_range]))
            print(f'      Post-apply overlap means:')
            print(f'        Ax1 master={post_ax1_master_mean:.6f}, slave={post_ax1_slave_mean:.6f} (diff={post_ax1_master_mean-post_ax1_slave_mean:.6f})')
            print(f'        Ax2 master={post_ax2_master_mean:.6f}, slave={post_ax2_slave_mean:.6f} (diff={post_ax2_master_mean-post_ax2_slave_mean:.6f})')
        print(f'    Offset corrections: Ax1={ax1_correction:.3f}, Ax2={ax2_correction:.3f} um')

    else:  # row stitching
        # MATLAB-compatible overlap detection for row stitching
        master_y = master['Y'][:, 0]
        slave_y = slave['Y'][:, 0]
        
        # MATLAB algorithm: master_overlap_idx = find(master.Y(:,1) >= min(min(slave.Y)))
        #                   slave_overlap_idx = find(slave.Y(:,1) <= max(max(master.Y)))
        min_slave_y = np.min(slave['Y'])
        max_master_y = np.max(master['Y'])
        
        master_overlap_idx = np.where(master_y >= min_slave_y)[0]
        slave_overlap_idx = np.where(slave_y <= max_master_y)[0]
        
        if len(master_overlap_idx) == 0 or len(slave_overlap_idx) == 0:
            print('    Warning: No overlap found for row stitching')
            return slave_corrected
        
        m_range = master_overlap_idx
        s_range = slave_overlap_idx
        print(f'    Overlap: Master rows {m_range[0]}-{m_range[-1]}, Slave rows {s_range[0]}-{s_range[-1]}')

        # Mean Ax2 error across overlap rows (vector vs X)
        master_ax2_mean = np.mean(master['Ax2Err'][m_range, :], axis=0)
        slave_ax2_mean = np.mean(slave['Ax2Err'][s_range, :], axis=0)

        # Fit Ax2 straightness vs X
        master_coef_ax2 = np.polyfit(master['X'][0, :], master_ax2_mean, 1)
        slave_coef_ax2 = np.polyfit(slave['X'][0, :], slave_ax2_mean, 1)
        print(f'    Ax2 slope correction: Master={master_coef_ax2[0]:.6f}, Slave={slave_coef_ax2[0]:.6f} um/mm')
        if diag:
            pre_ax1_master_mean = float(np.mean(master['Ax1Err'][m_range, :]))
            pre_ax1_slave_mean = float(np.mean(slave['Ax1Err'][s_range, :]))
            pre_ax2_master_mean = float(np.mean(master['Ax2Err'][m_range, :]))
            pre_ax2_slave_mean = float(np.mean(slave['Ax2Err'][s_range, :]))
            print(f'      Overlap size (rows): {len(m_range)}')
            print(f'      Pre-correction overlap means:')
            print(f'        Ax1 master={pre_ax1_master_mean:.6f}, slave={pre_ax1_slave_mean:.6f} (diff={pre_ax1_master_mean-pre_ax1_slave_mean:.6f})')
            print(f'        Ax2 master={pre_ax2_master_mean:.6f}, slave={pre_ax2_slave_mean:.6f} (diff={pre_ax2_master_mean-pre_ax2_slave_mean:.6f})')
            print(f'      Ax2 polyfit (slope, intercept): master=({master_coef_ax2[0]:.6f}, {master_coef_ax2[1]:.6f}), '
                  f'slave=({slave_coef_ax2[0]:.6f}, {slave_coef_ax2[1]:.6f})')

        # Apply Ax2 slope corrections across all rows of slave
        for n in range(slave['Y'].shape[0]):
            slave_corrected['Ax2Err'][n, :] = (
                slave_corrected['Ax2Err'][n, :]
                - np.polyval(slave_coef_ax2, slave['X'][n, :])
                + np.polyval(master_coef_ax2, slave['X'][n, :])
            )

        # Scalar offset corrections across overlap rows
        ax1_correction = np.mean(master['Ax1Err'][m_range, :]) - np.mean(slave_corrected['Ax1Err'][s_range, :])
        ax2_correction = np.mean(master['Ax2Err'][m_range, :]) - np.mean(slave_corrected['Ax2Err'][s_range, :])
        if diag:
            print(f'      Offsets to apply (pre-apply): Ax1={ax1_correction:.6f}, Ax2={ax2_correction:.6f}')
        slave_corrected['Ax1Err'] += ax1_correction
        slave_corrected['Ax2Err'] += ax2_correction
        if diag:
            post_ax1_master_mean = float(np.mean(master['Ax1Err'][m_range, :]))
            post_ax1_slave_mean = float(np.mean(slave_corrected['Ax1Err'][s_range, :]))
            post_ax2_master_mean = float(np.mean(master['Ax2Err'][m_range, :]))
            post_ax2_slave_mean = float(np.mean(slave_corrected['Ax2Err'][s_range, :]))
            print(f'      Post-apply overlap means:')
            print(f'        Ax1 master={post_ax1_master_mean:.6f}, slave={post_ax1_slave_mean:.6f} (diff={post_ax1_master_mean-post_ax1_slave_mean:.6f})')
            print(f'        Ax2 master={post_ax2_master_mean:.6f}, slave={post_ax2_slave_mean:.6f} (diff={post_ax2_master_mean-post_ax2_slave_mean:.6f})')
        print(f'    Offset corrections: Ax1={ax1_correction:.3f}, Ax2={ax2_correction:.3f} um')

    return slave_corrected


# ----------------------
# Output file writers
# ----------------------

def write_cal_file(filename, Ax1cal, Ax2cal, grid_system, setup):
    pos_unit = 'METRIC' if setup.get('UserUnit', 'METRIC').upper().startswith('METRIC') else 'ENGLISH'
    cor_unit = f"{pos_unit}/1000"
    dx = float(grid_system['incAx1'])
    dy = float(grid_system['incAx2'])

    num_cols = Ax1cal.shape[1]
    num_rows = Ax1cal.shape[0]

    offset_row = ((num_rows - 1) / 2.0) * dy
    offset_col = ((num_cols - 1) / 2.0) * dx

    with open(filename, 'w') as f:
        ax2_num = int(grid_system.get('Ax2Num', 0))
        ax1_num = int(grid_system.get('Ax1Num', 0))
        out_axis3 = int(setup.get('OutAxis3', 0))
        out_ax3_value = int(setup.get('OutAx3Value', 0))
        f.write(f":START2D {ax2_num} {ax1_num} {out_axis3} {out_ax3_value} {dx:.3f} {dy:.3f} {num_cols}\n")
        f.write(f":START2D POSUNIT={pos_unit} CORUNIT={cor_unit} OFFSETROW = {offset_row:.3f} OFFSETCOL = {offset_col:.3f}\n")
        f.write("\n")
        for i in range(num_rows):
            line_parts = []
            for j in range(num_cols):
                line_parts.append(f"{Ax1cal[i, j]:.4f}\t{Ax2cal[i, j]:.4f}")
            f.write("\t".join(line_parts) + "\n")
        f.write("\n:END\n")


def write_cal_file_start2d(filename, Ax1cal, Ax2cal, grid_system, setup):
    """Legacy START2D writer to match Matlab-Old.cal format exactly (header, offsets, CRLF, tabs)."""
    dx = float(grid_system['incAx1'])
    dy = float(grid_system['incAx2'])
    num_cols = int(Ax1cal.shape[1])
    num_rows = int(Ax1cal.shape[0])

    ax2_num = int(grid_system.get('Ax2Num', 0))
    ax1_num = int(grid_system.get('Ax1Num', 0))
    ax1_sign = int(grid_system.get('Ax1Sign', 1))
    ax2_sign = int(grid_system.get('Ax2Sign', 1))
    cal_div = int(grid_system.get('calDivisor', 1))

    # Sampling distances (use increments for single-file pipeline)
    ax1_samp = dx
    ax2_samp = dy

    # Compute origin-based offsets (include surrounding-zero border like MATLAB)
    X = np.array(grid_system['X'])
    Y = np.array(grid_system['Y'])
    try:
        origin_x = float(X[0, 0])
        origin_y = float(Y[0, 0])
    except Exception:
        origin_x = float(np.min(X)) if X.size else 0.0
        origin_y = float(np.min(Y)) if Y.size else 0.0

    offset_row = -ax2_sign * (origin_y - ax2_samp) * cal_div
    offset_col = -ax1_sign * (origin_x - ax1_samp) * cal_div

    user_unit = str(grid_system.get('UserUnit', 'METRIC'))

    # First header line: :START2D Ax2Num Ax1Num Ax1Num Ax2Num ...
    out_axis3 = ax1_num
    out_ax3_value = ax2_num

    # Write with CRLF like MATLAB
    with open(filename, 'w', encoding='utf-8', newline='\r\n') as f:
        f.write(f":START2D {ax2_num} {ax1_num} {out_axis3} {out_ax3_value} {ax2_samp*cal_div:.3f} {ax1_samp*cal_div:.3f} {num_cols} \r\n")
        # Second header line (no OUTAXIS3 for non-gantry dataset)
        f.write(
            f":START2D POSUNIT={user_unit} CORUNIT={user_unit}/{1000//max(cal_div,1)} "
            f"OFFSETROW = {offset_row:.3f} OFFSETCOL = {offset_col:.3f} \r\n"
        )
        # Blank line per MATLAB
        f.write("\r\n")
        # Data rows: tab-separated pairs, no trailing tab
        for i in range(num_rows):
            tokens = []
            for j in range(num_cols):
                tokens.append(f"{Ax1cal[i, j]:.4f}")
                tokens.append(f"{Ax2cal[i, j]:.4f}")
            f.write("\t".join(tokens) + "\r\n")
        f.write(":END\r\n")


def write_accuracy_file(filename, X, Y, Ax1Err, Ax2Err, VectorErr, valid_mask, grid_system, setup):
    with open(filename, 'w', encoding='utf-8', newline='\n') as f:
        f.write('% Multi-Zone 2D Accuracy Calibration Results\n')
        f.write(f"% System: {grid_system['model']} (S/N: {grid_system['SN']})\n")
        f.write(f"% Zones processed: {grid_system['zoneCount']}\n")
        f.write(f"% Grid size: {X.shape[0]} x {X.shape[1]} points\n")
        f.write(f"% Units: {grid_system['UserUnit']}\n")
        f.write('% Ax1TestLoc Ax2TestLoc Ax1Err Ax2Err VectorErr AvgCount\n')
        for i in range(X.shape[0]):
            for j in range(X.shape[1]):
                if valid_mask[i, j]:
                    f.write(f'{X[i,j]:.6f}\t{Y[i,j]:.6f}\t{Ax1Err[i,j]:.6f}\t{Ax2Err[i,j]:.6f}\t{VectorErr[i,j]:.6f}\t{grid_system["avgCount"][i,j]:.0f}\n')


# ----------------------
# Plotting helper
# ----------------------

def save_plots(plot_path, X, Y, Ax1Err, Ax2Err, VectorErr):
    if not HAS_MPL:
        print('Matplotlib not available; skipping plot generation.')
        return
    fig, axes = plt.subplots(1, 3, figsize=(18, 5), constrained_layout=True)
    extent = [np.min(X), np.max(X), np.min(Y), np.max(Y)]

    im0 = axes[0].imshow(Ax1Err, origin='lower', extent=extent, aspect='auto', cmap='viridis')
    axes[0].set_title('Ax1 Error (um)')
    plt.colorbar(im0, ax=axes[0])

    im1 = axes[1].imshow(Ax2Err, origin='lower', extent=extent, aspect='auto', cmap='magma')
    axes[1].set_title('Ax2 Error (um)')
    plt.colorbar(im1, ax=axes[1])

    im2 = axes[2].imshow(VectorErr, origin='lower', extent=extent, aspect='auto', cmap='inferno')
    axes[2].set_title('Vector Error (um)')
    plt.colorbar(im2, ax=axes[2])

    for ax in axes:
        ax.set_xlabel('X (mm)')
        ax.set_ylabel('Y (mm)')

    fig.suptitle('Stitched 2D Calibration Errors', fontsize=14)
    fig.savefig(plot_path, dpi=150)
    plt.close(fig)
    print(f'Plot saved: {plot_path}')


# ----------------------
# End-to-end pipeline
# ----------------------

def process_single_zone(zone_file):
    """Run complete single-zone pipeline and return dicts; for stitching preserve absolute reference."""
    config = step1_parse_header(zone_file)
    data_raw = step2_load_data(zone_file, config)
    grid_data = step3_create_grid(data_raw)

    # Compute per-zone slopes
    slope_data = step4_calculate_slopes(grid_data)
    # Use multizone-compatible step5 that preserves absolute error references
    processed_data = step5_process_errors_multizone(grid_data, slope_data)

    # For stitching, MATCH MATLAB: use per-zone processed errors with slopes removed but absolute reference preserved
    zone = {
        'X': processed_data['X'].copy(),
        'Y': processed_data['Y'].copy(),
        'Ax1Err': processed_data['Ax1Err'].copy(),
        'Ax2Err': processed_data['Ax2Err'].copy(),
    }
    meta = {
        'config': config,
        'grid_data': grid_data,
        'slope_data': slope_data,
        'processed_data': processed_data,
    }
    return zone, meta


def stitch_and_calibrate(zone_files, rows, cols, out_cal, out_dat, plot_path=None, user_unit_override=None, dump_cal_dir=None):
    if len(zone_files) != rows * cols:
        raise ValueError(f'Expected {rows*cols} zone files, got {len(zone_files)}')

    # Process zones in row-major order, apply stitching progressively
    zones_corrected = []  # list of dicts with corrected zone data
    metas = []            # parallel list of metadata

    y_meas_dir = -1
    col_master = {}
    row_master = {}

    # Also track overall bounds while stitching (using corrected zone positions)
    minX = np.inf
    maxX = -np.inf
    minY = np.inf
    maxY = -np.inf

    # Will capture increments from the first zone
    incAx1 = None
    incAx2 = None

    # Capture representative system/config info from first zone
    sys_info = {}

    zone_idx = 0
    for i in range(rows):
        for j in range(cols):
            zone_file = zone_files[zone_idx]
            print('----------------------------------------')
            print(f'Processing Zone: Row {i+1}, Col {j+1} -> {zone_file}')
            zone_raw, meta = process_single_zone(zone_file)

            if incAx1 is None:
                # Determine increments from first zone grid
                incAx1 = zone_raw['X'][0, 1] - zone_raw['X'][0, 0] if zone_raw['X'].shape[1] > 1 else 1.0
                incAx2 = zone_raw['Y'][1, 0] - zone_raw['Y'][0, 0] if zone_raw['Y'].shape[0] > 1 else 1.0
                # System info
                cfg = meta['config']
                sys_info = {
                    'SN': cfg.get('SN', ''),
                    'Ax1Name': cfg.get('Ax1Name', ''),
                    'Ax2Name': cfg.get('Ax2Name', ''),
                    'Ax1Num': cfg.get('Ax1Num', 0),
                    'Ax2Num': cfg.get('Ax2Num', 0),
                    'Ax1Sign': cfg.get('Ax1Sign', 1),
                    'Ax2Sign': cfg.get('Ax2Sign', 1),
                    'UserUnit': user_unit_override if user_unit_override else cfg.get('UserUnit', 'METRIC'),
                    'calDivisor': cfg.get('calDivisor', 1),
                    'posUnit': cfg.get('posUnit', 'mm'),
                    'errUnit': cfg.get('errUnit', '\\mum'),
                    'operator': cfg.get('operator', ''),
                    'model': cfg.get('model', ''),
                }

            if i == 0 and j == 0:
                # First zone becomes master
                col_master = {
                    'X': zone_raw['X'].copy(),
                    'Y': zone_raw['Y'].copy(),
                    'Ax1Err': zone_raw['Ax1Err'].copy(),
                    'Ax2Err': zone_raw['Ax2Err'].copy(),
                }
                row_master[(i, j)] = deepcopy(col_master)
                slave_corrected = deepcopy(col_master)
            else:
                # Determine master and stitch type
                if j > 0:
                    master = col_master
                    stitch_type = 'column'
                else:
                    master = row_master[(i-1, j)]
                    stitch_type = 'row'
                slave_corrected = apply_stitching_corrections(master, zone_raw, stitch_type, y_meas_dir, diag=bool(dump_cal_dir), dump_dir=dump_cal_dir)
                # Update masters
                col_master = deepcopy(slave_corrected)
                if (i > 0) and (j == 0):
                    row_master[(i, j)] = deepcopy(slave_corrected)

            # Track bounds
            minX = min(minX, float(np.min(slave_corrected['X'])))
            maxX = max(maxX, float(np.max(slave_corrected['X'])))
            minY = min(minY, float(np.min(slave_corrected['Y'])))
            maxY = max(maxY, float(np.max(slave_corrected['Y'])))

            zones_corrected.append(slave_corrected)
            metas.append(meta)
            zone_idx += 1

    # Allocate full grid based on bounds and increments
    num_points_ax1 = int(round((maxX - minX) / incAx1) + 1)
    num_points_ax2 = int(round((maxY - minY) / incAx2) + 1)
    print(f'Full grid dimensions: {num_points_ax2} x {num_points_ax1} points')

    X_full = np.zeros((num_points_ax2, num_points_ax1))
    Y_full = np.zeros((num_points_ax2, num_points_ax1))
    Ax1Err_full = np.zeros((num_points_ax2, num_points_ax1))
    Ax2Err_full = np.zeros((num_points_ax2, num_points_ax1))
    avgCount = np.zeros((num_points_ax2, num_points_ax1))

    # Accumulate corrected zones into full grid
    for z in zones_corrected:
        start_ax1 = int(round((z['X'][0, 0] - minX) / incAx1))
        start_ax2 = int(round((z['Y'][0, 0] - minY) / incAx2))
        h, w = z['X'].shape
        r_ax1 = slice(start_ax1, start_ax1 + w)
        r_ax2 = slice(start_ax2, start_ax2 + h)
        X_full[r_ax2, r_ax1] += z['X']
        Y_full[r_ax2, r_ax1] += z['Y']
        Ax1Err_full[r_ax2, r_ax1] += z['Ax1Err']
        Ax2Err_full[r_ax2, r_ax1] += z['Ax2Err']
        avgCount[r_ax2, r_ax1] += 1.0

    valid_mask = avgCount > 0

    # Average overlapped regions
    X_avg = np.zeros_like(X_full)
    Y_avg = np.zeros_like(Y_full)
    Ax1Err_avg = np.zeros_like(Ax1Err_full)
    Ax2Err_avg = np.zeros_like(Ax2Err_full)
    X_avg[valid_mask] = X_full[valid_mask] / avgCount[valid_mask]
    Y_avg[valid_mask] = Y_full[valid_mask] / avgCount[valid_mask]
    Ax1Err_avg[valid_mask] = Ax1Err_full[valid_mask] / avgCount[valid_mask]
    Ax2Err_avg[valid_mask] = Ax2Err_full[valid_mask] / avgCount[valid_mask]

    # Save stitched data BEFORE slope removal for debugging (like MATLAB does)
    try:
        sio.savemat('python_stitched_before_slopes.mat', {
            'X': X_avg,
            'Y': Y_avg, 
            'Ax1Err_before_slopes': Ax1Err_avg,
            'Ax2Err_before_slopes': Ax2Err_avg,
            'avgCount': avgCount
        })
        print('Pre-slope-removal data saved for debugging: python_stitched_before_slopes.mat')
    except Exception as e:
        print(f'Warning: could not save pre-slope data ({e})')

    # Remove global slopes, compute orthogonality (match MATLAB step4_calculate_slopes exactly)
    # Calculate mean straightness errors along each axis (same as MATLAB)
    # Ax1 straightness: average error in Ax1 direction vs Ax2 position
    Ax1_mean = np.mean(Ax1Err_avg, axis=1)  # Average across rows (Ax1 direction)
    Ax2_mean = np.mean(Ax2Err_avg, axis=0)  # Average across columns (Ax2 direction)

    # Fit linear slopes to the mean straightness errors (same as MATLAB)
    # Ax1Coef: slope of Ax1 error vs Ax2 position (units: microns/mm)
    Ax1Coef = np.polyfit(Y_avg[:, 0], Ax1_mean, 1)
    # Ax2Coef: slope of Ax2 error vs Ax1 position (units: microns/mm)
    Ax2Coef = np.polyfit(X_avg[0, :], Ax2_mean, 1)
    print(f'Debug: Global slope coefficients - Ax1: {Ax1Coef}, Ax2: {Ax2Coef}')
    y_meas_dir = -1
    Ax1Line = np.polyval(Ax1Coef, Y_avg[:, 0])
    Ax2Line = np.polyval(y_meas_dir * Ax1Coef, X_avg[0, :])
    print(f'Debug: Slope lines at origin - Ax1Line[0]: {Ax1Line[0]:.6f}, Ax2Line[0]: {Ax2Line[0]:.6f}')

    for i in range(num_points_ax1):
        if np.any(valid_mask[:, i]):
            Ax1Err_avg[:, i] -= Ax1Line
    for i in range(num_points_ax2):
        if np.any(valid_mask[i, :]):
            Ax2Err_avg[i, :] -= Ax2Line

    orthog = Ax1Coef[0] - y_meas_dir * Ax2Coef[0]
    orthog_arcsec = np.arctan(orthog/1000) * 180/np.pi * 3600

    # Zero-reference at origin if valid
    if valid_mask[0, 0]:
        ax1_offset = Ax1Err_avg[0, 0]
        ax2_offset = Ax2Err_avg[0, 0]
        print(f'Debug: Zero-referencing offsets - Ax1: {ax1_offset:.6f}, Ax2: {ax2_offset:.6f}')
        Ax1Err_avg = Ax1Err_avg - ax1_offset
        Ax2Err_avg = Ax2Err_avg - ax2_offset

    VectorErr = np.sqrt(Ax1Err_avg**2 + Ax2Err_avg**2)

    valid_ax1_errors = Ax1Err_avg[valid_mask]
    valid_ax2_errors = Ax2Err_avg[valid_mask]
    valid_vector_errors = VectorErr[valid_mask]

    pkAx1 = float(np.max(valid_ax1_errors) - np.min(valid_ax1_errors))
    pkAx2 = float(np.max(valid_ax2_errors) - np.min(valid_ax2_errors))
    pkVector = float(np.max(valid_vector_errors) - np.min(valid_vector_errors))

    rmsAx1 = float(np.sqrt(np.mean(valid_ax1_errors**2)))
    rmsAx2 = float(np.sqrt(np.mean(valid_ax2_errors**2)))
    rmsVector = float(np.sqrt(np.mean(valid_vector_errors**2)))

    # Build grid_system/setup for writers
    grid_system = {
        'X': X_avg,
        'Y': Y_avg,
        'Ax1Err': Ax1Err_avg,
        'Ax2Err': Ax2Err_avg,
        'avgCount': avgCount,
        'incAx1': incAx1,
        'incAx2': incAx2,
        'zoneCount': rows * cols,
        **sys_info,
    }
    setup = {
        'WriteCalFile': 1,
        'OutAxis3': 0,
        'OutAx3Value': 2,
        'CalFile': out_cal,
        'UserUnit': grid_system['UserUnit'],
        'writeOutputFile': 1,
        'OutFile': out_dat,
    }

    # Generate calibration file with surrounding zeros (as in multizone_step4)
    size_cal = Ax1Err_avg.shape
    Ax1cal = np.zeros((size_cal[0] + 2, size_cal[1] + 2))
    Ax2cal = np.zeros((size_cal[0] + 2, size_cal[1] + 2))
    Ax1cal[1:-1, 1:-1] = -grid_system['Ax1Sign'] * np.round(Ax1Err_avg * 10000) / 10000
    Ax2cal[1:-1, 1:-1] = -grid_system['Ax2Sign'] * np.round(Ax2Err_avg * 10000) / 10000

    # Optional dump of calibration and unrounded matrices for debugging/parity checks
    if dump_cal_dir:
        try:
            os.makedirs(dump_cal_dir, exist_ok=True)
            np.savetxt(os.path.join(dump_cal_dir, 'Ax1cal.txt'), Ax1cal, fmt='%.6f')
            np.savetxt(os.path.join(dump_cal_dir, 'Ax2cal.txt'), Ax2cal, fmt='%.6f')
            np.save(os.path.join(dump_cal_dir, 'Ax1cal.npy'), Ax1cal)
            np.save(os.path.join(dump_cal_dir, 'Ax2cal.npy'), Ax2cal)
            np.savetxt(os.path.join(dump_cal_dir, 'Ax1Err_avg_unrounded.txt'), Ax1Err_avg, fmt='%.6f')
            np.savetxt(os.path.join(dump_cal_dir, 'Ax2Err_avg_unrounded.txt'), Ax2Err_avg, fmt='%.6f')
            np.save(os.path.join(dump_cal_dir, 'Ax1Err_avg_unrounded.npy'), Ax1Err_avg)
            np.save(os.path.join(dump_cal_dir, 'Ax2Err_avg_unrounded.npy'), Ax2Err_avg)
            print(f'Debug matrices written to {dump_cal_dir}')
        except Exception as e:
            print(f'Warning: failed to dump debug matrices: {e}')

    write_cal_file(out_cal, Ax1cal, Ax2cal, grid_system, setup)
    print(f'Calibration file written: {out_cal}')

    write_accuracy_file(out_dat, X_avg, Y_avg, Ax1Err_avg, Ax2Err_avg, VectorErr, valid_mask, grid_system, setup)
    print(f'Accuracy data file written: {out_dat}')

    # Also emit legacy START2D file for parity with old MATLAB script
    legacy_cal = os.path.splitext(out_cal)[0] + '_start2d.cal'
    write_cal_file_start2d(legacy_cal, Ax1cal, Ax2cal, grid_system, setup)
    print(f'Legacy START2D calibration file written: {legacy_cal}')

    if plot_path:
        save_plots(plot_path, X_avg, Y_avg, Ax1Err_avg, Ax2Err_avg, VectorErr)

    # Save .mat summary (optional, helpful for downstream)
    try:
        sio.savemat('stitched_multizone_summary.mat', {
            'X': X_avg,
            'Y': Y_avg,
            'Ax1Err': Ax1Err_avg,
            'Ax2Err': Ax2Err_avg,
            'VectorErr': VectorErr,
            'avgCount': avgCount,
            'orthogonality_arcsec': orthog_arcsec,
            'pkAx1': pkAx1,
            'pkAx2': pkAx2,
            'pkVector': pkVector,
            'rmsAx1': rmsAx1,
            'rmsAx2': rmsAx2,
            'rmsVector': rmsVector,
        })
        print('Summary MAT file written: stitched_multizone_summary.mat')
    except Exception as e:
        print(f'Warning: could not write MAT summary ({e})')

    print('\n=== FINAL CALIBRATION SUMMARY ===')
    print(f"Total zones processed: {rows*cols}")
    print(f"Final grid size: {X_avg.shape[0]} x {X_avg.shape[1]} points")
    coverage = 100 * float(np.sum(valid_mask)) / float(np.prod(X_avg.shape))
    print(f"Valid data points: {int(np.sum(valid_mask))} ({coverage:.1f}% coverage)")
    overlap_pts = int(np.sum(avgCount > 1))
    print(f"Overlap points: {overlap_pts}")
    print('Final accuracy performance:')
    print(f"  Ax1: ±{pkAx1/2:.3f} um P-P, {rmsAx1:.3f} um RMS")
    print(f"  Ax2: ±{pkAx2/2:.3f} um P-P, {rmsAx2:.3f} um RMS")
    print(f"  Vector: {rmsVector:.3f} um RMS")
    print(f"  Orthogonality: {orthog_arcsec:.3f} arc-seconds")

    return {
        'grid_system': grid_system,
        'stats': {
            'orthogonality_arcsec': orthog_arcsec,
            'pkAx1': pkAx1,
            'pkAx2': pkAx2,
            'pkVector': pkVector,
            'rmsAx1': rmsAx1,
            'rmsAx2': rmsAx2,
            'rmsVector': rmsVector,
        }
    }


def parse_args(argv=None):
    p = argparse.ArgumentParser(description='2D multi-zone stitching and calibration (single-file pipeline).')
    p.add_argument('--rows', type=int, required=True, help='Number of zone rows (Axis 2 direction)')
    p.add_argument('--cols', type=int, required=True, help='Number of zone columns (Axis 1 direction)')
    p.add_argument('--zones', nargs='+', required=True, help='Zone data files in row-major order (len = rows*cols)')
    p.add_argument('--out-cal', default='stitched_multizone_python.cal', help='Output calibration .cal file path')
    p.add_argument('--out-dat', default='stitched_multizone_accuracy_python.dat', help='Output accuracy .dat file path')
    p.add_argument('--plot', default=None, help='Optional path to save a PNG plot')
    p.add_argument('--user-unit', choices=['METRIC', 'ENGLISH'], default=None, help='Override UserUnit (normally read from headers)')
    p.add_argument('--dump-cal', dest='dump_cal', default=None, help='Optional directory to dump Ax1cal/Ax2cal and unrounded matrices before writing')
    return p.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)
    # Validate paths
    missing = [z for z in args.zones if not os.path.exists(z)]
    if missing:
        print('ERROR: Missing zone files:')
        for z in missing:
            print(f'  - {z}')
        return 1

    result = stitch_and_calibrate(
        zone_files=args.zones,
        rows=args.rows,
        cols=args.cols,
        out_cal=args.out_cal,
        out_dat=args.out_dat,
        plot_path=args.plot,
        user_unit_override=args.user_unit,
        dump_cal_dir=args.dump_cal,
    )
    return 0


if __name__ == '__main__':
    sys.exit(main())