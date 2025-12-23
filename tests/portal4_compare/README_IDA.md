# IDA Suite for Problema 4 - Portal Frame Seismic Analysis

Comprehensive Incremental Dynamic Analysis (IDA) workflow for a single-story portal frame under seismic loading.

## Overview

This IDA suite performs a systematic analysis of a portal frame structure subjected to increasing seismic intensities until collapse. The workflow includes:

1. **Input Generation**: Earthquake signals and CalculiX models for multiple amplitudes
2. **Analysis Execution**: Sequential dynamic analyses with collapse detection
3. **Results Extraction**: Peak drifts, rotations, forces, and energy dissipation
4. **Visualization**: IDA curves, time histories, and performance metrics
5. **Validation Report**: Comprehensive assessment against code requirements

## Problem Specifications (Problema 4)

### Structural System

- **Type**: Single-story portal frame
- **Geometry**:
  - Height: H = 3.0 m
  - Span: L = 5.0 m
- **Sections** (from Problema 2):
  - S1 (columns): 40 × 60 cm, 4 bars φ20mm
  - S2 (beam): 25 × 50 cm, 3+2 bars φ20mm
- **Plastic Hinges**: 4 locations
  - 2 at column bases
  - 2 at beam-column connections

### Loading

**Seismic input**: `a_g(t) = A · cos(0.2πt) · sin(4πt)`, t ∈ [0, 10] s

- **Amplitude range**: A = 0.1g, 0.2g, ..., up to collapse
- **Fundamental period**: T₀ ≈ 0.5 s

### Collapse Criterion

**Drift > 5%** (i.e., horizontal displacement > H/20 = 15 cm for H = 3m)

## Quick Start

### Option 1: Run Complete Workflow (Recommended)

```bash
# Run full IDA workflow with default parameters (0.1g to 1.0g, step 0.1g)
bash run_full_ida.sh

# Custom amplitude range
bash run_full_ida.sh --start 0.1 --end 0.8 --step 0.1

# Specify CalculiX executable
bash run_full_ida.sh --ccx /path/to/ccx
```

This single command will:
- Generate all input files
- Run all analyses
- Extract results
- Create plots
- Generate validation report

**Output**: All results in `ida/` directory

### Option 2: Step-by-Step Execution

```bash
# Step 1: Generate IDA test suite
bash generate_ida_suite.sh

# Step 2: Run analyses
bash run_ida_analysis.sh

# Step 3: Extract results
python3 extract_ida_results.py

# Step 4: Generate plots
python3 plot_ida_validation.py

# Step 5: Create report
python3 generate_ida_report.py
```

## Directory Structure

```
tests/portal4_compare/
├── generate_ida_suite.sh          # Generate all inputs
├── run_ida_analysis.sh            # Run all analyses
├── extract_ida_results.py         # Extract results to CSV
├── plot_ida_validation.py         # Generate validation plots
├── generate_ida_report.py         # Create markdown report
├── run_full_ida.sh                # Master script (runs all)
├── generate_earthquake_senoidal.py  # Earthquake signal generator
├── generate_portal_eq_ccx.py      # CCX input generator
└── ida/                           # Output directory
    ├── portal_A0.1g.inp           # CalculiX input files
    ├── portal_A0.1g.dat           # CalculiX output files
    ├── portal_A0.1g.frd           # Results (for visualization)
    ├── portal_A0.1g.hinge_map.json  # Hinge node mapping
    ├── earthquake_A0.1g.csv       # Earthquake signal
    ├── ida_results_summary.csv    # Summary of all results
    ├── ida_summary.txt            # Quick summary
    ├── IDA_VALIDATION_REPORT.md   # Validation report
    ├── plots/                     # All plots (PDF + PNG)
    │   ├── ida_curve.png
    │   ├── drift_histories.png
    │   ├── rotation_accumulation.png
    │   ├── base_shear_vs_drift.png
    │   ├── energy_dissipation.png
    │   └── ida_summary.png
    └── logs/                      # Analysis logs
        ├── ida_run.log
        └── portal_A*.ccx.log
```

## Scripts Documentation

### 1. `generate_ida_suite.sh`

Generates earthquake signals and CalculiX input files for all amplitudes.

