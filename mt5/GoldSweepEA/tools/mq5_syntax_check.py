#!/usr/bin/env python3
"""MQL5 -> C++17 syntax gate.

MQL5 cannot be compiled without MetaEditor. This tool rewrites the small set of
MQL5-only constructs used by GoldSweepEA into equivalent C++ and compiles the
result with g++ -fsyntax-only against a hand written API stub (mql5_stub.h).

It catches: syntax errors, undeclared identifiers, wrong argument counts,
type mismatches in our own code. It does NOT validate MQL5 runtime semantics.
"""
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def find_ea() -> Path:
    """Works both in the repo (../Experts) and in the downloaded MT5 package (../MQL5/Experts)."""
    for candidate in (ROOT.parent / "Experts" / "GoldSweepEA.mq5",
                      ROOT.parent / "MQL5" / "Experts" / "GoldSweepEA.mq5",
                      ROOT.parent.parent / "Experts" / "GoldSweepEA.mq5"):
        if candidate.exists():
            return candidate
    raise SystemExit("GoldSweepEA.mq5 not found next to tools/")


SRC = find_ea()
OUT = ROOT / "_build_syntax.cpp"

ARRAY_PARAM = re.compile(r'\b([A-Za-z_]\w*)\s*&\s*([A-Za-z_]\w*)\[\]')
ARRAY_DECL = re.compile(r'\b([A-Za-z_]\w*)\s+([A-Za-z_]\w*)\[\]\s*;')


def preprocess(text: str) -> str:
    lines = []
    for line in text.splitlines():
        if re.match(r'\s*#property\b', line):
            continue
        if re.match(r'\s*input\s+group\b', line):
            lines.append('   // ' + line.strip())
            continue
        m = re.match(r'^(\s*)s?input\s+(.*)$', line)
        if m:
            line = m.group(1) + m.group(2)
        lines.append(line)
    text = "\n".join(lines)

    text = ARRAY_PARAM.sub(r'MqlArray<\1>& \2', text)
    text = ARRAY_DECL.sub(r'MqlArray<\1> \2;', text)

    text = re.sub(r'ArraySetAsSeries\s*\([^;]*\)\s*;', '/* series */;', text)
    text = re.sub(r'ArrayResize\s*\(\s*([A-Za-z_]\w*)\s*,\s*([^()]*?)\s*\)', r'\1.resize(\2)', text)
    text = re.sub(r'ArraySize\s*\(\s*([A-Za-z_]\w*)\s*\)', r'((int)\1.size())', text)
    text = re.sub(r'ArrayFree\s*\(\s*([A-Za-z_]\w*)\s*\)\s*;', r'\1.clear();', text)

    header = '#include "mql5_stub.h"\n#line 1 "GoldSweepEA.mq5"\n'
    return header + text


def main() -> int:
    src = SRC.read_text(encoding="utf-8")
    cpp = preprocess(src)
    OUT.write_text(cpp, encoding="utf-8")

    cmd = [
        "g++", "-std=c++17", "-fsyntax-only", "-Wall", "-Wextra",
        "-Wno-unused-parameter", "-Wno-unused-variable", "-Wno-unused-but-set-variable",
        "-Wno-format", "-Wno-sign-compare", "-Wno-class-memaccess",
        "-I", str(ROOT), str(OUT),
    ]
    print("running:", " ".join(cmd))
    proc = subprocess.run(cmd, text=True, capture_output=True)
    if proc.stdout.strip():
        print(proc.stdout)
    if proc.stderr.strip():
        print(proc.stderr)
    if proc.returncode == 0:
        print("SYNTAX CHECK: PASS (C++17 stub compilation)")
    else:
        print("SYNTAX CHECK: FAIL")
    return proc.returncode


if __name__ == "__main__":
    sys.exit(main())
