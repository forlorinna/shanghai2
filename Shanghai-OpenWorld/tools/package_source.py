#!/usr/bin/env python3
"""Collect the Godot project and rebuildable assets without developer-local credentials."""
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

root = Path(__file__).resolve().parents[1]
output = root / 'builds/Shanghai-OpenWorld-v0.1.0-source.zip'
required = ['project.godot', 'export_presets.cfg', 'README.md', 'DEVELOPMENT_PLAN.md',
            'PROGRESS.md', 'TEST_REPORT.md', 'LICENSES.md', '.gitignore']
directories = ['game', 'assets', 'maps', 'scenes', 'scripts', 'systems', 'ui',
               'shaders', 'tests', 'docs']
tools = root / 'tools'
tool_sources = [p for p in tools.iterdir() if p.is_file()]
output.parent.mkdir(parents=True, exist_ok=True)
with ZipFile(output, 'w', compression=ZIP_DEFLATED, compresslevel=8) as archive:
    sources = [root / item for item in required]
    for directory in directories:
        sources += [p for p in (root / directory).rglob('*') if p.is_file()]
    sources += tool_sources
    for file in sorted(sources):
        assert file.is_file(), file
        if '__pycache__' in file.parts or file.suffix in ('.pyc', '.p12', '.jks', '.keystore'):
            continue
        archive.write(file, Path('Shanghai-OpenWorld-v0.1.0') / file.relative_to(root))
with ZipFile(output) as archive:
    assert archive.testzip() is None
    members = archive.namelist()
    assert not any('/tools/signing/' in name or name.endswith('/password') for name in members)
print(f'{output.name}: {output.stat().st_size:,} bytes')
