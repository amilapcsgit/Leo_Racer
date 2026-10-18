"""Additive Colombo scenery. Run Blender --background --python this_file."""
import bpy, math, random, json
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/models/colombo'
OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
random.seed(2026)

def mat(name,hexcolor,metal=0,rough=.65):
 m=bpy.data.materials.new(name);m.diffuse_color=(*[int(hexcolor[i:i+2],16)/255 for i in (0,2,4)],1);m.use_nodes=True
 bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=m.diffuse_color;bs.inputs['Metallic'].default_value=metal;bs.inputs['Roughness'].default_value=rough
 return m

bark=mat('Palm_Bark','6b4430');leaf=mat('Palm_Leaf','238645');leaf2=mat('Palm_LeafLight','5d963b');gold=mat('Colombo_Gold','d4af37',.8,.25)
dark=mat('Obsidian','101b24',.35,.3);glass=mat('EV_Glass','102c3d',.7,.16);rubber=mat('Rubber','111417',0,.86)
teal=mat('Electric_Teal','00888c',.65,.23);red=mat('Tuk_Maroon','8d2241',.3,.32);cream=mat('Warm_Limestone','c5b999')
lamp=mat('Headlamp','b1f4f3',.2,.15)

def mesh(name,verts,faces,material):
 data=bpy.data.meshes.new(name);data.from_pydata(verts,[],faces);data.materials.append(material)
 ob=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(ob);return ob

def box(name,loc,scale,material,bevel=0):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc);ob=bpy.context.object;ob.name=name;ob.scale=scale
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);ob.data.materials.append(material)
 if bevel:
  mod=ob.modifiers.new('Soft highlights','BEVEL');mod.width=bevel;mod.segments=3
  bpy.context.view_layer.objects.active=ob;bpy.ops.object.modifier_apply(modifier=mod.name)
  for p in ob.data.polygons:p.use_smooth=True
 return ob

def sphere(name,loc,scale,material):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=6,location=loc);ob=bpy.context.object;ob.name=name;ob.scale=scale;ob.data.materials.append(material)
 for p in ob.data.polygons:p.use_smooth=True
 return ob

def wheel(loc,r=.36,w=.22):
 bpy.ops.mesh.primitive_cylinder_add(vertices=20,radius=r,depth=w,location=loc,rotation=(0,math.pi/2,0));ob=bpy.context.object;ob.data.materials.append(rubber)
 bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=r*.57,depth=w*1.08,location=loc,rotation=(0,math.pi/2,0));bpy.context.object.data.materials.append(gold)

def export_group(name,objects):
 bpy.ops.object.select_all(action='DESELECT')
 meshes=[ob for ob in objects if ob.type=='MESH']
 non_meshes=[ob for ob in objects if ob.type!='MESH']
 for ob in meshes: ob.select_set(True)
 bpy.context.view_layer.objects.active=meshes[0]
 if len(meshes)>1:
  bpy.ops.object.join()
  objects[:]=[bpy.context.view_layer.objects.active]+non_meshes
 bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_apply=True,export_yup=True)
 print('COLOMBO_ASSET',name,'triangles',sum(len(o.data.polygons)*2 for o in objects if o.type=='MESH'),flush=True)

