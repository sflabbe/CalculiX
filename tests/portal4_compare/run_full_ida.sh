#!/bin/bash
#
# Master script to run complete IDA workflow for Problema 4
#
# This script:
# 1. Generates IDA test suite (earthquake signals + CCX inputs)
# 2. Runs all IDA analyses sequentially
# 3. Extracts results to CSV
# 4. Generates validation plots
# 5. Creates validation report
#
# Usage:
#   bash run_full_ida.sh [--start 0.1] [--end 1.0] [--step 0.1] [--ccx /path/to/ccx]
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Default parameters
START_A=0.1
END_A=1.0
STEP_A=0.1
CCX_EXEC="${CCX:-../../bin/ccx_2.21}"

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
        --ccx)
            CCX_EXEC="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --start A   Starting amplitude (default: 0.1)"
            echo "  --end A     Ending amplitude (default: 1.0)"
            echo "  --step A    Amplitude step (default: 0.1)"
            echo "  --ccx PATH  Path to CalculiX executable (default: ../../bin/ccx_2.21)"
            echo "  -h, --help  Show this help message"
            echo ""
            echo "Example:"
            echo "  $0 --start 0.1 --end 0.8 --step 0.1"
            echo ""
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

MASTER_LOG="ida_master.log"

echo "========================================" | tee "$MASTER_LOG"
echo "IDA Complete Workflow - Problema 4" | tee -a "$MASTER_LOG"
echo "========================================" | tee -a "$MASTER_LOG"
echo "Start time: $(date)" | tee -a "$MASTER_LOG"
echo "" | tee -a "$MASTER_LOG"
echo "Parameters:" | tee -a "$MASTER_LOG"
echo "  Amplitude range: ${START_A}g to ${END_A}g (step ${STEP_A}g)" | tee -a "$MASTER_LOG"
echo "  CalculiX:        $CCX_EXEC" | tee -a "$MASTER_LOG"
echo "" | tee -a "$MASTER_LOG"

# Check CCX
if [ ! -x "$CCX_EXEC" ]; then
    echo "ERROR: CalculiX executable not found or not executable: $CCX_EXEC" | tee -a "$MASTER_LOG"
    echo "Please specify with --ccx or check installation" | tee -a "$MASTER_LOG"
    exit 1
fi

echo "CalculiX version:" | tee -a "$MASTER_LOG"
"$CCX_EXEC" 2>&1 | head -5 | tee -a "$MASTER_LOG"
echo "" | tee -a "$MASTER_LOG"

# ============================================
# Step 1: Generate IDA test suite
# ============================================
echo "[1/5] Generating IDA test suite..." | tee -a "$MASTER_LOG"
echo "" | tee -a "$MASTER_LOG"

bash generate_ida_suite.sh --start "$START_A" --end "$END_A" --step "$STEP_A" 2>&1 | tee -a "$MASTER_LOG"

if [ ! -d "ida" ] || [ -z "$(ls -A ida/*.inp 2>/dev/null)" ]; then
    echo "ERROR: IDA suite generation failed" | tee -a "$MASTER_LOG"
    exit 1
fi

echo "" | tee -a "$MASTER_LOG"
echo "✓ IDA suite generated successfully" | tee -a "$MASTER_LOG"
echo "" | tee -a "$MASTER_LOG"

# ============================================
# Step 2: Run IDA analyses
# ============================================
echo "[2/5] Running IDA analyses..." | tee -a "$MASTER_LOG"
echo "" | tee -a "$MASTER_LOG"

bash run_ida_analysis.sh --ccx "$CCX_EXEC" --start "$START_A" --end "$END_A" --step "$STEP_A" 2>&1 | tee -a "$MASTER_LOG"

echo "" | tee -a "$MASTER_LOG"
echo "✓ IDA analyses completed" | tee -a "$MASTER_LOG"
echo "" | tee -a "$MASTER_LOG"

# ============================================
# Step 3: Extract results
# ============================================
echo "[3/5] Extracting results..." | tee -a "$MASTER_LOG"
echo "" | tee -a "$MASTER_LOG"

python3 extract_ida_results.py --ida-dir ida --start "$START_A" --end "$END_A" --step "$STEP_A" 2>&1 | tee -a "$MASTER_LOG"

