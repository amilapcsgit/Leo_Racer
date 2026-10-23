"""Hash the complete set of downloadable 1.9 release packages."""
from pathlib import Path
import argparse, hashlib

parser = argparse.ArgumentParser()
parser.add_argument('--version', default='1.9.0')
version = parser.parse_args().version
root = Path(__file__).resolve().parents[1]
names = [f'LeoRacer-{version}-win64.zip', f'LeoRacer-Setup-{version}.exe']
lines = []
for name in names:
    path = root / 'dist' / name
    with path.open('rb') as stream:
        digest = hashlib.file_digest(stream, 'sha256').hexdigest()
    lines.append(f'{digest}  {name}')
(root / 'dist' / f'SHA256SUMS-{version}.txt').write_text('\n'.join(lines) + '\n', encoding='ascii')
print('\n'.join(lines))
