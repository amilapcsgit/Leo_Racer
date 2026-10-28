"""Diagnostic native harness derived from the preserved 2.6 Windows preview."""
from pathlib import Path
import hashlib,json,os,re,shutil
import city_packs
R=Path(__file__).resolve().parents[1]
BASE=R/'build/Preview-2.6.0'
TARGET=R/'build/native-lighting'
def sha(path):
 with path.open('rb') as stream:return hashlib.file_digest(stream,'sha256').hexdigest()
def prepare():
 TARGET.mkdir(exist_ok=True)
 for name in ['LeoRacer.exe','LeoRacer.console.exe','data_LeoRacer_windows_x86_64']:
  source=BASE/name;dest=TARGET/name
  if source.is_dir():shutil.copytree(source,dest,dirs_exist_ok=True)
  elif not dest.exists():shutil.copy2(source,dest)
 # Hard links are confined to the independent derivative stage, never the 2.6 preview.
 source=R/'build/lighting-content/GameAssets';dest=TARGET/'GameAssets'
 for path in source.rglob('*'):
  if not path.is_file():continue
  output=dest/path.relative_to(source);output.parent.mkdir(parents=True,exist_ok=True)
  if not output.exists():os.link(path,output)
 engine,entries=city_packs.read_pack(BASE/'LeoRacer.pck')
 for folder,suffixes in [('scripts',{'.gd'}),('shaders',{'.gdshader'}),('assets/config',{'.json'}),('assets/ui',{'.tres'}),('scenes',{'.tscn'})]:
  for path in (R/folder).rglob('*'):
   if not path.is_file() or path.suffix not in suffixes:continue
   name=path.relative_to(R).as_posix();entries.pop(name+'.remap',None);entries[name]=path.read_bytes()
 for name in ['assets/ui/art/lighting-skyline.png','assets/ui/art/lighting-skyline.png.import']:
  entries[name]=(R/name).read_bytes()
  if name.endswith('.import'):
   for dependency in re.findall(r'"(res://\.godot/imported/[^"\n]+)"',entries[name].decode()):entries[dependency.removeprefix('res://')]=(R/dependency.removeprefix('res://')).read_bytes()
 entries['.godot/global_script_class_cache.cfg']=(R/'.godot/global_script_class_cache.cfg').read_bytes()
 entries['scripts/content/track_check.gd']=(R/'tests/release260_benchmark_probe.gd').read_bytes();entries.pop('scripts/content/track_check.gd.remap',None)
 city_packs.write_pack(TARGET/'LeoRacer.pck',engine,entries)
 report={'purpose':'diagnostic only; not the final export','base_commit':'8579189','engine_unchanged':sha(BASE/'LeoRacer.exe')==sha(TARGET/'LeoRacer.exe'),'core_sha256':sha(TARGET/'LeoRacer.pck')}
 (TARGET/'harness.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
 print('NATIVE_LIGHTING_READY',flush=True)
if __name__=='__main__':prepare()
