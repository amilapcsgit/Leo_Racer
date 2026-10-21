"""Vehicle-only, uncompressed glTF 2.0 derivative for Leo Racer 1.6 RC."""
import bpy,bmesh,math,pathlib,json,hashlib,tempfile,argparse,sys
from mathutils import Vector,Matrix
REPO=pathlib.Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--master',type=pathlib.Path,required=True)
parser.add_argument('--output',type=pathlib.Path,default=REPO/'build/bigster-runtime')
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
R=args.output.resolve();R.mkdir(parents=True,exist_ok=True)
MASTER=args.master.resolve()
master_hash=hashlib.sha256(MASTER.read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(MASTER));bpy.context.scene.frame_set(1)
bpy.context.view_layer.update();bpy.context.preferences.filepaths.save_version=0
tempfile.tempdir=str(R/'temp');pathlib.Path(tempfile.tempdir).mkdir(exist_ok=True)
asset=bpy.data.collections['BIGSTER_EXTREME_GRAY'];original=list(asset.all_objects)
wheel_names=['wheel-front-left','wheel-front-right','wheel-back-left','wheel-back-right']
centres=[bpy.data.objects[n].matrix_world.translation.copy() for n in wheel_names]
targets=[Vector((-.78,1.351,.355)),Vector((.78,1.351,.355)),Vector((-.78,-1.351,.355)),Vector((.78,-1.351,.355))]
paint_old=bpy.data.materials['dust25_body'];paint_node=next(n for n in paint_old.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
paint_rgb=list(paint_node.inputs['Base Color'].default_value)[:3]
coll=bpy.data.collections.new('LEO_RACER_BIGSTER');bpy.context.scene.collection.children.link(coll)
root=bpy.data.objects.new('VehicleMetres',None);coll.objects.link(root)
groups=[];caliper_groups=[]
for i,p in enumerate(targets):
    o=bpy.data.objects.new('wheel_'+str(i),None);coll.objects.link(o);o.parent=root;o.location=p;groups.append(o)
    o=bpy.data.objects.new('caliper_'+str(i),None);coll.objects.link(o);o.parent=root;o.location=p;caliper_groups.append(o)
def mat(name,rgb,metal=0,rough=.5,alpha=1,emission=0):
    m=bpy.data.materials.new(name);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*rgb,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
    p.inputs['Alpha'].default_value=alpha;p.inputs['Transmission Weight'].default_value=0
    if emission:p.inputs['Emission Color'].default_value=(*rgb,1);p.inputs['Emission Strength'].default_value=emission
    if alpha<1:m.surface_render_method='DITHERED'
    m.diffuse_color=(*rgb,alpha);return m
P={
 'paint':mat('Gray paint',paint_rgb,.42,.3),
 'roof':mat('Black roof',(.008,.012,.015),.25,.25),
 'cladding':mat('Dark cladding',(.022,.027,.030),0,.64),
 'rubber':mat('Wheel rubber',(.012,.015,.018),0,.93),
 'gloss':mat('Gloss black trim',(.008,.011,.014),.05,.28),
 'alloy':mat('Machined alloy',(.38,.42,.44),.82,.3),
 'silver':mat('Satin silver',(.30,.33,.35),.55,.43),
 'copper':mat('Copper accents',(.50,.30,.16),.65,.3),
 'cabin':mat('Cabin dark',(.022,.027,.032),0,.82),
 'seats':mat('Seat fabric',(.042,.049,.053),0,.88),
 'white':mat('Badge and plate white',(.72,.75,.77),.1,.4),
 'plate_black':mat('Plate lettering',(.004,.006,.008),0,.6),
 'blue':mat('Plate EU blue',(.008,.025,.22),0,.4),
 'led':mat('Headlamp white',(.65,.75,.84),.1,.22,emission=.35),
 'red':mat('Tail lamp red',(.36,.003,.009),.15,.24,emission=.25),
 'glass_front':mat('Front glass',(.11,.16,.19),0,.12,.26),
 'glass_rear':mat('Privacy glass',(.04,.07,.09),0,.14,.48),
 'glass_roof':mat('Panoramic glass',(.014,.023,.030),.1,.18,.94),
 'lens':mat('Lamp lens',(.12,.15,.17),0,.1,.10),
}
def role(o,m):
    n=m.name.lower() if m else '';name=o.name.lower()
    if any(k in n for k in ['frit','epdm','seal']):return 'cladding'
    glass_role=m.get('asset_glass_role','') if m else ''
    if glass_role and glass_role!='lamp_lens':
        if 'panoramic' in name or 'sunroof' in name:return 'glass_roof'
        return 'glass_rear' if any(k in name for k in ['tailgate','sideglass','doorglass_r']) else 'glass_front'
    if any(k in name for k in ['plate_text']):return 'plate_black'
    if 'eu_band' in name:return 'blue'
    if 'plate' in name and 'mount' not in name:return 'white'
    if 'glass' in n:return 'lens'
    if 'rubber' in n or 'tyre' in name:return 'rubber'
    if 'wordmark' in n or 'dacia_oem_badge' in name:return 'alloy'
    if n.startswith('dust25_body'):return 'paint'
    if 'roof' in n or 'ceramic' in n:return 'roof'
    if n=='dust25_or' or 'copper' in n:return 'copper'
    if any(k in n for k in ['red','reflector']) or n in ['dust25_re','dust25_brake','dust25_fogr']:return 'red'
    if any(k in n for k in ['led','driving_white','headlamp_white','signature_white']) or n in ['dust25_l','dust25_r']:return 'led'
    if any(k in n for k in ['machined','alum','mirror','chrome']) or n=='dust25_chr':return 'alloy'
    if 'megalith' in n or 'nizchr' in n or 'brake_disc' in n:return 'silver'
    if any(k in n for k in ['leath','stic','uphol','seat']):return 'seats'
    if any(k in n for k in ['intl','carpet','screen','rem','gauges','intlo']) or n=='dust25_int':return 'cabin'
    if 'gloss' in n or 'polymer' in n or n=='dust25_blacke':return 'gloss'
    return 'cladding'
def wheel_index(o):
    a=o
    while a:
        if a.name in wheel_names:return wheel_names.index(a.name)
        a=a.parent
    n=o.get('wheel_association')
    return wheel_names.index(n) if n in wheel_names else None
drop_tokens=['engine_i3','engbay','turbo_i3','subframe','strut_front','spring_r','diff_r','transmission','transfercase','intercooler','radiator','radsupport','airbox','intake_i3','hub_f','hub_r','wishbone','swaybar','lowerarm','upperarm','trailingarm','halfshaft','shock_r','tierod','fueltank','raerbeam','exhaustpipe']
rows=[];kept=[];buckets={}
for o in original:
    if o.type!='MESH':continue
    name=o.name;low=name.lower();before=sum(len(p.vertices)-2 for p in o.data.polygons);wi=wheel_index(o)
    if low.startswith('tyre_') or any(k in low for k in drop_tokens) or low.startswith(('dust25_headlightglass','dust25_taillightsglass')):
        rows.append({'name':name,'before':before,'after':0,'reason':'Replaced tyre or hidden mechanical resource'});continue
    if low.startswith(('dust25_doorglass','dust25_sideglass','dust25_windshield','dust25_tailgateglass')):
        mesh=o.data.copy() # Runtime glass is a single sheet, without physical laminate rims.
    else:mesh=bpy.data.meshes.new_from_object(o.evaluated_get(bpy.context.evaluated_depsgraph_get()),preserve_all_data_layers=True,depsgraph=bpy.context.evaluated_depsgraph_get())
    if low in ['bigster_panoramic_fixed_glass','bigster_sunroof_opening_glass']:
        bm=bmesh.new();bm.from_mesh(mesh);bm.normal_update()
        bmesh.ops.delete(bm,geom=[f for f in bm.faces if f.normal.z<.4],context='FACES')
        bm.to_mesh(mesh);bm.free();mesh.update()
    mesh.transform(o.matrix_world)
    new=bpy.data.objects.new('runtime_'+name,mesh);coll.objects.link(new)
    materials=[P[role(o,m)] for m in o.data.materials]
    source_indices=[p.material_index for p in mesh.polygons]
    mesh.materials.clear()
    for m in materials:mesh.materials.append(m)
    for p,i in zip(mesh.polygons,source_indices):p.material_index=i
    for v in mesh.vertices:
        v.co=targets[wi]+(v.co-centres[wi])*(.355/.359) if wi is not None else v.co-Vector((0,.08,0))
    new.animation_data_clear();bpy.context.view_layer.objects.active=new
    bpy.ops.object.select_all(action='DESELECT');new.select_set(True)
    # Safely remove redundant coplanar detail, then use role-specific collapse.
    bm=bmesh.new();bm.from_mesh(mesh)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.000001)
    bmesh.ops.dissolve_limit(bm,angle_limit=.002,verts=list(bm.verts),edges=list(bm.edges),delimit={'MATERIAL','SHARP'})
    bm.to_mesh(mesh);bm.free();mesh.update()
    cabin='Cabin' in [c.name for c in o.users_collection] or low in ['dust25_tailgate_carp','dust25_body1','dust25_phonh']
    ratio=.06 if cabin else .26
    if wi is not None:ratio=.16
    if any(k in low for k in ['glass','weather_seal','native_glass_seal']):ratio=.15 if before>1000 else .8
    if any(k in low for k in ['lower_copper_tab','lower_lattice','patterned_band']):ratio=.16
    if any(k in low for k in ['badge','plate_text']):ratio=.72
    if name=='dust25_body.002' or before<250:ratio=1
    if low=='dust25_underbody':ratio=.10
    count=sum(len(p.vertices)-2 for p in mesh.polygons)
    if ratio<1 and count>200:
        mod=new.modifiers.new('Runtime simplification','DECIMATE');mod.ratio=ratio;mod.use_collapse_triangulate=True
        bpy.ops.object.modifier_apply(modifier=mod.name)
    if new.data.has_custom_normals:
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
    bm=bmesh.new();bm.from_mesh(new.data)
    bad=[f for f in bm.faces if f.calc_area()<1e-12]
    if bad:bmesh.ops.delete(bm,geom=bad,context='FACES')
    loose=[v for v in bm.verts if not v.link_faces]
    if loose:bmesh.ops.delete(bm,geom=loose,context='VERTS')
    for e in bm.edges:
        if len(e.link_faces)==2:e.smooth=e.calc_face_angle(0)<math.radians(45)
    bm.to_mesh(new.data);bm.free();new.data.update()
    if wi is not None:
        bucket=('caliper' if o.get('wheel_role')=='caliper_static' else 'wheel',wi)
    elif any(m and m.node_tree.nodes.get('Principled BSDF').inputs['Alpha'].default_value<1 for m in new.data.materials):bucket=('glass','Panoramic_closed' if low in ['bigster_panoramic_fixed_glass','bigster_sunroof_opening_glass'] else name)
    else:bucket=('body',0)
    buckets.setdefault(bucket,[]).append(new);kept.append(new)
    rows.append({'name':name,'before':before,'after':sum(len(p.vertices)-2 for p in new.data.polygons),'ratio':ratio,'bucket':str(bucket)})
