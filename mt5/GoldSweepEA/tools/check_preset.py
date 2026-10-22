#!/usr/bin/env python3
"""Ensures the .set preset matches the EA input defaults (no drift)."""
import re
from pathlib import Path

SRC = Path(__file__).resolve().parent.parent / "Experts" / "GoldSweepEA.mq5"
SET = Path(__file__).resolve().parent.parent / "Presets" / "GoldSweepEA_XAUUSD_M15.set"

ENUMS = {
    "GS_RISK_PERCENT": "0", "GS_RISK_FIXED_LOT": "1",
    "GS_SCOPE_EA": "0", "GS_SCOPE_ACCOUNT": "1",
    "GS_FILL_AUTO": "0", "GS_FILL_FOK": "1", "GS_FILL_IOC": "2", "GS_FILL_RETURN": "3",
    "PERIOD_M15": "15", "PERIOD_H1": "16385",
}


def main() -> int:
    src = SRC.read_text(encoding="utf-8")
    inputs = re.findall(r'^\s*input\s+(?!group)([A-Za-z_]\w*)\s+([A-Za-z_]\w*)\s*=\s*([^;]+);', src, re.M)
    defaults = {}
    for _typ, name, val in inputs:
        val = val.strip()
        defaults[name] = ENUMS.get(val, val)

    preset = {}
    for line in SET.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith(";") or "=" not in line:
            continue
        name, rest = line.split("=", 1)
        preset[name.strip()] = rest.split("||")[0].strip()

    errors = []
    for name, val in defaults.items():
        if name not in preset:
            errors.append(f"missing in preset: {name}")
        elif preset[name].lower() != val.lower():
            errors.append(f"value mismatch {name}: EA={val} preset={preset[name]}")
    for name in preset:
        if name not in defaults:
            errors.append(f"unknown preset key: {name}")

    print(f"inputs={len(defaults)} preset={len(preset)} errors={len(errors)}")
    for err in errors:
        print(" -", err)
    print("PRESET CHECK:", "PASS" if not errors else "FAIL")
    return 0 if not errors else 1


if __name__ == "__main__":
    raise SystemExit(main())
