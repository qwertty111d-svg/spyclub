#!/usr/bin/env python3
"""Build both place files and verify preservation of their original binary data."""
import json
from pathlib import Path
import sys
from rbxl_tool import Place

ROOT = Path(__file__).resolve().parents[1]
TARGETS = (
    ('lobby', 'SPY_CLUB_LOBBY_V127_CLUBLINK.rbxl', 'SPY_CLUB_LOBBY_V134_CLUB_UI.rbxl'),
    ('match', 'SPY_CLUB_MATCH_V88_HUD.rbxl', 'SPY_CLUB_MATCH_V95_CLUB_UI.rbxl'),
)

def main():
    results = {}
    for place, original, output in TARGETS:
        report = Place(ROOT / 'places' / 'original' / original).patch(ROOT / 'src' / place, ROOT / 'dist' / output)
        results[place] = report
        print(f"{output}: {len(report['changed_scripts'])} changed scripts, "
              f"{len(report['added_instances'])} added instances; binary preservation verified")
    (ROOT / 'reports').mkdir(exist_ok=True)
    (ROOT / 'reports' / 'build.json').write_text(json.dumps(results, ensure_ascii=False, indent=2) + '\n')
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
