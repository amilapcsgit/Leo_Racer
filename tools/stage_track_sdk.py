"""Assemble the offline authoring project without exporting the game."""
from pathlib import Path
import argparse,hashlib,json,re,shutil,sys
ROOT=Path(__file__).resolve().parents[1]
def copy(source,target):
 target.parent.mkdir(parents=True,exist_ok=True)
 if not target.is_file() or hashlib.file_digest(source.open('rb'),'sha256').digest()!=hashlib.file_digest(target.open('rb'),'sha256').digest():shutil.copy2(source,target)
def stage(output,bundle=False):
 for p in (ROOT/'sdk/track-kit').rglob('*'):
  if p.is_file() and not any(s in ['.godot','exported'] for s in p.relative_to(ROOT/'sdk/track-kit').parts):copy(p,output/p.relative_to(ROOT/'sdk/track-kit'))
 for name in ['road-generator','terrain_3d','EZ-Tree-Godot-Port']:
  for p in (ROOT/'addons'/name).rglob('*'):
   if p.is_file() and p.suffix not in ['.import','.uid','.so','.dylib'] and not any(s in ['.godot','__pycache__'] for s in p.parts):copy(p,output/'addons'/name/p.relative_to(ROOT/'addons'/name))
 # Godot 4.7 removed an old editor setting; retain upstream copyright/version
 # and apply a documented one-line editor-only compatibility fallback.
 slider=output/'addons/terrain_3d/src/double_slider.gd'
 text=slider.read_text(encoding='utf-8').replace('var ds: int = es.get_setting("interface/editor/display_scale")','var ds: int = int(es.get_setting("interface/editor/display_scale")) if es.has_setting("interface/editor/display_scale") else 2')
 slider.write_text(text,encoding='utf-8')
 for name in ['author-python','engine','inputs','licenses','exported','rebuilt-world']:
  directory=output/name;directory.mkdir(parents=True,exist_ok=True);(directory/'.gdignore').write_text('',encoding='utf-8')
 (output/'dependency-patches.json').write_text(json.dumps({'terrain3d-1.0.2':['double_slider.gd: default old removed display_scale setting to 100% under Godot4.7']},indent=2),encoding='utf-8')
 modules=set()
 for p in (ROOT/'assets/models/colombo_city/recipes').glob('*.tscn'):
  text=p.read_text(encoding='utf-8');modules.update(re.findall(r'res://assets/models/colombo_city/(modules/[^" ]+)',text))
  target=output/'library/recipes'/p.name;target.parent.mkdir(parents=True,exist_ok=True);target.write_text(text.replace('res://assets/models/colombo_city/','res://library/'),encoding='utf-8')
 for relative in modules:copy(ROOT/'assets/models/colombo_city'/relative,output/'library'/relative)
 # GLBs retain their external material images, shared once in the SDK.
 for p in (ROOT/'assets/models/colombo_city/modules/textures').glob('*'):
  if p.is_file() and p.suffix!='.import':copy(p,output/'library/modules/textures'/p.name)
 for p in (ROOT/'assets/art/kandy').rglob('*'):
  if p.is_file() and p.suffix!='.import':copy(p,output/'art'/p.relative_to(ROOT/'assets/art/kandy'))
 copy(ROOT/'tools/prepare_kandy.py',output/'tools/prepare_kandy.py')
 for p in (ROOT/'assets/models/colombo').glob('*'):
  if p.is_file() and p.suffix in ['.res','.png']:copy(p,output/'assets/models/colombo'/p.name)

 for p in (ROOT/'licenses').glob('*'):
  if p.is_file():copy(p,output/'licenses'/p.name)
 upstream=ROOT/'build/kandy/earth2road-upstream'
 for name in ['LICENSE','THIRD_PARTY_NOTICES.md','requirements.lock','docs/SOURCES.md','docs/WORLD_FORMAT.md','docs/CLI.md']:
  copy(upstream/name,output/'licenses/earth2road'/name)
 (output/'dependencies.json').write_text(json.dumps({'earth2road':'fec38c79441585e5ff719dd37fa516db809eef9b','world_api':2,'road_generator':'0.9.5','terrain3d':'1.0.2','godot':'4.7.2','offline':True},indent=2),encoding='utf-8')
 if bundle:
  # A portable standard library plus pinned generator dependencies; no pip or
  # first-run installation is needed in the delivered SDK.
  base=Path(sys.base_prefix);python=output/'author-python'
  for p in base.iterdir():
   if p.is_file() and p.suffix.lower() in ['.exe','.dll','.zip','.pyd']:copy(p,python/p.name)
  for name in ['DLLs','Lib']:
   if (base/name).is_dir():shutil.copytree(base/name,python/name,dirs_exist_ok=True,ignore=shutil.ignore_patterns('site-packages','__pycache__','test','tests','idlelib','tkinter','ensurepip'))
  shutil.copytree(ROOT/'build/kandy/author-python',python/'Lib/site-packages',dirs_exist_ok=True,ignore=shutil.ignore_patterns('__pycache__','tests','test'))
  shutil.copytree(ROOT/'build/kandy/map',output/'inputs/world',dirs_exist_ok=True)
  engine=ROOT/'../../tools/godot-net/Godot_v4.7.2-stable_mono_win64'
  shutil.copytree(engine,output/'engine',dirs_exist_ok=True)
  for p in (ROOT/'licenses').glob('Godot*'):copy(p,output/'engine'/p.name)

 source_hashes={}
 for base in [output/'addons/road-generator',output/'addons/terrain_3d']:
  source_hashes[base.name]={str(p.relative_to(base)).replace('\\','/'):hashlib.file_digest(p.open('rb'),'sha256').hexdigest() for p in base.rglob('*') if p.is_file() and p.suffix not in ['.import','.uid']}
 (output/'dependency-hashes.json').write_text(json.dumps(source_hashes,indent=2),encoding='utf-8')
 print('OFFLINE_TRACK_SDK_STAGED',output)
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,default=ROOT/'build/TrackSDK');p.add_argument('--bundle',action='store_true');a=p.parse_args();stage(a.output,a.bundle)
