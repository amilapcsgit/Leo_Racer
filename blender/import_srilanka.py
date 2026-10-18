"""Offline supplied-asset conversion. Blender 4.5 --background --python this_file -- STAGE.
Original Downloads files are never changed. Runtime models use metres, ground pivots,
embedded PBR textures, applied transforms and deterministic triangle budgets.
"""
import bpy, sys, json, math, hashlib, os
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
SRC=Path(os.environ.get('LEO_SRI_ASSETS',Path.home()/'Downloads/Leo Racer/game-assests'))
INPUT=ROOT/'.srilanka-inputs'
OUT=ROOT/'assets/models/srilanka'
OUT.mkdir(parents=True,exist_ok=True)
REPORT=ROOT/'docs/qa-srilanka'
REPORT.mkdir(parents=True,exist_ok=True)

def clear():
 bpy.ops.wm.read_factory_settings(use_empty=True)

def load_glb(name):
 clear();bpy.ops.import_scene.gltf(filepath=str(SRC/name));return [o for o in bpy.context.scene.objects if o.type=='MESH']

def keep(objects):
 matrices={o:o.matrix_world.copy() for o in objects}
 for o in objects:o.parent=None;o.matrix_world=matrices[o]
 for o in list(bpy.context.scene.objects):
  if o not in objects:bpy.data.objects.remove(o,do_unlink=True)
 bpy.ops.object.select_all(action='DESELECT')
 for o in objects:o.select_set(True)
 bpy.context.view_layer.objects.active=objects[0]
 bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)

def normalize(objects,height=None,length=None):
 keep(objects)
 vs=[o.matrix_world@Vector(v) for o in objects for v in o.bound_box]
 lo=Vector([min(v[i] for v in vs) for i in range(3)]);hi=Vector([max(v[i] for v in vs) for i in range(3)])
 factor=height/(hi.z-lo.z) if height else length/max(hi.x-lo.x,hi.y-lo.y)
 center=Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z))
 for o in objects:
  o.location=(o.location-center)*factor;o.scale*=factor
 bpy.context.view_layer.update()
 bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)

def triangles(objects):return sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in objects)

def simplify(objects,budget):
 before=triangles(objects)
 if before<=budget:return
 for o in objects:
  bpy.context.view_layer.objects.active=o
  mod=o.modifiers.new('Runtime triangle budget','DECIMATE');mod.ratio=max(.003,budget/before*.98)
  bpy.ops.object.modifier_apply(modifier=mod.name)

def export(name,objects):
 keep(objects)
 for o in objects:
  for slot in o.material_slots:
   if slot.material:
    slot.material.use_nodes=True
    bs=next((n for n in slot.material.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
    if bs and not bs.inputs['Roughness'].is_linked:bs.inputs['Roughness'].default_value=max(.28,bs.inputs['Roughness'].default_value)
 bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_apply=True,export_yup=True,export_animations=False,export_cameras=False,export_lights=False,export_image_format='AUTO')
 result={'name':name,'triangles':triangles(objects),'bytes':(OUT/(name+'.glb')).stat().st_size,'materials':sorted({s.material.name for o in objects for s in o.material_slots if s.material})}
 (REPORT/(name+'-asset.json')).write_text(json.dumps(result,indent=2),encoding='utf-8');print('SRI_ASSET',json.dumps(result))

def image(path):
 im=bpy.data.images.load(str(path),check_existing=True)
 # Limit source 4K scans to a shared 2K maximum while keeping aspect ratio.
 if max(im.size)>2048:
  ratio=2048/max(im.size);im.scale(max(1,int(im.size[0]*ratio)),max(1,int(im.size[1]*ratio)))
 im.pack();return im

def pbr(name,color,rough=.5,metal=0):
 m=bpy.data.materials.new(name);m.use_nodes=True
 bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*color,1);bs.inputs['Roughness'].default_value=rough;bs.inputs['Metallic'].default_value=metal
 return m

