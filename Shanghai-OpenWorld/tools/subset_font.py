#!/usr/bin/env python3
"""Create the offline Simplified Chinese font from an OFL Noto CJK collection."""
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
source = sys.argv[1] if len(sys.argv) > 1 else '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc'
characters = set(chr(code) for code in range(32, 127))
for directory in ('scripts', 'systems', 'ui', 'assets'):
    for script in (root / directory).rglob('*.gd'):
        characters.update(script.read_text())
characters.update((root / 'maps/city.json').read_text())
text = root / 'tools/local/font-glyphs.txt'
text.parent.mkdir(parents=True, exist_ok=True)
text.write_text(''.join(sorted(characters)))
subprocess.run(['pyftsubset', source, '--font-number=2', f'--text-file={text}',
                f'--output-file={root}/assets/textures/city-font.otf', '--name-IDs=*',
                '--layout-features=*'], check=True)
