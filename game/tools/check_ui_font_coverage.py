#!/usr/bin/env python3
from pathlib import Path
import ast
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
data_text = (ROOT / 'systems' / 'ui_font_data.gd').read_text(encoding='utf-8')
m = re.search(r'const CODEPOINTS: Array\[int\] = \[(.*?)\]', data_text, re.S)
if not m:
    raise SystemExit('Could not read CODEPOINTS from systems/ui_font_data.gd')
covered = {int(v.strip()) for v in m.group(1).split(',') if v.strip()}

used = set(range(32, 127))
for p in ROOT.rglob('*.gd'):
    if p.name == 'ui_font_data.gd':
        continue
    text = p.read_text(encoding='utf-8')
    for match in re.finditer(r'"(?:\\.|[^"\\])*"', text):
        try:
            value = ast.literal_eval(match.group(0))
        except Exception:
            continue
        used.update(ord(ch) for ch in value if ch not in '\n\r\t')

missing = sorted(used - covered)
if missing:
    print('Missing UI glyphs:', ' '.join(f'U+{cp:04X} {chr(cp)!r}' for cp in missing))
    sys.exit(1)
print(f'UI font coverage OK: {len(used)} used codepoints are present.')