if [ ! -f "ida/ida_results_summary.csv" ]; then
    echo "ERROR: Results extraction failed" | tee -a "$MASTER_LOG"
    exit 1
fi

echo "" | tee -a "$MASTER_LOG"
echo "✓ Results extracted successfully" | tee -a "$MASTER_LOG"
echo "" | tee -a "$MASTER_LOG"

# ============================================
# Step 4: Generate plots
# ============================================
echo "[4/5] Generating validation plots..." | tee -a "$MASTER_LOG"
echo "" | tee -a "$MASTER_LOG"

python3 plot_ida_validation.py --ida-dir ida 2>&1 | tee -a "$MASTER_LOG"

if [ ! -d "ida/plots" ] || [ -z "$(ls -A ida/plots/*.png 2>/dev/null)" ]; then
    echo "ERROR: Plot generation failed" | tee -a "$MASTER_LOG"
    exit 1
fi

echo "" | tee -a "$MASTER_LOG"
echo "✓ Plots generated successfully" | tee -a "$MASTER_LOG"
echo "" | tee -a "$MASTER_LOG"

# ============================================
# Step 5: Generate validation report
# ============================================
echo "[5/5] Generating validation report..." | tee -a "$MASTER_LOG"
echo "" | tee -a "$MASTER_LOG"

python3 generate_ida_report.py --ida-dir ida --output ida/IDA_VALIDATION_REPORT.md 2>&1 | tee -a "$MASTER_LOG"

if [ ! -f "ida/IDA_VALIDATION_REPORT.md" ]; then
    echo "ERROR: Report generation failed" | tee -a "$MASTER_LOG"
    exit 1
fi

echo "" | tee -a "$MASTER_LOG"
echo "✓ Validation report generated" | tee -a "$MASTER_LOG"
echo "" | tee -a "$MASTER_LOG"

# ============================================
# Summary
# ============================================
echo "========================================" | tee -a "$MASTER_LOG"
echo "IDA WORKFLOW COMPLETE!" | tee -a "$MASTER_LOG"
echo "========================================" | tee -a "$MASTER_LOG"
echo "End time: $(date)" | tee -a "$MASTER_LOG"
echo "" | tee -a "$MASTER_LOG"

echo "Output files:" | tee -a "$MASTER_LOG"
echo "" | tee -a "$MASTER_LOG"
echo "📁 ida/" | tee -a "$MASTER_LOG"
echo "   ├── portal_A*.inp              (CalculiX input files)" | tee -a "$MASTER_LOG"
echo "   ├── portal_A*.dat              (CalculiX output files)" | tee -a "$MASTER_LOG"
echo "   ├── portal_A*.frd              (Results for visualization)" | tee -a "$MASTER_LOG"
echo "   ├── ida_results_summary.csv    (Summary data)" | tee -a "$MASTER_LOG"
echo "   ├── IDA_VALIDATION_REPORT.md   (Validation report)" | tee -a "$MASTER_LOG"
echo "   ├── plots/*.png                (Validation plots)" | tee -a "$MASTER_LOG"
echo "   └── logs/*.log                 (Analysis logs)" | tee -a "$MASTER_LOG"
echo "" | tee -a "$MASTER_LOG"

# Display key results
if [ -f "ida/ida_summary.txt" ]; then
    echo "Key Results:" | tee -a "$MASTER_LOG"
    echo "" | tee -a "$MASTER_LOG"
    cat ida/ida_summary.txt | tail -10 | tee -a "$MASTER_LOG"
    echo "" | tee -a "$MASTER_LOG"
fi

echo "Next steps:" | tee -a "$MASTER_LOG"
echo "  1. Review validation report: ida/IDA_VALIDATION_REPORT.md" | tee -a "$MASTER_LOG"
echo "  2. Check plots:              ida/plots/" | tee -a "$MASTER_LOG"
echo "  3. Analyze results CSV:      ida/ida_results_summary.csv" | tee -a "$MASTER_LOG"
echo "" | tee -a "$MASTER_LOG"

echo "🎉 All done!" | tee -a "$MASTER_LOG"
echo "" | tee -a "$MASTER_LOG"
