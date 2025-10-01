# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

Project overview
- Purpose: 2D accuracy analysis and stitching for single-zone and multi-zone calibration data. The repo implements a 5-step single-zone pipeline and a 4-step multizone pipeline, plus utilities to compare Python output against MATLAB/Octave.
- Primary language: Python (scripts, no packaging). Data inputs are .dat measurement files under MATLAB Source/.

Prerequisites
- Python with pip
- Python packages used in the code: numpy, scipy, pandas
- Optional for Octave comparisons: GNU Octave on PATH (used by compare_step1.py)

Environment setup (Windows PowerShell)
- Create and activate a venv, then install dependencies:
  - py -3 -m venv .venv
  - .\.venv\Scripts\Activate.ps1
  - pip install numpy scipy pandas

Common commands
- Single-zone: run the full pipeline (generates step1_output_python.txt … step5_output_python.txt and complete_pipeline_python.mat)
  - python test_all_steps_python.py
  - Notes: Expects data file MATLAB Source/642583-1-1-CZ1.dat. If missing, the script lists available .dat files in MATLAB Source/.
- Single-zone: run an individual step’s built-in test (each script has a __main__ that exercises the step)
  - Step 1 header parser: python step1_parse_header.py
  - Step 2 raw data loader: python step2_load_data.py
  - Step 3 grid creator: python step3_create_grid.py
  - Step 4 slope calculator: python step4_calculate_slopes.py
  - Step 5 error processing: python step5_process_errors.py
- Multizone: end-to-end calibration (runs setup → initialize grid → stitch zones → finalize; generates calibration and accuracy files)
  - python multizone_step4_finalize_calibration.py
  - Output files (defaults set internally):
    - Calibration file: stitched_multizone.cal (or overridden to stitched_multizone_python.cal in the __main__ of step4)
    - Accuracy data: stitched_multizone_accuracy.dat (or stitched_multizone_accuracy_python.dat)
- Multizone: run specific stages (each has a __main__)
  - Setup only (validates inputs, prints config, writes multizone_step1_output_python.txt):
    - python multizone_step1_setup.py
  - Initialize grid with first zone (writes multizone_step2_output_python.txt):
    - python multizone_step2_initialize_grid.py
  - Stitch remaining zones (writes multizone_step3_output_python.txt):
    - python multizone_step3_stitch_zones.py
- Compare outputs (Python vs MATLAB/Octave text files)
  - Compare step outputs (1–5): python compare_outputs.py
  - Compare header parser (runs Octave test if available): python compare_step1.py
  - Multizone comparisons:
    - Step 1: python compare_multizone_step1.py
    - Step 2: python compare_multizone_step2.py
    - Step 3: python compare_multizone_step3.py
  - Compare generated calibration/data files: python compare_cal_files.py

Running a single test
- This repo doesn’t use pytest/unittest; instead, run the specific step script you want to validate. Example: to validate slope calculation only, run:
  - python step4_calculate_slopes.py

High-level architecture
Single-zone pipeline (step1 → step5)
- step1_parse_header.step1_parse_header(input_file) → config: Parses header lines to a config dict (axis names/numbers/signs/gantry flags; units and divisor; operator/model/environment; file date). Key fields include SN, Ax1Name/Ax2Name, Ax1Num/Ax2Num, Ax1Sign/Ax2Sign, Ax1Gantry/Ax2Gantry, UserUnit, calDivisor, posUnit, errUnit, operator, model, airTemp, matTemp, expandCoef, comment, fileDate.
- step2_load_data.step2_load_data(input_file, config) → data_raw: Loads numeric table (auto-detects start after header). Computes:
  - Position/command vectors (Ax1PosCmd, Ax2PosCmd), test indices, relative errors (Ax1RelErr, Ax2RelErr), microns-centered errors (Ax1RelErr_um, Ax2RelErr_um)
  - Counts and sampling distances (NumAx1Points/NumAx2Points, Ax1SampDist/Ax2SampDist), Ax1Pos/Ax2Pos ranges
- step3_create_grid.step3_create_grid(data_raw) → grid_data: Creates 2D position meshes X, Y and interpolates error fields to a regular grid using scipy.interpolate.griddata (linear), storing Ax1Err, Ax2Err, SizeGrid and normalization factors maxAx1/maxAx2.
- step4_calculate_slopes.step4_calculate_slopes(grid_data) → slope_data: Averages straightness by axis; fits linear slopes (um/mm) to Ax1 vs Y and Ax2 vs X; computes orthogonality in arc-seconds using y_meas_dir = -1; produces Ax1Line/Ax2Line and detrended vectors Ax1Orthog/Ax2Orthog.
- step5_process_errors.step5_process_errors(grid_data, slope_data) → processed_data: Removes Ax1Line/Ax2Line from the grid error matrices, zero-references at origin, computes VectorErr and summary stats: pkAx1/pkAx2, rmsAx1/rmsAx2/rmsVector, maxVectorErr, amplitudes, and carries slope_data.

Multizone pipeline (step1 → step4)
- multizone_step1_setup.multizone_step1_setup(num_row, num_col, travel_ax1, travel_ax2, zone_filenames) → setup: Validates a 2D list of zone filenames and travel ranges (inches). Stores options for calibration/output file generation and pre-allocates arrays for environmental metadata.
- multizone_step2_initialize_grid.multizone_step2_initialize_grid(setup) → grid_system: Processes the first zone via the single-zone pipeline to establish master references and grid increments (incAx1/incAx2). Initializes full-travel matrices (X, Y, Ax1Err, Ax2Err) and an overlap counter avgCount; records system/config metadata; seeds zoneCount = 1.
- multizone_step3_stitch_zones.multizone_step3_stitch_zones(setup, grid_system) → grid_system: Iterates zones row-major. For each zone, runs the single-zone pipeline, then stitches to either the previous column (column stitch) or previous row (row stitch):
  - Finds overlap in X or Y, fits linear slopes on overlap means, applies slope corrections (with y_meas_dir coupling) and offset corrections, updates accumulation matrices and avgCount, advances zoneCount.
- multizone_step4_finalize_calibration.multizone_step4_finalize_calibration(setup, grid_system) → final_result: Averages accumulated fields by avgCount, removes global straightness slopes and computes orthogonality, computes vector errors and stats, and optionally writes:
  - A3200 START2D-format calibration file (write_cal_file): uses unit strings, grid spacing, and offset rows/cols; writes signed correction tables (with surrounding zeros and sign based on Ax1Sign/Ax2Sign).
  - Accuracy verification .dat file (write_accuracy_file) with valid points only and avgCount.

Data and units
- Test and multizone scripts expect .dat input files in MATLAB Source/ (e.g., 642583-1-1-CZ1.dat … CZ4.dat). Many __main__ blocks will list or validate these files.
- Units: UserUnit and calDivisor from the header determine conversion. Errors are reported in microns (um). Travel ranges in the multizone setup are specified in inches but are converted to mm internally for grid spacing.

Build, lint, CI
- Build: There is no packaging/build system; scripts are executed directly.
- Lint/format (optional, not configured in repo): If desired, install tools and run on demand:
  - pip install ruff black
  - ruff check .
  - black .

Notes for future agents
- When running any script’s __main__, ensure the expected data files exist under MATLAB Source/. Several scripts will terminate early and print guidance if files are missing.
- Comparison utilities assume that both the Octave/MATLAB-generated and Python-generated text outputs exist side-by-side with well-known filenames (…_octave.txt vs …_python.txt).
