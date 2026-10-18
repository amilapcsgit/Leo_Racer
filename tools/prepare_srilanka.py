"""Prepare read-only supplied source archives for offline Blender conversion."""
from pathlib import Path
import os,zipfile,subprocess,shutil,json,hashlib,struct
ROOT=Path(__file__).resolve().parents[1]
SRC=Path(os.environ.get('LEO_SRI_ASSETS',Path.home()/'Downloads/Leo Racer/game-assests'))
DEST=ROOT/'.srilanka-inputs';DEST.mkdir(exist_ok=True)
for name,folder in [('Textures.zip','banana'),('Leyland+FBX_OBJ_080331.zip','bus')]:
 with zipfile.ZipFile(SRC/name) as z:
  target=(DEST/folder).resolve()
  for entry in z.infolist():
   resolved=(target/entry.filename).resolve()
   if not resolved.is_relative_to(target):raise ValueError('Archive path outside input directory')
  z.extractall(target)
subprocess.run(['tar','-xf',str(SRC/'New_Plant_High_detail_Phoenix_Sylvestris_Small+blender.rar'),'-C',str(DEST)],check=True)
(ROOT/'assets/flags').mkdir(exist_ok=True)
shutil.copyfile(SRC/'Flag_of_Sri_Lanka.svg',ROOT/'assets/flags/sri_lanka_flag.svg')
records=[]
for name in ['lotus_tower_-_nelum_kuluna.glb','street-art_tuk-tuk.glb','tuk_tuk_rikshaw.glb','banana+tree.glb','Banana_Plant_01.blend','Textures.zip','New_Plant_High_detail_Phoenix_Sylvestris_Small+blender.rar','Leyland+FBX_OBJ_080331.zip','Flag_of_Sri_Lanka.svg']:
 b=(SRC/name).read_bytes();r={'source_file':name,'sha256':hashlib.sha256(b).hexdigest(),'bytes':len(b),'license':'User-supplied; no license metadata bundled'}
 if name.endswith('.glb'):
  n=struct.unpack_from('<I',b,12)[0];r.update(json.loads(b[20:20+n]).get('asset',{}).get('extras',{}))
 records.append(r)
(ROOT/'assets/models/srilanka/source-manifest.json').write_text(json.dumps({'sources':records},indent=2),encoding='utf-8')
print('Prepared inputs without modifying originals:',SRC)
