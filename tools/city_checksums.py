from pathlib import Path
import argparse,hashlib
root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('--version',required=True);args=parser.parse_args()
files=[root/'dist'/f'LeoRacer-{args.version}-win64.zip',root/'dist'/f'LeoRacer-Setup-{args.version}.exe']
lines=[hashlib.sha256(p.read_bytes()).hexdigest()+'  '+p.name for p in files]
(root/'dist'/f'SHA256SUMS-{args.version}.txt').write_text('\n'.join(lines)+'\n',encoding='ascii')
print('\n'.join(lines))
