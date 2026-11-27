"""Install pinned Godot addons from the user's original asset archives.

Usage: python tools/setup_dependencies.py --archives "C:/path/to/AI"
Rokojori remains a separately obtained dependency under its Public Indie License.
"""
from pathlib import Path
import argparse, hashlib, json, zipfile
import re

ROOT = Path(__file__).resolve().parent.parent
PACKS = {
 'rokojori_action_library-v0.6.zip': 'addons/rokojori_action_library/',
 'Terrain3D_v1.0.2-stable-2.zip': 'addons/terrain_3d/',
 'addons.zip': 'addons/EZ-Tree-Godot-Port/',
}

def install(folder):
 records = []
 lock_path = ROOT/'dependency-lock.json'
 lock = json.loads(lock_path.read_text(encoding="utf-8")) if lock_path.exists() else {}
 for name, prefix in PACKS.items():
  archive = folder/name
  digest = hashlib.sha256(archive.read_bytes()).hexdigest()
  if name in lock and lock[name]['sha256'] != digest:
   raise ValueError(f'Archive checksum mismatch: {name}')
  with zipfile.ZipFile(archive) as z:
   for entry in z.infolist():
    if not entry.filename.startswith(prefix) or entry.is_dir() or entry.filename.endswith('.import'):
     continue
    if '/bin/' in entry.filename and not ('.windows.' in entry.filename):
     continue
    target = (ROOT / entry.filename).resolve()
    if ROOT not in target.parents: raise ValueError('Unsafe archive path')
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(z.read(entry))
  records.append((name, {'sha256': digest, 'prefix':prefix}))
  print('Installed', name)
 # Rokojori exports a C# Baker type. Qualify Terrain3D's local script alias.
 for script in (ROOT/'addons/terrain_3d').rglob('*.gd'):
  text=script.read_text(encoding="utf-8")
  fixed=re.sub(r'\bBaker\b','Terrain3DBaker',text)
  if fixed!=text: script.write_text(fixed,encoding="utf-8")
 for script in (ROOT/'addons/EZ-Tree-Godot-Port').rglob('*'):
  if script.suffix not in ['.gd','.tscn','.tres']:continue
  text=script.read_text(encoding="utf-8")
  fixed=text.replace('res://addons/ez-tree-godot-port/','res://addons/EZ-Tree-Godot-Port/')
  if fixed!=text: script.write_text(fixed,encoding="utf-8")
 lock_path.write_text(json.dumps(dict(records),indent=2)+'\n')

if __name__=='__main__':
 parser=argparse.ArgumentParser()
 parser.add_argument('--archives',type=Path,required=True)
 install(parser.parse_args().archives)
