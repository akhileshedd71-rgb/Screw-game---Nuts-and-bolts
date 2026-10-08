#!/usr/bin/env python3
"""Package current successful exports and record SHA256 artifact checksums."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import hashlib

root = Path(__file__).resolve().parents[1]
builds = root / 'builds'
for platform in ('linux', 'web'):
    source = builds / platform
    if not source.is_dir():
        continue
    output = builds / f'Screwcraft-{platform}.zip'
    with ZipFile(output, 'w', ZIP_DEFLATED, compresslevel=6) as archive:
        for item in sorted(source.rglob('*')):
            if item.is_file() and not item.name.endswith('.import'):
                archive.write(item, Path('Screwcraft-' + platform) / item.relative_to(source))
        archive.write(root / 'docs' / 'QA.md', 'QA.md')
    print(output.relative_to(root), output.stat().st_size)
artifacts = [builds / 'android/Screwcraft-debug.apk', builds / 'Screwcraft-linux.zip', builds / 'Screwcraft-web.zip']
lines = []
for artifact in artifacts:
    if artifact.exists():
        with artifact.open('rb') as handle:
            digest = hashlib.file_digest(handle, 'sha256').hexdigest()
        lines.append(f'{digest}  {artifact.relative_to(builds)}')
(builds / 'SHA256SUMS').write_text('\n'.join(lines) + '\n')
print('Wrote builds/SHA256SUMS')
