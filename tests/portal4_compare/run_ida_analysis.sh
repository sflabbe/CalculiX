#!/bin/bash
#
# Run IDA (Incremental Dynamic Analysis) for Problema 4
# Executes all amplitudes sequentially and monitors for collapse
#
# Collapse criterion: Drift > 5% (|u_roof| > 15cm for H=3m)
#
# Usage:
#   bash run_ida_analysis.sh [--ccx /path/to/ccx] [--start 0.1] [--end 1.0] [--step 0.1]
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Default parameters
CCX_EXEC="${CCX:-../../../bin/ccx_2.21}"
IDA_DIR="ida"
START_A=0.1
END_A=1.0
STEP_A=0.1

# Collapse criteria
H_m=3.0  # Column height in meters
COLLAPSE_DRIFT_PCT=5.0  # 5% drift
COLLAPSE_U_cm=$(awk "BEGIN {printf \"%.1f\", $H_m * 100 * $COLLAPSE_DRIFT_PCT / 100}")

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --ccx)
            CCX_EXEC="$2"
            shift 2
            ;;
        --start)
            START_A="$2"
            shift 2
            ;;
        --end)
            END_A="$2"
            shift 2
            ;;
        --step)
            STEP_A="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--ccx /path/to/ccx] [--start 0.1] [--end 1.0] [--step 0.1]"
            exit 1
            ;;
    esac
done

# Check if CCX exists
if [ ! -x "$CCX_EXEC" ]; then
    echo "ERROR: CalculiX executable not found: $CCX_EXEC"
    echo "Please specify with --ccx or set CCX environment variable"
    exit 1
fi

# Check if IDA directory exists
if [ ! -d "$IDA_DIR" ]; then
    echo "ERROR: IDA directory not found: $IDA_DIR"
    echo "Please run generate_ida_suite.sh first"
    exit 1
fi

# Create log directory
LOG_DIR="$IDA_DIR/logs"
mkdir -p "$LOG_DIR"

LOG_FILE="$LOG_DIR/ida_run.log"
SUMMARY_FILE="$IDA_DIR/ida_summary.txt"