**Usage:**
```bash
bash generate_ida_suite.sh [--start 0.1] [--end 1.0] [--step 0.1]
```

**Options:**
- `--start A`: Starting amplitude (default: 0.1)
- `--end A`: Ending amplitude (default: 1.0)
- `--step A`: Amplitude increment (default: 0.1)

**Output:**
- `ida/portal_A*.inp`: CalculiX input files
- `ida/earthquake_A*.csv`: Earthquake signals
- `ida/*.hinge_map.json`: Hinge node mappings

### 2. `run_ida_analysis.sh`

Runs all IDA analyses sequentially with collapse detection.

**Usage:**
```bash
bash run_ida_analysis.sh [--ccx /path/to/ccx] [--start 0.1] [--end 1.0]
```

**Options:**
- `--ccx PATH`: Path to CalculiX executable (default: ../../bin/ccx_2.21)
- `--start A`: Starting amplitude
- `--end A`: Ending amplitude
- `--step A`: Amplitude step

**Features:**
- Monitors peak drift during execution
- Stops automatically when collapse detected (drift > 5%)
- Handles timeouts (max 10 min per analysis)
- Logs all output

**Output:**
- `ida/*.dat`: CalculiX output files
- `ida/*.frd`: Results for visualization
- `ida/ida_summary.txt`: Quick summary
- `ida/logs/*.log`: Analysis logs

### 3. `extract_ida_results.py`

Parses .dat files and extracts IDA metrics to CSV.

**Usage:**
```bash
python3 extract_ida_results.py [--ida-dir ida] [--output ida_results_summary.csv]
```

**Extracted Metrics:**
- Peak and residual roof drift (cm and %)
- Peak plastic rotations at each hinge
- Maximum base shear
- Energy dissipation
- Analysis status (OK, COLLAPSE, FAILED)

**Output:**
- `ida/ida_results_summary.csv`: Summary CSV with all metrics

### 4. `plot_ida_validation.py`

Generates all validation plots.

**Usage:**
```bash
python3 plot_ida_validation.py [--ida-dir ida] [--output-dir ida/plots]
```

**Generated Plots:**
1. **IDA Curve**: Peak drift vs. amplitude
2. **Drift Histories**: Time histories for multiple amplitudes
3. **Rotation Accumulation**: Peak rotation vs. amplitude for each hinge
4. **Base Shear vs. Drift**: Strength degradation
5. **Energy Dissipation**: Cumulative energy vs. amplitude
6. **Summary Figure**: Multi-panel comprehensive view

**Output:**
- `ida/plots/*.png`: Publication-quality plots (150 DPI)
- `ida/plots/*.pdf`: Vector graphics (300 DPI)

### 5. `generate_ida_report.py`

Creates comprehensive markdown validation report.

**Usage:**
```bash
python3 generate_ida_report.py [--ida-dir ida] [--output IDA_VALIDATION_REPORT.md]
```

**Report Contents:**
- Executive summary with collapse amplitude
- Structural configuration
- IDA results table
- Performance ranges (elastic, plastic, collapse)
- Validation against expected behavior
- All plots embedded
- Recommendations
- Conclusions

**Output:**
- `ida/IDA_VALIDATION_REPORT.md`: Markdown report

## Validation Plots Explained

### 1. IDA Curve

The most important plot showing peak drift vs. spectral acceleration. Key features:

- **X-axis**: Peak roof drift (%)
- **Y-axis**: Spectral acceleration (g)
- **Red dashed line**: Collapse criterion (5% drift)
- **Expected behavior**:
  - Initial steep slope (elastic)
  - Gradual flattening (plastic)
  - Plateau or negative slope (collapse)

### 2. Drift Time Histories

Shows displacement evolution during each earthquake:

- Multiple amplitudes overlaid
- Dashed lines indicate collapse cases
- Red horizontal lines mark ±5% collapse limits

### 3. Rotation Accumulation

Peak plastic rotation at each hinge vs. amplitude:

- Identifies which hinge governs collapse
- Shows progressive yielding
- Compare against 0.04 rad limit (typical for RC)

### 4. Base Shear vs. Drift

Demonstrates strength degradation:

- Should show strength plateau
- Degradation indicates damage progression
- Collapse cases show significant drop

### 5. Energy Dissipation

Cumulative plastic energy vs. amplitude:

