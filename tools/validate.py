#!/usr/bin/env python3
"""Compile every place source and run current deterministic module tests."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--compiler', default='/workspace/.spy-tools/bin/luau-compile')
    parser.add_argument('--runtime', default='/workspace/.spy-tools/bin/luau')
    args = parser.parse_args()
    rows = []
    for place in ('lobby', 'match'):
        for source in sorted((ROOT / 'src' / place).rglob('*.luau')):
            result = subprocess.run([args.compiler, '--null', str(source)], capture_output=True, text=True)
            row = {'place': place, 'file': str(source.relative_to(ROOT / 'src' / place)),
                   'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
                   'exit_code': result.returncode, 'diagnostics': (result.stdout + result.stderr).strip()}
            rows.append(row)
            if result.returncode:
                print(f"FAIL {place}/{row['file']}: {row['diagnostics']}", file=sys.stderr)
    report = {'scope': 'Luau syntax and bytecode compilation; Roblox Studio was not run',
              'total': len(rows), 'passed': sum(row['exit_code'] == 0 for row in rows),
              'failed': sum(row['exit_code'] != 0 for row in rows), 'scripts': rows}
    (ROOT / 'reports').mkdir(exist_ok=True)
    (ROOT / 'reports' / 'luau-current.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(f"Luau compilation: {report['passed']}/{report['total']} passed")
    if report['failed']:
        return 1
    for runner in [ROOT / 'tools' / 'test_lobby_environment.py', ROOT / 'tools' / 'test_billiards_ui.py']:
        if runner.exists():
            result = subprocess.run([sys.executable, str(runner)], cwd=ROOT)
            if result.returncode:
                return result.returncode
    # Each runner executes actual project sources with the minimal service stubs.
    for runner in sorted((ROOT / 'tests').glob('run_*.py')):
        result = subprocess.run([sys.executable, str(runner)], cwd=ROOT)
        if result.returncode:
            return result.returncode
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
