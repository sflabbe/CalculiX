#!/bin/bash
#
# Generate IDA (Incremental Dynamic Analysis) test suite for Problema 4
# Creates earthquake signals and CalculiX inputs for amplitudes from 0.1g to 1.0g
#
# Usage:
#   bash generate_ida_suite.sh [--start 0.1] [--end 1.0] [--step 0.1]
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Default IDA parameters
START_A=0.1
END_A=1.0
STEP_A=0.1

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
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
            echo "Usage: $0 [--start 0.1] [--end 1.0] [--step 0.1]"
            exit 1
            ;;
    esac
done

# Create IDA directory
IDA_DIR="ida"
mkdir -p "$IDA_DIR"

echo "========================================"
echo "Generating IDA Suite for Problema 4"
echo "========================================"
echo "Amplitude range: ${START_A}g to ${END_A}g (step ${STEP_A}g)"
echo "Output directory: $IDA_DIR/"
echo ""

# Generate amplitude array using awk for floating point arithmetic
AMPLITUDES=($(awk -v start="$START_A" -v end="$END_A" -v step="$STEP_A" '
BEGIN {
    for (a = start; a <= end + 1e-9; a += step) {
        printf "%.1f\n", a
    }
}'))

echo "Amplitudes to generate: ${AMPLITUDES[@]}"
echo ""

# Counter for progress
TOTAL=${#AMPLITUDES[@]}
COUNT=0

for A in "${AMPLITUDES[@]}"; do
    COUNT=$((COUNT + 1))
    echo "[$COUNT/$TOTAL] Generating files for A = ${A}g..."

    # Step 1: Generate earthquake signal
    echo "  [1/2] Generating earthquake signal..."
    python3 generate_earthquake_senoidal.py \
        --A "$A" \
        --dt 0.0025 \
        --duration 10.0 \
        --units g \
        --out "$IDA_DIR/earthquake_A${A}g.csv" > /dev/null 2>&1

    # Step 2: Generate CalculiX input
    echo "  [2/2] Generating CalculiX input..."
    python3 generate_portal_eq_ccx.py \
        --eq "$IDA_DIR/earthquake_A${A}g.csv" \
        --out "$IDA_DIR/portal_A${A}g.inp" \
        --H 3.0 \
        --L 5.0 \
        --col_b 0.40 \
        --col_h 0.60 \
        --beam_b 0.25 \
        --beam_h 0.50 > /dev/null 2>&1

    echo "  ✓ Generated: portal_A${A}g.inp, earthquake_A${A}g.csv, hinge_map.json"
done

echo ""
echo "========================================"
echo "IDA Suite Generation Complete!"
echo "========================================"
echo "Generated $TOTAL test cases in $IDA_DIR/"
echo ""
echo "Files created:"
ls -lh "$IDA_DIR"/*.inp 2>/dev/null | awk '{printf "  %s  %s\n", $9, $5}'
echo ""
echo "Next steps:"
echo "  1. Run IDA analysis: bash run_ida_analysis.sh"
echo "  2. Extract results:  python3 extract_ida_results.py"
echo "  3. Generate plots:   python3 plot_ida_validation.py"
echo ""
