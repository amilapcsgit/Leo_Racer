"""Package the street-racing UI Windows release."""
from pathlib import Path
import argparse,hashlib,json,zipfile
root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--version',default='1.9.0')
version=parser.parse_args().version
assert all(c in '0123456789.-abcdefghijklmnopqrstuvwxyz' for c in version), 'Invalid version'
folder=root/'build/UIRefresh'
destination=root/('dist/LeoRacer-'+version+'-win64.zip')
destination.parent.mkdir(exist_ok=True)
with zipfile.ZipFile(destination,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
    for path in sorted(folder.rglob('*')):
        if path.is_file() and path.suffix.lower() not in ('.pdb','.log'):
            archive.write(path,'LeoRacer/'+path.relative_to(folder).as_posix())
with zipfile.ZipFile(destination) as archive:
    assert archive.testzip() is None
report={'archive':str(destination),'bytes':destination.stat().st_size,'sha256':hashlib.sha256(destination.read_bytes()).hexdigest()}
(root/'build/qa-ui').mkdir(parents=True,exist_ok=True)
(root/'build/qa-ui/package.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2))
