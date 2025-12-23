#!/usr/bin/env python3
"""
Generate IDA validation plots for Problema 4.

Creates:
1. IDA Curve (drift vs amplitude)
2. Drift time histories (multiple amplitudes overlaid)
3. M-θ hysteresis curves (selected amplitudes)
4. Plastic rotation accumulation
5. Base shear vs drift
6. Energy dissipation vs amplitude

Usage:
    python3 plot_ida_validation.py [--ida-dir ida] [--output-dir ida/plots]
"""

import argparse
import csv
import json
import sys
from pathlib import Path
from typing import Dict, List, Tuple
import re

try:
    import numpy as np
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    from matplotlib.gridspec import GridSpec
except ImportError:
    print("ERROR: matplotlib and numpy are required")
    print("Install with: pip install matplotlib numpy")
    sys.exit(1)


def read_summary_csv(csv_path: Path) -> List[Dict]:
    """Read IDA summary CSV file."""
    results = []

    with open(csv_path, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            results.append(row)

    return results


def parse_dat_displacements(dat_path: Path) -> Tuple[np.ndarray, Dict]:
    """
    Parse displacement time histories from .dat file.

    Returns:
        - time array
        - dict {node_id: array of (U1, U2, U3) for each time step}
    """
    time_steps = []
    displacements = {}

    current_time = 0.0
    in_displ_section = False

    with open(dat_path, 'r') as f:
        for line in f:
            # Look for time
            time_match = re.search(r'time\s+(\d+\.\d+[eE]?[+-]?\d*)', line, re.IGNORECASE)
            if time_match:
                current_time = float(time_match.group(1))
                if current_time not in time_steps:
                    time_steps.append(current_time)

            # Displacement section
            if 'displacements (vx,vy,vz) for set' in line.lower():
                in_displ_section = True
                continue

            if line.strip() == '' or line.startswith('*'):
                in_displ_section = False

            if in_displ_section:
                match = re.match(r'^\s*(\d+)\s+([-+]?\d+\.\d+[eE]?[-+]?\d*)\s+([-+]?\d+\.\d+[eE]?[-+]?\d*)\s+([-+]?\d+\.\d+[eE]?[-+]?\d*)', line)
                if match:
                    node_id = int(match.group(1))
                    u1 = float(match.group(2))
                    u2 = float(match.group(3))
                    u3 = float(match.group(4))

                    if node_id not in displacements:
                        displacements[node_id] = []
                    displacements[node_id].append((u1, u2, u3))

    return np.array(time_steps), displacements


def plot_ida_curve(results: List[Dict], output_dir: Path, hinge_map: Dict):
    """Plot IDA curve (peak drift vs amplitude)."""
    amplitudes = [float(r['Amplitude_g']) for r in results]
    peak_drifts = [float(r['Peak_Drift_pct']) for r in results]
    statuses = [r['Status'] for r in results]

    # Separate OK and COLLAPSE points
    amp_ok = [a for a, s in zip(amplitudes, statuses) if s == 'OK']
    drift_ok = [d for d, s in zip(peak_drifts, statuses) if s == 'OK']

    amp_collapse = [a for a, s in zip(amplitudes, statuses) if s == 'COLLAPSE']
    drift_collapse = [d for d, s in zip(peak_drifts, statuses) if s == 'COLLAPSE']

    fig, ax = plt.subplots(figsize=(10, 8))

    # Plot data
    if amp_ok:
        ax.plot(drift_ok, amp_ok, 'o-', color='steelblue', linewidth=2,
                markersize=8, label='No collapse', zorder=3)

    if amp_collapse:
        ax.plot(drift_collapse, amp_collapse, 'o', color='red', markersize=10,
                label='Collapse', zorder=4)

    # Collapse criterion line
    ax.axvline(5.0, color='red', linestyle='--', linewidth=1.5,
               label='Collapse criterion (5% drift)', alpha=0.7, zorder=2)

    # Formatting
    ax.set_xlabel('Peak Roof Drift (%)', fontsize=13, fontweight='bold')
    ax.set_ylabel('Spectral Acceleration (g)', fontsize=13, fontweight='bold')
    ax.set_title('IDA Curve - Portal Frame Problema 4', fontsize=15, fontweight='bold')
    ax.grid(True, alpha=0.3, zorder=1)
    ax.legend(fontsize=11, loc='best')

    # Set reasonable limits
    ax.set_xlim(0, max(peak_drifts) * 1.1)
    ax.set_ylim(0, max(amplitudes) * 1.1)

    plt.tight_layout()
    plt.savefig(output_dir / 'ida_curve.pdf', dpi=300, bbox_inches='tight')
    plt.savefig(output_dir / 'ida_curve.png', dpi=150, bbox_inches='tight')
    plt.close()

    print("  ✓ IDA curve")


def plot_drift_histories(ida_dir: Path, results: List[Dict], output_dir: Path, hinge_map: Dict):
    """Plot drift time histories for multiple amplitudes."""
    H = hinge_map.get('geometry', {}).get('H', 3.0)

    # Select representative amplitudes
    amplitudes_to_plot = [0.1, 0.2, 0.3, 0.5, 0.7, 1.0]
    available_amps = [float(r['Amplitude_g']) for r in results]
    amplitudes_to_plot = [a for a in amplitudes_to_plot if a in available_amps]

    if not amplitudes_to_plot:
        amplitudes_to_plot = available_amps[:6]  # First 6

    fig, ax = plt.subplots(figsize=(12, 7))

    colors = plt.cm.viridis(np.linspace(0, 0.9, len(amplitudes_to_plot)))

    for amp, color in zip(amplitudes_to_plot, colors):
        dat_file = ida_dir / f"portal_A{amp}g.dat"

        if not dat_file.exists():
            continue

        time, displ = parse_dat_displacements(dat_file)

        if not displ or len(time) == 0:
            continue

        # Find max U1 at each time step
        max_u1_history = []
        for i in range(len(time)):
            max_u1 = 0.0
            for node_id, u_data in displ.items():
                if i < len(u_data):
                    u1 = abs(u_data[i][0])
                    if u1 > abs(max_u1):
                        max_u1 = u_data[i][0] if u_data[i][0] > 0 else -u1

            max_u1_history.append(max_u1)

        drift_pct = (np.array(max_u1_history) / H) * 100

        # Get status
        status = next((r['Status'] for r in results if float(r['Amplitude_g']) == amp), 'OK')
        linestyle = '-' if status == 'OK' else '--'
        linewidth = 2 if status == 'COLLAPSE' else 1.5

        ax.plot(time, drift_pct, linestyle=linestyle, color=color, linewidth=linewidth,
                label=f'A = {amp}g' + (' (collapse)' if status == 'COLLAPSE' else ''))

    # Collapse criterion
    ax.axhline(5.0, color='red', linestyle='--', linewidth=1, label='Collapse limit', alpha=0.5)
    ax.axhline(-5.0, color='red', linestyle='--', linewidth=1, alpha=0.5)

    ax.set_xlabel('Time (s)', fontsize=13, fontweight='bold')
    ax.set_ylabel('Roof Drift (%)', fontsize=13, fontweight='bold')
    ax.set_title('Drift Time Histories - Multiple Amplitudes', fontsize=15, fontweight='bold')
    ax.grid(True, alpha=0.3)
    ax.legend(fontsize=10, loc='best', ncol=2)

    plt.tight_layout()
    plt.savefig(output_dir / 'drift_histories.pdf', dpi=300, bbox_inches='tight')
    plt.savefig(output_dir / 'drift_histories.png', dpi=150, bbox_inches='tight')
    plt.close()

    print("  ✓ Drift time histories")


def plot_rotation_accumulation(results: List[Dict], output_dir: Path, hinge_map: Dict):
    """Plot peak plastic rotation vs amplitude for each hinge."""
    amplitudes = [float(r['Amplitude_g']) for r in results]

    # Extract hinge names
    hinge_names = [h['name'] for h in hinge_map.get('hinges', [])]

    if not hinge_names:
        print("  Skipping rotation accumulation (no hinge data)")
        return

    fig, ax = plt.subplots(figsize=(10, 7))

    colors = ['steelblue', 'coral', 'green', 'purple']

    for i, h_name in enumerate(hinge_names):
        col_name = f'Peak_theta_{h_name}_rad'

        if col_name not in results[0]:
            continue

        peak_thetas = [float(r.get(col_name, 0.0)) for r in results]

        ax.plot(amplitudes, peak_thetas, 'o-', color=colors[i % len(colors)],
                linewidth=2, markersize=6, label=h_name)

    ax.set_xlabel('Amplitude (g)', fontsize=13, fontweight='bold')
    ax.set_ylabel('Peak Plastic Rotation (rad)', fontsize=13, fontweight='bold')
    ax.set_title('Plastic Rotation Accumulation', fontsize=15, fontweight='bold')
    ax.grid(True, alpha=0.3)
    ax.legend(fontsize=11)

    plt.tight_layout()
    plt.savefig(output_dir / 'rotation_accumulation.pdf', dpi=300, bbox_inches='tight')
    plt.savefig(output_dir / 'rotation_accumulation.png', dpi=150, bbox_inches='tight')
    plt.close()

    print("  ✓ Rotation accumulation")


def plot_base_shear_vs_drift(results: List[Dict], output_dir: Path):
    """Plot peak base shear vs peak drift."""
    peak_drifts = [float(r['Peak_Drift_pct']) for r in results]
    base_shears = [float(r['Peak_Vb_kN']) for r in results]
    statuses = [r['Status'] for r in results]

    fig, ax = plt.subplots(figsize=(10, 7))

    # Separate by status
    drift_ok = [d for d, s in zip(peak_drifts, statuses) if s == 'OK']
    shear_ok = [v for v, s in zip(base_shears, statuses) if s == 'OK']

    drift_collapse = [d for d, s in zip(peak_drifts, statuses) if s == 'COLLAPSE']
    shear_collapse = [v for v, s in zip(base_shears, statuses) if s == 'COLLAPSE']

    if drift_ok:
        ax.plot(drift_ok, shear_ok, 'o-', color='steelblue', linewidth=2,
                markersize=8, label='No collapse')

    if drift_collapse:
        ax.plot(drift_collapse, shear_collapse, 'o', color='red', markersize=10,
                label='Collapse')

    ax.axvline(5.0, color='red', linestyle='--', linewidth=1, label='Collapse limit', alpha=0.5)

    ax.set_xlabel('Peak Roof Drift (%)', fontsize=13, fontweight='bold')
    ax.set_ylabel('Peak Base Shear (kN)', fontsize=13, fontweight='bold')
    ax.set_title('Base Shear vs. Drift', fontsize=15, fontweight='bold')
    ax.grid(True, alpha=0.3)
    ax.legend(fontsize=11)

    plt.tight_layout()
    plt.savefig(output_dir / 'base_shear_vs_drift.pdf', dpi=300, bbox_inches='tight')
    plt.savefig(output_dir / 'base_shear_vs_drift.png', dpi=150, bbox_inches='tight')
    plt.close()

    print("  ✓ Base shear vs drift")


def plot_energy_dissipation(results: List[Dict], output_dir: Path):
    """Plot cumulative energy dissipation vs amplitude."""
    amplitudes = [float(r['Amplitude_g']) for r in results]
    energies = [float(r['Energy_kNm']) for r in results]

    fig, ax = plt.subplots(figsize=(10, 7))

    ax.plot(amplitudes, energies, 'o-', color='darkgreen', linewidth=2, markersize=8)

    ax.set_xlabel('Amplitude (g)', fontsize=13, fontweight='bold')
    ax.set_ylabel('Energy Dissipation (kN·m)', fontsize=13, fontweight='bold')
    ax.set_title('Cumulative Energy Dissipation', fontsize=15, fontweight='bold')
    ax.grid(True, alpha=0.3)

    plt.tight_layout()
    plt.savefig(output_dir / 'energy_dissipation.pdf', dpi=300, bbox_inches='tight')
    plt.savefig(output_dir / 'energy_dissipation.png', dpi=150, bbox_inches='tight')
    plt.close()

    print("  ✓ Energy dissipation")


def create_summary_figure(results: List[Dict], output_dir: Path, hinge_map: Dict):
    """Create a comprehensive summary figure with multiple subplots."""
    fig = plt.figure(figsize=(16, 10))
    gs = GridSpec(2, 3, figure=fig, hspace=0.3, wspace=0.3)

    amplitudes = np.array([float(r['Amplitude_g']) for r in results])
    peak_drifts = np.array([float(r['Peak_Drift_pct']) for r in results])
    residual_drifts = np.array([float(r['Residual_Drift_pct']) for r in results])
    base_shears = np.array([float(r['Peak_Vb_kN']) for r in results])
    energies = np.array([float(r['Energy_kNm']) for r in results])
    statuses = [r['Status'] for r in results]

    # 1. IDA Curve
    ax1 = fig.add_subplot(gs[0, 0])
    amp_ok = amplitudes[[s == 'OK' for s in statuses]]
    drift_ok = peak_drifts[[s == 'OK' for s in statuses]]
    amp_collapse = amplitudes[[s == 'COLLAPSE' for s in statuses]]
    drift_collapse = peak_drifts[[s == 'COLLAPSE' for s in statuses]]

    if len(amp_ok) > 0:
        ax1.plot(drift_ok, amp_ok, 'o-', color='steelblue', linewidth=2, markersize=6)
    if len(amp_collapse) > 0:
        ax1.plot(drift_collapse, amp_collapse, 'o', color='red', markersize=8)
    ax1.axvline(5.0, color='red', linestyle='--', linewidth=1, alpha=0.5)
    ax1.set_xlabel('Peak Drift (%)', fontweight='bold')
    ax1.set_ylabel('Amplitude (g)', fontweight='bold')
    ax1.set_title('IDA Curve', fontweight='bold')
    ax1.grid(True, alpha=0.3)

    # 2. Peak vs Residual Drift
    ax2 = fig.add_subplot(gs[0, 1])
    ax2.plot(amplitudes, peak_drifts, 'o-', color='steelblue', linewidth=2, label='Peak', markersize=6)
    ax2.plot(amplitudes, residual_drifts, 's-', color='coral', linewidth=2, label='Residual', markersize=6)
    ax2.axhline(5.0, color='red', linestyle='--', linewidth=1, alpha=0.5)
    ax2.set_xlabel('Amplitude (g)', fontweight='bold')
    ax2.set_ylabel('Drift (%)', fontweight='bold')
    ax2.set_title('Peak & Residual Drift', fontweight='bold')
    ax2.legend()
    ax2.grid(True, alpha=0.3)

    # 3. Base Shear vs Drift
    ax3 = fig.add_subplot(gs[0, 2])
    if len(drift_ok) > 0:
        shear_ok = base_shears[[s == 'OK' for s in statuses]]
        ax3.plot(drift_ok, shear_ok, 'o-', color='green', linewidth=2, markersize=6)
    ax3.axvline(5.0, color='red', linestyle='--', linewidth=1, alpha=0.5)
    ax3.set_xlabel('Peak Drift (%)', fontweight='bold')
    ax3.set_ylabel('Base Shear (kN)', fontweight='bold')
    ax3.set_title('Base Shear vs Drift', fontweight='bold')
    ax3.grid(True, alpha=0.3)

    # 4. Energy Dissipation
    ax4 = fig.add_subplot(gs[1, 0])
    ax4.plot(amplitudes, energies, 'o-', color='darkgreen', linewidth=2, markersize=6)
    ax4.set_xlabel('Amplitude (g)', fontweight='bold')
    ax4.set_ylabel('Energy (kN·m)', fontweight='bold')
    ax4.set_title('Energy Dissipation', fontweight='bold')
    ax4.grid(True, alpha=0.3)

    # 5. Status Distribution
    ax5 = fig.add_subplot(gs[1, 1])
    status_counts = {}
    for s in statuses:
        status_counts[s] = status_counts.get(s, 0) + 1

    colors_map = {'OK': 'steelblue', 'COLLAPSE': 'red', 'FAILED': 'orange'}
    ax5.bar(status_counts.keys(), status_counts.values(),
            color=[colors_map.get(s, 'gray') for s in status_counts.keys()])
    ax5.set_ylabel('Count', fontweight='bold')
    ax5.set_title('Analysis Status', fontweight='bold')
    ax5.grid(True, alpha=0.3, axis='y')

    # 6. Summary Table
    ax6 = fig.add_subplot(gs[1, 2])
    ax6.axis('off')

    summary_text = "Summary Statistics\n" + "="*30 + "\n\n"
    summary_text += f"Total analyses: {len(results)}\n"
    summary_text += f"Collapse count: {sum(1 for s in statuses if s == 'COLLAPSE')}\n\n"

    if any(s == 'COLLAPSE' for s in statuses):
        collapse_idx = next(i for i, s in enumerate(statuses) if s == 'COLLAPSE')
        summary_text += f"Collapse amplitude:\n  {amplitudes[collapse_idx]:.1f}g\n\n"

    summary_text += f"Max drift:\n  {max(peak_drifts):.2f}% at {amplitudes[np.argmax(peak_drifts)]:.1f}g\n\n"
    summary_text += f"Max base shear:\n  {max(base_shears):.1f} kN\n\n"
    summary_text += f"Total energy:\n  {max(energies):.1f} kN·m"

    ax6.text(0.1, 0.9, summary_text, transform=ax6.transAxes,
             fontsize=11, verticalalignment='top', family='monospace',
             bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.3))

    fig.suptitle('IDA Validation Summary - Problema 4', fontsize=16, fontweight='bold')

    plt.savefig(output_dir / 'ida_summary.pdf', dpi=300, bbox_inches='tight')
    plt.savefig(output_dir / 'ida_summary.png', dpi=150, bbox_inches='tight')
    plt.close()

    print("  ✓ Summary figure")


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--ida-dir", type=str, default="ida",
                    help="Directory containing IDA results (default: ida)")
    ap.add_argument("--output-dir", type=str, default=None,
                    help="Output directory for plots (default: ida/plots)")

    args = ap.parse_args()

    ida_dir = Path(args.ida_dir)

    if not ida_dir.exists():
        print(f"ERROR: IDA directory not found: {ida_dir}")
        sys.exit(1)

    if args.output_dir is None:
        output_dir = ida_dir / "plots"
    else:
        output_dir = Path(args.output_dir)

    output_dir.mkdir(parents=True, exist_ok=True)

    print("=" * 60)
    print("Generating IDA Validation Plots")
    print("=" * 60)
    print(f"IDA directory:    {ida_dir}")
    print(f"Output directory: {output_dir}")
    print("")

    # Read summary CSV
    summary_csv = ida_dir / "ida_results_summary.csv"

    if not summary_csv.exists():
        print(f"ERROR: Summary CSV not found: {summary_csv}")
        print("Please run extract_ida_results.py first")
        sys.exit(1)

    results = read_summary_csv(summary_csv)

    print(f"Loaded {len(results)} results from {summary_csv.name}")
    print("")

    # Read hinge map
    hinge_map = None
    for hinge_file in sorted(ida_dir.glob("*.hinge_map.json")):
        with open(hinge_file, 'r') as f:
            hinge_map = json.load(f)
        break

    if not hinge_map:
        print("Warning: No hinge_map.json found, using defaults")
        hinge_map = {'geometry': {'H': 3.0, 'L': 5.0}, 'hinges': []}

    print("Generating plots:")

    # Generate individual plots
    plot_ida_curve(results, output_dir, hinge_map)
    plot_drift_histories(ida_dir, results, output_dir, hinge_map)
    plot_rotation_accumulation(results, output_dir, hinge_map)
    plot_base_shear_vs_drift(results, output_dir)
    plot_energy_dissipation(results, output_dir)
    create_summary_figure(results, output_dir, hinge_map)

    print("")
    print("=" * 60)
    print("Plots generated successfully!")
    print("=" * 60)
    print(f"Output location: {output_dir}/")
    print("")
    print("Files created:")
    for plot_file in sorted(output_dir.glob("*.png")):
        print(f"  {plot_file.name}")
    print("")
    print("Next step: Generate validation report")
    print("")


if __name__ == '__main__':
    main()