def repair_plants(objects,palm=False):
 for m in {s.material for o in objects for s in o.material_slots if s.material}:
  m.use_nodes=True;nt=m.node_tree;nt.nodes.clear();out=nt.nodes.new('ShaderNodeOutputMaterial');bs=nt.nodes.new('ShaderNodeBsdfPrincipled');nt.links.new(bs.outputs['BSDF'],out.inputs['Surface']);bs.inputs['Roughness'].default_value=.65
  if palm:
   part=next((p for p in ['Branche_Red','Branche','Cap','Leaf','Stem','Trunk02'] if p.lower() in m.name.lower()),'Leaf')
   folder=INPUT/'Maps';prefix='Phoenix_Sylvestris_'+part
   paths={'Base Color':folder/(prefix+'.jpeg'),'Normal':folder/(prefix+'_Normal.jpeg'),'Alpha':folder/(prefix+'_Opacity.jpeg')}
  else:
   folder=INPUT/'banana/Textures';paths={'Base Color':folder/'Banana_Plants_BaseColor.png','Normal':folder/'Banana_Plants_Normal_OpenGL.png','Alpha':folder/'Banana_Plants_Opacity.png','Roughness':folder/'Banana_Plants_Roughness.png'}
  for channel,path in paths.items():
   if not path.exists():continue
   tex=nt.nodes.new('ShaderNodeTexImage');tex.image=image(path)
   if channel!='Base Color':tex.image.colorspace_settings.name='Non-Color'
   if channel=='Normal':
    normal=nt.nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.5;nt.links.new(tex.outputs['Color'],normal.inputs['Color']);nt.links.new(normal.outputs['Normal'],bs.inputs['Normal'])
   else:nt.links.new(tex.outputs['Color'],bs.inputs[channel])
  m.use_backface_culling=False
  if paths['Alpha'].exists():
   m.surface_render_method='DITHERED';m.alpha_threshold=.45
   # Exporter uses legacy clip mode when explicitly provided as glTF extras.
   m['gltf_alpha_mode']='MASK'

stage=sys.argv[sys.argv.index('--')+1]
if stage=='tower':
 objects=load_glb('lotus_tower_-_nelum_kuluna.glb');normalize(objects,height=132);export('lotus_tower',objects)
elif stage in ['tuk','street']:
 objects=load_glb('tuk_tuk_rikshaw.glb' if stage=='tuk' else 'street-art_tuk-tuk.glb');normalize(objects,height=2.05);simplify(objects,32000 if stage=='tuk' else 48000);export('tuk_tuk' if stage=='tuk' else 'street_tuk_tuk',objects);simplify(objects,6000);export(('tuk_tuk' if stage=='tuk' else 'street_tuk_tuk')+'_lod',objects)
elif stage=='banana':
 objects=load_glb('banana+tree.glb');normalize(objects,height=3.1);export('banana_simple',objects)
 bpy.ops.wm.open_mainfile(filepath=str(SRC/'Banana_Plant_01.blend'))
 objects=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.name=='Banana_Plant_01_LOD0'];normalize(objects,height=3.6);repair_plants(objects);export('banana_detailed',objects);simplify(objects,1800);export('banana_detailed_lod',objects)
elif stage=='palms':
 for index,name in enumerate(['Phoenix_Sylvestris_Small','Phoenix_Sylvestris_Small03','Phoenix_Sylvestris_Small04']):
  bpy.ops.wm.open_mainfile(filepath=str(INPUT/'untitled.blend'));objects=[bpy.data.objects[name]];normalize(objects,height=[8.5,9.5,11][index]);repair_plants(objects,True);simplify(objects,25000);export('phoenix_%d'%index,objects);simplify(objects,4200);export('phoenix_%d_lod'%index,objects)
elif stage=='bus':
 clear();bpy.ops.wm.obj_import(filepath=str(INPUT/'bus/Leyland FBX_OBJ/.obj/Leyland 1.obj'));objects=[o for o in bpy.context.scene.objects if o.type=='MESH'];normalize(objects,length=10.5)
 vs=[o.matrix_world@Vector(v) for o in objects for v in o.bound_box];dims=[max(v[i] for v in vs)-min(v[i] for v in vs) for i in range(3)]
 if dims[0]>dims[1]:
  for o in objects:o.rotation_euler.z=math.pi/2
  bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
 mats=[pbr('Transit_Cream',(.58,.51,.32),.36,.25),pbr('Transit_Scarlet',(.35,.015,.025),.3,.4),pbr('Transit_Glass',(.015,.04,.045),.16,.4),pbr('Transit_Rubber',(.012,.014,.017),.85),pbr('Transit_Roof',(.65,.64,.52),.45,.2)]
 for o in objects:
  o.data.materials.clear()
  for m in mats:o.data.materials.append(m)
  bounds=[o.matrix_world@Vector(v) for v in o.bound_box];low=min(v.z for v in bounds);high=max(v.z for v in bounds);half=max(abs(v.x) for v in bounds)
  for face in o.data.polygons:
   c=o.matrix_world@face.center;z=(c.z-low)/max(.1,high-low)
   face.material_index=4 if z>.92 else (3 if z<.22 else (2 if .49<z<.85 and abs(c.x)>half*.77 else (1 if z<.47 else 0)))
 simplify(objects,42000);export('sri_lanka_bus',objects);simplify(objects,8000);export('sri_lanka_bus_lod',objects)
else:raise ValueError(stage)
