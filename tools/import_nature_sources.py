"""Restore the editable CC0 inputs used by blender/build_colombo.py."""
from pathlib import Path
import argparse, zipfile, json, hashlib
ROOT=Path(__file__).resolve().parent.parent
MODELS=['Bush_Common','Bush_Common_Flowers','Fern_1','Plant_1','Plant_7','Grass_Wispy_Short','Rock_Medium_1','Rock_Medium_2']
parser=argparse.ArgumentParser()
parser.add_argument('archive',type=Path)
args=parser.parse_args()
lock=json.loads((ROOT/'asset-lock.json').read_text(encoding="utf-8"))
if hashlib.sha256(args.archive.read_bytes()).hexdigest()!=lock['nature']['sha256']:
 raise ValueError('Quaternius archive checksum mismatch')
base=(ROOT/'source_assets/nature').resolve()
with zipfile.ZipFile(args.archive) as z:
 for model in MODELS:
  entry='glTF/'+model+'.gltf';doc=json.loads(z.read(entry))
  names=[entry]+['glTF/'+x['uri'] for kind in ['images','buffers'] for x in doc.get(kind,[]) if 'uri' in x]
  for name in names:
   target=(base/Path(name).relative_to('glTF')).resolve()
   if base not in target.parents: raise ValueError('Unsafe ZIP path')
   target.parent.mkdir(parents=True,exist_ok=True)
   target.write_bytes(z.read(name))
print('Restored eight editable Quaternius sources')
