#!/usr/bin/env bash
# Runs every offline check available for GoldSweepEA (no MetaTrader required).
set -euo pipefail
cd "$(dirname "$0")"

echo "== 1/3 MQL5 syntax gate (C++17 stub) =="
python3 mq5_syntax_check.py

echo "== 2/3 Algorithm reference tests =="
python3 verify_algorithms.py

echo "== 3/3 Preset/defaults consistency =="
python3 check_preset.py

echo "ALL OFFLINE CHECKS PASSED"
