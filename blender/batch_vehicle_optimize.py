"""Balanced authoring-only simplification of canonical Workshop car folders."""
import argparse, json, sys, time, shutil
from pathlib import Path
import bpy
from mathutils import Vector

parser=argparse.ArgumentParser()
parser.add_argument('--job',type=Path,required=True)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
job=json.loads(args.job.read_text());folder=Path(job['folder']);source=folder/'model.glb'
started=time.monotonic();bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source))
objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
def triangles(o):return sum(max(0,len(p.vertices)-2) for p in o.data.polygons)
before=sum(map(triangles,objects));budget=int(job.get('budget',200000))
original_names={o.name for o in objects};bounds={}
for o in objects:
    points=[o.matrix_world@Vector(p) for p in o.bound_box]
    bounds[o.name]=([min(p[i] for p in points) for i in range(3)],[max(p[i] for p in points) for i in range(3)])
ratios={}
if before>budget:
    wheel_total=sum(triangles(o) for o in objects if o.name.startswith('wheel_'))
    caliper_total=sum(triangles(o) for o in objects if o.name.startswith('caliper_'))
    wheel_budget=min(wheel_total,40000);caliper_budget=min(caliper_total,8000)
    body_total=before-wheel_total-caliper_total
    for o in objects:
        count=triangles(o)
        if o.name.startswith('wheel_'):ratio=min(1.,wheel_budget/max(1,wheel_total))
        elif o.name.startswith('caliper_'):ratio=min(1.,caliper_budget/max(1,caliper_total))
        else:ratio=min(1.,max(1000,budget-wheel_budget-caliper_budget)/max(1,body_total))
        if ratio<.999 and count>300:
            bpy.context.view_layer.objects.active=o
            modifier=o.modifiers.new('Balanced runtime geometry','DECIMATE')
            modifier.ratio=ratio;modifier.use_collapse_triangulate=True
            bpy.ops.object.modifier_apply(modifier=modifier.name)
        ratios[o.name]=ratio
resized=[]
for image in bpy.data.images:
    width,height=image.size
    maximum=int(job.get('maximum_texture',2048))
    if max(width,height)>maximum:
        factor=maximum/max(width,height);image.scale(max(1,round(width*factor)),max(1,round(height*factor)))
        image.pack();resized.append({'image':image.name,'before':[width,height],'after':list(image.size)})
after=sum(map(triangles,objects))
assert {o.name for o in objects}==original_names,'Optimization changed required mesh names'
deviation=0.
for o in objects:
    points=[o.matrix_world@Vector(p) for p in o.bound_box]
    current=([min(p[i] for p in points) for i in range(3)],[max(p[i] for p in points) for i in range(3)])
    deviation=max(deviation,max(abs(current[j][i]-bounds[o.name][j][i]) for j in range(2) for i in range(3)))
assert deviation<.025,'Optimization changed vehicle silhouette bounds by more than 25 mm'
changed=after!=before or bool(resized)
if changed:
    backup=folder.parent/(folder.name+'-before-optimization.glb')
    if not backup.exists():shutil.copy2(source,backup)
    temporary=folder/'model.optimizing.glb'
    bpy.ops.export_scene.gltf(filepath=str(temporary),export_format='GLB',export_yup=True,export_cameras=False,export_lights=False,export_animations=False)
    temporary.replace(source)
report={'format':1,'triangles_before':before,'triangles_after':after,'target_triangles':budget,'target_met':after<=budget*1.02,'maximum_texture':int(job.get('maximum_texture',2048)),'resized_images':resized,'ratios':ratios,'bound_deviation_m':deviation,'seconds':time.monotonic()-started,'mesh_names_preserved':True}
(folder/'optimization-report.json').write_text(json.dumps(report,indent=2)+'\n')
print('BATCH_OPTIMIZED',json.dumps(report))