- Indicates inelastic deformation
- Should increase nonlinearly
- Rapid increase near collapse

## Expected Results

### Performance Ranges

Based on typical portal frame behavior:

| Amplitude | Peak Drift | Status | Description |
|-----------|------------|--------|-------------|
| 0.1g | < 1.0% | Elastic | Minimal damage |
| 0.2g | 1-2% | Light plastic | Repairable damage |
| 0.3-0.5g | 2-4% | Moderate plastic | Significant damage |
| 0.6-0.8g | > 5% | Collapse | Structural failure |

### Collapse Capacity

For a typical portal frame with these dimensions and sections:
- **Expected collapse amplitude**: 0.6-0.8g
- **Peak drift at collapse**: ~5-7%

If results deviate significantly, review:
- Material properties (E, f_c, f_y)
- Section dimensions
- Hinge moment-rotation curves
- Damping coefficients

## Troubleshooting

### Issue: Analyses taking too long

**Solution**:
- Reduce amplitude range: `--end 0.5`
- Increase step size: `--step 0.2`
- Check for convergence issues in logs

### Issue: No collapse detected

**Solution**:
- Extend amplitude range: `--end 1.5`
- Check collapse criterion (may need adjustment)
- Review structural capacity (may be over-designed)

### Issue: Early collapse (A < 0.3g)

**Solution**:
- Review material properties
- Check section sizes
- Verify hinge moment-rotation curves
- Inspect .dat files for anomalies

### Issue: Plots not generating

**Solution**:
```bash
# Install required packages
pip install matplotlib numpy

# Or use system packages
sudo apt-get install python3-matplotlib python3-numpy
```

### Issue: Missing .dat files

**Solution**:
- Check CalculiX execution logs in `ida/logs/`
- Verify CCX executable permissions
- Review convergence in .sta files

## Advanced Usage

### Custom Collapse Criterion

Edit `run_ida_analysis.sh` to modify the collapse drift threshold:

```bash
COLLAPSE_DRIFT_PCT=5.0  # Change to desired value (e.g., 3.0 for 3%)
```

### Extract Specific Metrics

For custom post-processing, parse the .dat files directly:

```python
from extract_ida_results import parse_dat_file

dat_data = parse_dat_file(Path("ida/portal_A0.3g.dat"))
time_steps = dat_data['time_steps']
displacements = dat_data['displacements']
```

### Visualization with CGX

View 3D results using CalculiX GraphiX:

```bash
cgx -b ida/portal_A0.5g.frd
```

## Performance Benchmarks

Approximate execution times (depends on hardware):

| Component | Time | Notes |
|-----------|------|-------|
| Input generation | 1-2 min | For 10 amplitudes |
| Single analysis | 2-5 min | H=3m, 4000 increments |
| Complete IDA | 20-50 min | 10 amplitudes |
| Results extraction | < 1 min | All files |
| Plot generation | < 1 min | All plots |

**Total workflow time**: ~30-60 minutes for full IDA

## Dependencies

### Required

- **CalculiX 2.21** (or compatible version)
- **Python 3.6+**
- **Bash shell**

### Python Packages

- `matplotlib` (for plotting)
- `numpy` (for numerical operations)

Install with:
```bash
pip install matplotlib numpy
```

Or using system packages:
```bash
sudo apt-get install python3-matplotlib python3-numpy
```

## References

### Problema 4 Specifications

Based on "Tarea3_DC_2015" structural dynamics assignment:
- Single-story portal frame
- Seismic IDA until collapse
- Chilean seismic code (NCh433) performance requirements

### IDA Methodology

- Vamvatsikos, D., & Cornell, C. A. (2002). "Incremental dynamic analysis."
  *Earthquake Engineering & Structural Dynamics*, 31(3), 491-514.

### CalculiX Documentation

- CalculiX CrunchiX User's Manual v2.21
- Spring element nonlinear behavior
- Dynamic analysis with damping

## Support and Feedback

For issues or questions:

1. Check troubleshooting section above
2. Review log files in `ida/logs/`
3. Consult CalculiX documentation
4. Open issue in repository

## License

This IDA suite is part of the CalculiX testing framework and follows the same license.

---

**Last Updated**: 2025-12-23
**Version**: 1.0
**Author**: CalculiX Testing Framework