for variant in range(3):
 before=set(bpy.data.objects);h=8.6+variant*.8;lean=.8+variant*.24
 verts=[];faces=[];rings=20;sides=10
 for j in range(rings+1):
  t=j/rings;rad=.20*(1-.38*t)*(1+.07*math.sin(t*math.pi*36))
  for k in range(sides):
   a=k*math.tau/sides;verts.append((lean*t*t+math.cos(a)*rad,math.sin(a)*rad,h*t))
 for j in range(rings):
  for k in range(sides):
   a=j*sides+k;b=j*sides+(k+1)%sides;faces.append((a,b,b+sides,a+sides))
 trunk=mesh('Palm_Trunk',verts,faces,bark)
 for p in trunk.data.polygons:p.use_smooth=True
 for f in range(16):
  a=f*2.39996+variant;length=3.8+random.random()*1.3;verts=[];faces=[]
  for j in range(13):
   t=j/12;reach=length*t;z=h+math.sin(t*math.pi*.95)*1.2-t*t*1.6
   center=Vector((lean+math.cos(a)*reach,math.sin(a)*reach,z))
   side=Vector((-math.sin(a),math.cos(a),0));width=.32*math.sin(t*math.pi)**.6+.01
   verts.extend([center-side*width,center+Vector((0,0,.09)),center+side*width])
   if j:
    idx=j*3;faces.extend([(idx-3,idx,idx+1,idx-2),(idx-2,idx+1,idx+2,idx-1)])
   # Feathered leaflets give a dense canopy and a clean tropical silhouette.
   if j>1 and j<12:
    for sign in [-1,1]:
     base=len(verts);tip=center+side*sign*(.95*math.sin(t*math.pi)+.15)+Vector((math.cos(a)*.36,math.sin(a)*.36,-.24))
     verts.extend([center,tip,center+Vector((math.cos(a)*.20,math.sin(a)*.20,-.025))]);faces.append((base,base+1,base+2))
  mesh('Palm_Frond',verts,faces,leaf if f%3 else leaf2)
 for i in range(5):
  a=i*math.tau/5;sphere('Coconut',(lean+math.cos(a)*.28,math.sin(a)*.28,h-.20),(.16,.15,.20),bark)
 objects=list(set(bpy.data.objects)-before)
 bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'blender'/('palm_%d.blend'%variant)))
 export_group('palm_'+str(variant),objects)
 # A separate lower detail asset keeps authored hero geometry untouched.
 for ob in objects:
  if ob.type=='MESH' and len(ob.data.polygons)>80:
   bpy.context.view_layer.objects.active=ob;mod=ob.modifiers.new('Distance LOD','DECIMATE');mod.ratio=.42;bpy.ops.object.modifier_apply(modifier=mod.name)
 export_group('palm_'+str(variant)+'_lod',objects)
 for ob in objects:bpy.data.objects.remove(ob,do_unlink=True)

for name in ['Bush_Common','Bush_Common_Flowers','Fern_1','Plant_1','Plant_7','Grass_Wispy_Short','Rock_Medium_1','Rock_Medium_2']:
 before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(ROOT/'source_assets/nature'/(name+'.gltf')))
 objects=list(set(bpy.data.objects)-before)
 for ob in objects:
  if ob.type=='MESH' and len(ob.data.polygons)>6000:
   bpy.context.view_layer.objects.active=ob;mod=ob.modifiers.new('Game budget','DECIMATE');mod.ratio=6000/len(ob.data.polygons);bpy.ops.object.modifier_apply(modifier=mod.name)
 export_group(name.lower(),objects)
 for ob in objects:bpy.data.objects.remove(ob,do_unlink=True)

for kind in ['tuk_tuk','electric_car']:
 before=set(bpy.data.objects)
 if kind=='tuk_tuk':
  box('Tuk_Chassis',(0,0,.55),(1.5,2.8,.60),red,.18)
  box('Tuk_Cabin',(0,.42,1.32),(1.5,1.45,1.12),teal,.19)
  box('Tuk_Roof',(0,.2,1.95),(1.65,2.25,.19),dark,.12)
  box('Tuk_Windshield',(0,-.38,1.40),(1.25,.05,.63),glass,.08)
  box('Tuk_Nose',(0,-1.15,.95),(1.13,.58,.55),red,.17)
  for side in [-1,1]:
   wheel((side*.78,.85,.43),.36);box('OpenDoor',(side*.76,.10,1.15),(.06,.8,.74),dark,.03)
   sphere('Tuk_Headlamp',(side*.38,-1.47,1),(.14,.06,.14),lamp)
  wheel((0,-1.18,.38),.32,.30)
 else:
  box('EV_Body',(0,0,.64),(1.86,3.9,.76),teal,.32)
  box('EV_Cabin',(0,.12,1.22),(1.62,2.02,.88),glass,.35)
  box('EV_Roof',(0,.19,1.62),(1.30,1.42,.12),teal,.09)
  for side in [-1,1]:
   for axle in [-1,1]:wheel((side*.94,axle*1.21,.43),.39,.23)
   box('EV_Light',(side*.59,-1.94,.83),(.58,.07,.13),lamp,.04)
   box('EV_Trim',(side*.94,.1,.45),(.04,2.5,.06),gold,.01)
 objects=list(set(bpy.data.objects)-before);export_group(kind,objects)

bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'blender/colombo_props.blend'))
print('COLOMBO_ASSETS_COMPLETE',flush=True)