# Smooth, circular, grooved tyres replace dense individual tread blocks.
profile=[(-.107,.239),(-.116,.274),(-.114,.313),(-.104,.340),(-.088,.350),(-.065,.355),(-.042,.358),(-.039,.354),(-.034,.358),(0,.359),(.034,.358),(.039,.354),(.042,.358),(.065,.355),(.088,.350),(.104,.340),(.114,.313),(.116,.274),(.107,.239)]
for wi,c in enumerate(targets):
    vs=[];fs=[];seg=64;s=.355/.359
    for x,r in profile:
        for j in range(seg):a=math.tau*j/seg;vs.append(c+Vector((x*s,r*s*math.sin(a),r*s*math.cos(a))))
    for k in range(len(profile)-1):
        for j in range(seg):a=k*seg+j;b=k*seg+(j+1)%seg;fs.append((a,b,b+seg,a+seg))
    me=bpy.data.meshes.new('Runtime circular tyre');me.from_pydata(vs,[],fs);me.materials.append(P['rubber']);me.update()
    for p in me.polygons:p.use_smooth=True
    uv=me.uv_layers.new()
    for p in me.polygons:
        for li in p.loop_indices:idx=me.loops[li].vertex_index;uv.data[li].uv=(idx%seg/seg,idx//seg/(len(profile)-1))
    o=bpy.data.objects.new('Tyre_'+str(wi),me);coll.objects.link(o);buckets.setdefault(('wheel',wi),[]).append(o);kept.append(o)
final=[]
for bucket,objects in buckets.items():
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    if len(objects)>1:bpy.ops.object.join()
    o=objects[0]
    if bucket[0] in ['wheel','caliper']:
        i=bucket[1];parent=groups[i] if bucket[0]=='wheel' else caliper_groups[i]
        o.data.transform(Matrix.Translation(-targets[i]));o.matrix_world=Matrix.Identity(4);o.parent=parent;o.matrix_parent_inverse=Matrix.Identity(4)
        o.name=bucket[0]+'_mesh_'+str(i)
    else:o.parent=root;o.name='body' if bucket[0]=='body' else bucket[1]
    # Consolidate identical material slots after joining, retaining face mapping.
    mats=list(o.data.materials);unique=list(dict.fromkeys(mats));mapping={i:unique.index(m) for i,m in enumerate(mats)}
    for p in o.data.polygons:p.material_index=mapping[p.material_index]
    indices=[p.material_index for p in o.data.polygons];o.data.materials.clear()
    for m in unique:o.data.materials.append(m)
    for p,i in zip(o.data.polygons,indices):p.material_index=i
    # Joining meshes can retain duplicate edges/custom-data layers. Validate the
    # final runtime mesh before the exporter reads it.
    o.data.validate(verbose=True,clean_customdata=True)
    o.data.update()
    final.append(o)
# Delete source instances from this derivative scene only, never the master.
for o in original:
    if o.name in bpy.data.objects:bpy.data.objects.remove(o,do_unlink=True)
bpy.data.orphans_purge(do_recursive=True)
scene=bpy.context.scene;scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1;scene.frame_set(1)
bpy.ops.object.select_all(action='DESELECT')
for o in coll.all_objects:o.select_set(True)
bpy.context.view_layer.objects.active=root
root['target']='Leo Racer 1.6 RC';root['forward']='-Z after glTF export';root['normalization_y']=.08;root['wheel_radius']=.355
out=R/'replacement/assets/models/bigster';out.mkdir(parents=True,exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(out/'bigster.glb'),export_format='GLB',use_selection=True,export_yup=True,export_animations=False,export_apply=True,export_extras=True,export_cameras=False,export_lights=False)
bpy.ops.wm.save_as_mainfile(filepath=str(R/'bigster_leo_racer_simplified.blend'))
stats={'source_master_sha256':master_hash,'master_unchanged':hashlib.sha256(MASTER.read_bytes()).hexdigest()==master_hash,'source_triangles':452662,'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in final),'mesh_objects':len(final),'materials':len({m for o in final for m in o.data.materials}),'material_surfaces':sum(len(o.data.materials) for o in final),'textures':0,'glb_bytes':(out/'bigster.glb').stat().st_size,'closed_sunroof':True,'animations':0,'wheel_targets_blender':[list(p) for p in targets],'details':rows}
(R/'simplification_report.json').write_text(json.dumps(stats,indent=2))
assert stats['master_unchanged']
print('RUNTIME_EXPORT_DONE', {k:v for k,v in stats.items() if k!='details'})
