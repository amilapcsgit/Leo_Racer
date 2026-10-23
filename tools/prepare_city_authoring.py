"""Pin the supplied MIT editor addon and create an editable closed road graph."""
from pathlib import Path, PurePosixPath
import hashlib,json,math,zipfile
from build_astra_track import spline,distance
ROOT=Path(__file__).resolve().parents[1]
ARCHIVE=Path(r'C:\Users\amilapcs\Downloads\Leo Racer\colombo-city\godot-road-generator-0.9.5.zip')
CONTROL=[(-550,400),(-550,180),(-550,-150),(-550,-500),(-470,-690),(-240,-760),(-40,-700),(90,-560),(290,-600),(470,-460),(500,-260),(380,-170),(170,-160),(100,10),(210,180),(460,280),(550,480),(430,680),(140,750),(-140,720),(-400,650),(-550,520)]
def prepare():
    if ARCHIVE.exists():
        with zipfile.ZipFile(ARCHIVE) as archive:
            prefix='godot-road-generator-0.9.5/addons/road-generator/'
            for name in archive.namelist():
                if not name.startswith(prefix) or name.endswith('/'):continue
                relative=PurePosixPath(name[len(prefix):]);assert '..' not in relative.parts
                target=ROOT/'addons/road-generator'/Path(*relative.parts)
                target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(archive.read(name))
        (ROOT/'licenses/road-generator-MIT.txt').write_bytes((ROOT/'addons/road-generator/LICENSE').read_bytes())
        pin={'version':'0.9.5','license':'MIT','archive_sha256':hashlib.sha256(ARCHIVE.read_bytes()).hexdigest(),'source':'https://github.com/TheDuckCow/godot-road-generator'}
        (ROOT/'blender/city-road-toolchain.json').write_text(json.dumps(pin,indent=2)+'\n',encoding='utf-8')
    assert (ROOT/'addons/road-generator/plugin.cfg').is_file()
    dense=[spline(CONTROL[(i-1)%len(CONTROL)],b,CONTROL[(i+1)%len(CONTROL)],CONTROL[(i+2)%len(CONTROL)],j/200) for i,b in enumerate(CONTROL) for j in range(200)]
    length=sum(distance(a,b) for a,b in zip(dense,dense[1:]+dense[:1]));factor=5500/length
    controls=[(x*factor,z*factor) for x,z in CONTROL]
    lines=['[gd_scene load_steps=4 format=3]',
           '[ext_resource type="Script" path="res://addons/road-generator/nodes/road_manager.gd" id="manager"]',
           '[ext_resource type="Script" path="res://addons/road-generator/nodes/road_container.gd" id="container"]',
           '[ext_resource type="Script" path="res://addons/road-generator/nodes/road_point.gd" id="point"]',
           '[node name="ColomboRoadAuthoring" type="Node3D"]','script = ExtResource("manager")',
           '[node name="Course" type="Node3D" parent="."]','script = ExtResource("container")','density = 2.0','generate_ai_lanes = false']
    for i,(x,z) in enumerate(controls):
        previous=controls[(i-1)%len(controls)];nxt=controls[(i+1)%len(controls)]
        dx,dz=(nxt[0]-previous[0])/6,(nxt[1]-previous[1])/6
        width=24. if i in [5,7,10,12,13,16] else 18.
        lines += [f'[node name="P{i:02d}" type="Node3D" parent="Course"]','script = ExtResource("point")',
                  f'position = Vector3({x:.6f},0,{z:.6f})',f'rotation = Vector3(0,{math.atan2(dx,dz):.9f},0)',
                  f'prior_mag = {math.hypot(dx,dz):.6f}',f'next_mag = {math.hypot(dx,dz):.6f}',
                  f'prior_pt_init = NodePath("../P{(i-1)%len(controls):02d}")',f'next_pt_init = NodePath("../P{(i+1)%len(controls):02d}")',
                  'auto_lanes = false','traffic_dir = Array[int]([2,2,1,1])','lanes = Array[int]([0,0,0,0])',
                  f'lane_width = {width/4}','shoulder_width_l = 0.0','shoulder_width_r = 0.0','gutter_profile = Vector2(0,0)']
    (ROOT/'blender/colombo-road-authoring.tscn').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    (ROOT/'blender/colombo-road-controls.json').write_text(json.dumps({'target_m':5500,'controls':controls,'source':'Stylized Colombo districts; relative coastline and lake/landmark relationships, not a navigation map.'},indent=2)+'\n',encoding='utf-8')
    print('CITY_AUTHORING',len(controls),'RoadPoints',factor)
if __name__=='__main__':prepare()
