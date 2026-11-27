"""Create an isolated editor project for neutral indirect Kandy lightmaps."""
from pathlib import Path
import json,re,shutil
R=Path(__file__).resolve().parents[1];SOURCE=R/'build/TrackSDK';OUT=R/'build/neutral260'
def prepare():
 pending=[f'baked/{key}.tscn' for key in ['KandyPrecinct_mahaweli','KandyPrecinct_tooth_temple','KandyStartArch']]
 copied=set()
 while pending:
  relative=pending.pop()
  if relative in copied:continue
  p=SOURCE/relative
  assert p.is_file(),relative
  target=OUT/relative;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,target);copied.add(relative)
  if p.suffix in ['.tscn','.tres','.lmbake','.res','.scn']:
   for ref in re.findall(rb'res://[A-Za-z0-9_./ -]+',p.read_bytes()):
    path=ref.decode().removeprefix('res://').rstrip()
    if (SOURCE/path).is_file():pending.append(path)
 (OUT/'project.godot').write_text('[application]\nconfig/name="Leo 2.6 neutral lightmap authoring"\n[editor_plugins]\nenabled=PackedStringArray("res://addons/neutral/plugin.cfg")\n[rendering]\nrenderer/rendering_method="forward_plus"\n',encoding='utf-8')
 plugin=OUT/'addons/neutral';plugin.mkdir(parents=True,exist_ok=True)
 (plugin/'plugin.cfg').write_text('[plugin]\nname="Neutral lightmap bake"\ndescription="Offline 2.6 indirect bake"\nauthor="Leo Racer"\nversion="1.0"\nscript="plugin.gd"\n',encoding='utf-8')
 shutil.copy2(R/'tools/neutral260_plugin.gd',plugin/'plugin.gd')
 (OUT/'inputs.json').write_text(json.dumps(sorted(copied),indent=2)+'\n',encoding='utf-8')
 print('NEUTRAL_PROJECT_PREPARED',len(copied),flush=True)
if __name__=='__main__':prepare()
