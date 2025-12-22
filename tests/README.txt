CalculiX Test Suite
===================

This directory contains validation tests and benchmarks for CalculiX.

Test Categories:
----------------

1. beams/
   - Beam patch regression tests (B32R elements)
   - test1_cantilever.inp: Simple cantilever beam validation
   - test2_deepbeam.inp: Deep beam shear validation

2. portal4_compare/
   - Portal frame earthquake benchmark (Problema 4)
   - Canonical test generator: generate_portal_eq_ccx.py
   - Pre-generated tests: portal_A0.1g.inp, portal_A0.2g.inp
   - See portal4_compare/README_PROBLEMA4.md for full documentation

3. beam_patch/
   - Additional beam element patch tests

4. rot_spring2/
   - Rotational spring validation tests

Running Tests:
--------------
Use the unified test runner:
  bash run_all_benchmarks.sh

Or run individual tests with:
  ccx_2.21 -i test_name

Binary Location:
----------------
bin/ccx_2.21 (CalculiX 2.21 with impact simulation improvements)
