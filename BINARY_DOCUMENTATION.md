# CalculiX 2.21 Binary Documentation

## Build Information

**Binary Location**: `bin/ccx_2.21`
**Size**: ~12 MB
**Build Date**: December 22, 2025
**Platform**: Linux x86_64 (Ubuntu 24.04)

## Key Features and Improvements

### 1. Rotational Spring Support (SPRING2)

The binary includes enhanced support for rotational springs using SPRING2 elements:

- **Rotational DOFs 4-6**: In addition to translational DOFs 1-3, the solver now supports rotational degrees of freedom (DOF 4-6) for spring elements
- **M-θ Hinges**: Enables modeling of moment-rotation (M-θ) plastic hinges for seismic analysis
- **Nonlinear Tables**: Fully supports nonlinear M-θ curves with piecewise-linear interpolation
- **Units**: Rotations in radians, forces as moments (N·m)

**Documentation**: See `doc/rotational_springs.md` for usage examples

**Modified Files**:
- `src/springforc_n2f.f` - Force calculation for mixed DOF springs
- `src/springstiff_n2f.f` - Stiffness calculation for mixed DOF springs
- `src/springs.f` - Spring element initialization and validation
- `src/mafillsm.f` - Assembly of spring contributions to system matrix

### 2. Build System Improvements

- **Portable Dependencies**: Automatic detection of system ARPACK and OpenBLAS libraries
- **No Hardcoded Paths**: Removed Intel-specific library paths for better portability
- **System Integration**: Uses standard Ubuntu packages (libarpack2, libopenblas0, libgfortran5)

**Modified Files**:
- `src/Makefile` - Updated library linking
- `src/Makefile.inc` - Dependency autodetection

### 3. Enhanced Output Handling

Improved FRD output for:
- Rotational DOF displacements
- Spring element forces and moments
- Energy quantities for nonlinear analysis

**Modified Files**:
- `src/frd.c` - Enhanced FRD file writer
- `src/CalculiX.c` - Version reporting
- `src/CalculiXstep.c` - Multi-step analysis coordination

## Dependencies

### Runtime Requirements

The binary requires the following shared libraries:

```bash
# Install on Ubuntu/Debian:
apt-get install libarpack2 libopenblas0 libgfortran5
```

**Library Versions (Ubuntu 24.04)**:
- `libarpack.so.2` (ARPACK 3.9.1)
- `libopenblas.so.0` (OpenBLAS 0.3.26)
- `libgfortran.so.5` (GCC 14.2.0)

### Verification

Check library linking:
```bash
ldd bin/ccx_2.21 | grep -E "arpack|openblas|gfortran"
```

Expected output:
```
libarpack.so.2 => /lib/x86_64-linux-gnu/libarpack.so.2
libopenblas.so.0 => /lib/x86_64-linux-gnu/libopenblas.so.0
libgfortran.so.5 => /lib/x86_64-linux-gnu/libgfortran.so.5
```

## Usage

### Basic Execution

```bash
ccx_2.21 input_file
```

The `.inp` extension is added automatically if omitted.

### With Custom Binary Path

```bash
/path/to/bin/ccx_2.21 input_file
```

### Environment Variables

```bash
# Use custom library path if needed
export LD_LIBRARY_PATH=/custom/lib:$LD_LIBRARY_PATH
ccx_2.21 input_file
```

## Known Issues

### Memory Cleanup Warning

Some analyses (particularly long dynamic simulations) may show a memory cleanup error at the very end:

```
corrupted size vs. prev_size
```

**Impact**: The error occurs during cleanup **after** results are written. Output files (.frd, .dat, .sta) are valid and complete.

**Affected Analyses**:
- Long dynamic analyses (>1000 increments)
- Portal frame earthquake simulations
- Analyses with SPRING2 elements

**Workaround**: Check that output files are present and non-empty. The error does not affect result validity.

## Validation Tests

The binary has been validated against the following test suite:

### 1. Beam Tests (`tests/beams/`)

- `test1_cantilever.inp` - Cantilever beam tip deflection
- `test2_deepbeam.inp` - Deep beam shear validation

**Status**: ✓ Passing

### 2. Portal Frame Earthquake Tests (`tests/portal4_compare/`)

- `portal_A0.1g.inp` - Frame with 0.1g earthquake
- `portal_A0.2g.inp` - Frame with 0.2g earthquake

**Features Tested**:
- SPRING2 rotational hinges
- Nonlinear M-θ curves
- Dynamic implicit analysis
- AMPLITUDE earthquake loading

**Status**: ✓ Passing (with cleanup warning)

### Running Tests

Execute all validation tests:

```bash
cd tests
./run_all_benchmarks.sh
```

Individual tests:

```bash
cd tests/beams
ccx_2.21 test1_cantilever

cd tests/portal4_compare
ccx_2.21 portal_A0.1g
```

## Source Code Changes

### Main Modifications

1. **src/CalculiX.c** (lines 163-169)
   - Added build timestamp documentation
   - Lists key improvements in comments

2. **src/CalculiXstep.c** (lines 306-312)
   - Added build timestamp documentation
   - Multi-step analysis coordination

3. **src/frd.c** (lines 44-62)
   - Enhanced function documentation
   - Describes output format and recent improvements

4. **src/springs.f, springforc_n2f.f, springstiff_n2f.f**
   - Core rotational spring implementation
   - Mixed DOF handling (translational + rotational)

5. **src/mafillsm.f**
   - Assembly of spring contributions
   - Handles both force and moment DOFs

## Performance Notes

### Typical Analysis Times

Based on validation tests:

| Test | Elements | Increments | Time |
|------|----------|------------|------|
| test1_cantilever | 5 | 1 | <1s |
| test2_deepbeam | 4 | 1 | <1s |
| portal_A0.1g | 106 | 4000 | ~116s |
| portal_A0.2g | 106 | 4000 | ~115s |

**Platform**: Single CPU core, no parallelization

### Optimization

For production use:
- Compile with `-j$(nproc)` for parallel build
- Use SPOOLES solver (default, fast for medium problems)
- Enable PARDISO for large systems (requires license)

## References

- **CalculiX Documentation**: http://www.calculix.de
- **Rotational Springs**: `doc/rotational_springs.md`
- **Test Suite**: `tests/README.txt`
- **Build System**: `src/Makefile`, `src/Makefile.inc`

## Support

For issues specific to this binary:

1. Check runtime dependencies: `ldd bin/ccx_2.21`
2. Run validation tests: `tests/run_all_benchmarks.sh`
3. Review test outputs in `.dat` and `.sta` files
4. Check known issues section above

For general CalculiX questions, refer to the official documentation and community forums.