echo "========================================" | tee "$LOG_FILE"
echo "IDA Analysis for Problema 4" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"
echo "Start: $(date)" | tee -a "$LOG_FILE"
echo "CCX:   $CCX_EXEC" | tee -a "$LOG_FILE"
echo "Range: ${START_A}g to ${END_A}g (step ${STEP_A}g)" | tee -a "$LOG_FILE"
echo "Collapse criterion: drift > ${COLLAPSE_DRIFT_PCT}% (|u| > ${COLLAPSE_U_cm} cm)" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Generate amplitude array
AMPLITUDES=($(awk -v start="$START_A" -v end="$END_A" -v step="$STEP_A" '
BEGIN {
    for (a = start; a <= end + 1e-9; a += step) {
        printf "%.1f\n", a
    }
}'))

# Initialize summary file
echo "# IDA Summary - Problema 4" > "$SUMMARY_FILE"
echo "# Generated: $(date)" >> "$SUMMARY_FILE"
echo "# Collapse criterion: drift > ${COLLAPSE_DRIFT_PCT}% (|u| > ${COLLAPSE_U_cm} cm)" >> "$SUMMARY_FILE"
echo "#" >> "$SUMMARY_FILE"
echo "# Amplitude_g  Status  Peak_Drift_cm  Peak_Drift_pct  Runtime_s  Exit_Code" >> "$SUMMARY_FILE"

TOTAL=${#AMPLITUDES[@]}
COUNT=0
COLLAPSE_DETECTED=false
COLLAPSE_AMPLITUDE=""

for A in "${AMPLITUDES[@]}"; do
    COUNT=$((COUNT + 1))

    if [ "$COLLAPSE_DETECTED" = true ]; then
        echo "[$COUNT/$TOTAL] Skipping A = ${A}g (collapse already detected at ${COLLAPSE_AMPLITUDE}g)" | tee -a "$LOG_FILE"
        echo "${A}  SKIPPED  -  -  -  -" >> "$SUMMARY_FILE"
        continue
    fi

    echo "" | tee -a "$LOG_FILE"
    echo "[$COUNT/$TOTAL] Running A = ${A}g..." | tee -a "$LOG_FILE"

    BASE="portal_A${A}g"
    INP_FILE="$IDA_DIR/${BASE}.inp"

    if [ ! -f "$INP_FILE" ]; then
        echo "  ERROR: Input file not found: $INP_FILE" | tee -a "$LOG_FILE"
        echo "${A}  ERROR  -  -  -  -" >> "$SUMMARY_FILE"
        continue
    fi

    # Clean old outputs
    cd "$IDA_DIR"
    rm -f "${BASE}".{dat,frd,sta,cvg,12d} 2>/dev/null || true

    # Run CalculiX with timeout (max 10 minutes per analysis)
    echo "  Running CalculiX..." | tee -a "../$LOG_FILE"

    START_TIME=$(date +%s)
    set +e
    timeout 600 "$CCX_EXEC" -i "$BASE" > "$LOG_DIR/${BASE}.ccx.log" 2>&1
    CCX_RC=$?
    set -e
    END_TIME=$(date +%s)
    RUNTIME=$((END_TIME - START_TIME))

    # Check exit code
    if [ $CCX_RC -eq 124 ]; then
        echo "  ERROR: Timeout after 600s (likely divergence/collapse)" | tee -a "../$LOG_FILE"
        echo "${A}  TIMEOUT  -  -  ${RUNTIME}  ${CCX_RC}" >> "../$SUMMARY_FILE"
        COLLAPSE_DETECTED=true
        COLLAPSE_AMPLITUDE=$A
        cd ..
        continue
    elif [ $CCX_RC -ne 0 ]; then
        echo "  WARNING: CCX exited with code $CCX_RC" | tee -a "../$LOG_FILE"
        STATUS="FAILED"
    else
        echo "  ✓ CCX completed (${RUNTIME}s)" | tee -a "../$LOG_FILE"
        STATUS="OK"
    fi

    # Check if .dat file was generated
    if [ ! -f "${BASE}.dat" ]; then
        echo "  ERROR: No .dat file generated" | tee -a "../$LOG_FILE"
        echo "${A}  NO_DAT  -  -  ${RUNTIME}  ${CCX_RC}" >> "../$SUMMARY_FILE"
        cd ..
        continue
    fi

    # Extract peak displacement (quick check using grep/awk)
    # Look for node displacements in .dat file
    # This is a simplified approach - we'll do proper extraction later
    echo "  Checking for collapse..." | tee -a "../$LOG_FILE"

    # Find peak displacement from .dat file (U1 direction - horizontal)
    # The .dat file format varies, so we'll use a Python script for proper extraction
    cd ..
    PEAK_U=$(python3 -c "
import sys
import re

dat_file = 'ida/${BASE}.dat'
peak_u = 0.0

try:
    with open(dat_file, 'r') as f:
        in_displ_section = False
        for line in f:
            # Look for displacement output sections
            if 'displacements (vx,vy,vz) for set' in line.lower():
                in_displ_section = True
                continue

            # Check for numeric data lines when in displacement section
            if in_displ_section:
                # Line format: node_id  U1  U2  U3  ...
                match = re.match(r'^\s*\d+\s+([-+]?\d+\.\d+[eE]?[-+]?\d*)\s+([-+]?\d+\.\d+[eE]?[-+]?\d*)', line)
                if match:
                    u1 = abs(float(match.group(1)))
                    if u1 > peak_u:
                        peak_u = u1
                elif line.strip() == '' or 'time' in line.lower():
                    in_displ_section = False

except Exception as e:
    print(f'0.0  # Error: {e}', file=sys.stderr)
    sys.exit(1)

print(f'{peak_u * 100:.3f}')  # Convert m to cm
" 2>/dev/null || echo "0.0")

    PEAK_DRIFT_PCT=$(awk -v u="$PEAK_U" -v h="$H_m" 'BEGIN {printf "%.2f", (u/100) / h * 100}')

    echo "  Peak displacement: ${PEAK_U} cm (drift = ${PEAK_DRIFT_PCT}%)" | tee -a "$LOG_FILE"

    # Check collapse criterion
    COLLAPSED=$(awk -v drift="$PEAK_DRIFT_PCT" -v crit="$COLLAPSE_DRIFT_PCT" 'BEGIN {if (drift > crit) print "YES"; else print "NO"}')

    if [ "$COLLAPSED" = "YES" ]; then
        echo "  ⚠ COLLAPSE DETECTED! Drift ${PEAK_DRIFT_PCT}% > ${COLLAPSE_DRIFT_PCT}%" | tee -a "$LOG_FILE"
        STATUS="COLLAPSE"
        COLLAPSE_DETECTED=true
        COLLAPSE_AMPLITUDE=$A
    fi

    # Record to summary
    echo "${A}  ${STATUS}  ${PEAK_U}  ${PEAK_DRIFT_PCT}  ${RUNTIME}  ${CCX_RC}" >> "$SUMMARY_FILE"

done

echo "" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"
echo "IDA Analysis Complete!" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"
echo "End: $(date)" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

if [ "$COLLAPSE_DETECTED" = true ]; then
    echo "Collapse detected at A = ${COLLAPSE_AMPLITUDE}g" | tee -a "$LOG_FILE"
else
    echo "No collapse detected up to A = ${END_A}g" | tee -a "$LOG_FILE"
    echo "Consider extending IDA range or checking model" | tee -a "$LOG_FILE"
fi

echo "" | tee -a "$LOG_FILE"
echo "Results:" | tee -a "$LOG_FILE"
echo "  Summary:  $SUMMARY_FILE" | tee -a "$LOG_FILE"
echo "  Outputs:  $IDA_DIR/*.dat, *.frd" | tee -a "$LOG_FILE"
echo "  Logs:     $LOG_DIR/*.log" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
cat "$SUMMARY_FILE" | tee -a "$LOG_FILE"
echo ""

echo "Next steps:" | tee -a "$LOG_FILE"
echo "  1. Extract detailed results: python3 extract_ida_results.py" | tee -a "$LOG_FILE"
echo "  2. Generate plots:          python3 plot_ida_validation.py" | tee -a "$LOG_FILE"
echo "  3. Create report:           (validation report will be generated)" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
