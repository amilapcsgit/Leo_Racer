"""Reproducible Blender 4.5 asset pipeline. Units: metres; Godot forward: -Z.
Run: blender --background --factory-startup --python blender/build_assets.py
All exports use applied transforms, shared PBR materials, UVs and +Y up.
"""
import bpy, math, random, json, os, sys
from mathutils import Vector
from collections import defaultdict
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'models')
random.seed(108)
M={}
def mat(name, rgb, rough=.65, metal=0, emission=0):
    # Palette values are authored in sRGB; Blender's shader inputs are linear.
    linear=tuple(c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4 for c in rgb)
    m=bpy.data.materials.new(name); m.diffuse_color=(*linear,1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*linear,1)
    p.inputs['Roughness'].default_value=rough; p.inputs['Metallic'].default_value=metal
    if emission:
        p.inputs['Emission Color'].default_value=(*linear,1); p.inputs['Emission Strength'].default_value=emission
    M[name]=m
for n,c in {'road':(.105,.15,.22),'grass':(.22,.56,.27),'grasslight':(.36,.68,.26),'sand':(.87,.71,.44),'cream':(.98,.89,.67),'white':(.97,.98,.93),'red':(.93,.17,.23),'navy':(.035,.065,.14),'cyan':(.05,.82,.94),'gold':(1,.65,.08),'pink':(.96,.22,.53),'purple':(.43,.22,.7),'trunk':(.42,.22,.105),'leaf':(.12,.44,.17),'leaflight':(.34,.67,.16),'coral':(.94,.42,.34),'aqua':(.24,.72,.68),'blue':(.04,.22,.85),'glass':(.08,.27,.36),'roof':(.65,.22,.16),'rubber':(.025,.03,.048),'muzzle':(.95,.72,.43),'green':(.15,.64,.26),'black':(.015,.018,.025)}.items():
    mat(n,c, .3 if n in ['blue','glass','gold','cyan','pink','aqua'] else .75, .45 if n=='gold' else .0, .35 if n=='cyan' else 0)
B=defaultdict(lambda:[[],[]])
def clear():
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False); B.clear()
def conv(p): return (p[0],-p[2],p[1])
def poly(verts,faces,material):
    vs,fs=B[material]; off=len(vs); vs.extend(verts); fs.extend([tuple(off+i for i in f) for f in faces])
def box(p,s,m,angle=0):
    x,y,z=p; a,b,c=[v/2 for v in s]; co=math.cos(angle); si=math.sin(angle)
    v=[]
    for dx,dy,dz in [(-a,-b,-c),(a,-b,-c),(a,b,-c),(-a,b,-c),(-a,-b,c),(a,-b,c),(a,b,c),(-a,b,c)]:
        v.append((x+dx*co+dz*si,y+dy,z-dx*si+dz*co))
    poly(v,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(3,7,6,2),(0,4,7,3),(1,2,6,5)],m)
def ell(p,s,m,n=16,rings=10):
    v=[]; f=[]
    for j in range(rings+1):
        a=math.pi*j/rings
        for i in range(n):
            b=2*math.pi*i/n
            v.append((p[0]+s[0]*math.sin(a)*math.cos(b),p[1]+s[1]*math.cos(a),p[2]+s[2]*math.sin(a)*math.sin(b)))
    for j in range(rings):
        for i in range(n): f.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
    poly(v,f,m)
def rod(a,b,r,m,r2=None,n=12):
    a=Vector(a); b=Vector(b); d=(b-a).normalized(); t=d.cross(Vector((0,1,0)))
    if t.length<.01: t=d.cross(Vector((1,0,0)))
    t.normalize(); q=d.cross(t).normalized(); v=[]; f=[]
    for p,radius in [(a,r),(b,r if r2 is None else r2)]:
        for i in range(n): v.append(tuple(p+radius*(t*math.cos(i*math.tau/n)+q*math.sin(i*math.tau/n))))
    f.extend([tuple(range(n-1,-1,-1)),tuple(range(n,2*n))])
    for i in range(n): f.append((i,(i+1)%n,(i+1)%n+n,i+n))
    poly(v,f,m)
def torus(p,R,r,m,axis='y',n=24,k=8):
    v=[]; f=[]
    for i in range(n):
        a=i*math.tau/n
        for j in range(k):
            b=j*math.tau/k; x=(R+r*math.cos(b))*math.cos(a); z=(R+r*math.cos(b))*math.sin(a); y=r*math.sin(b)
            if axis=='x': x,y,z=y,x,z
            v.append((p[0]+x,p[1]+y,p[2]+z))
    for i in range(n):
        for j in range(k): f.append((i*k+j,((i+1)%n)*k+j,((i+1)%n)*k+(j+1)%k,i*k+(j+1)%k))
    poly(v,f,m)
def flush(name='body',smooth=False):
    objects=[]
    for material,(verts,faces) in list(B.items()):
        if not verts: continue
        mesh=bpy.data.meshes.new(name+'_'+material); mesh.from_pydata([conv(v) for v in verts],[],faces); mesh.materials.append(M[material]); mesh.update()
        obj=bpy.data.objects.new(name+'_'+material,mesh); bpy.context.collection.objects.link(obj)
        uv=mesh.uv_layers.new(name='UVMap')
        for face in mesh.polygons:
            face.use_smooth=smooth
            for li in face.loop_indices:
                co=mesh.vertices[mesh.loops[li].vertex_index].co; uv.data[li].uv=(co.x*.1,co.y*.1)
        objects.append(obj)
    B.clear()
    if len(objects)>1:
        bpy.ops.object.select_all(action='DESELECT')
        for o in objects:o.select_set(True)
        bpy.context.view_layer.objects.active=objects[0]; bpy.ops.object.join()
    if objects: objects[0].name=name
    return objects[0] if objects else None
def export(name):
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'blender',name+'.blend'))
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,name+'.glb'),export_format='GLB',export_apply=True,export_yup=True,export_animations=False,export_cameras=False,export_lights=False)
    print('EXPORTED',name)

# Smooth closed circuit, arc length sampled once and shared with Godot.
knots=[(-90,78),(-90,25),(-90,-45),(-70,-100),(-15,-122),(48,-115),(92,-75),(98,-22),(65,10),(85,50),(70,105),(15,125),(-48,115),(-82,100)]
raw=[]
for i in range(len(knots)):
    a,b,c,d=[Vector(knots[j%len(knots)]) for j in (i-1,i,i+1,i+2)]
    for j in range(80):
        t=j/80; raw.append((2*b+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t)*.5)
lengths=[0.0]
for i in range(len(raw)): lengths.append(lengths[-1]+(raw[(i+1)%len(raw)]-raw[i]).length)
L=lengths[-1]; N=math.ceil(L/1.8); points=[]; cursor=0
for i in range(N):
    s=L*i/N
    while lengths[cursor+1]<s: cursor+=1
    t=(s-lengths[cursor])/(lengths[cursor+1]-lengths[cursor]); p=raw[cursor].lerp(raw[(cursor+1)%len(raw)],t); points.append(p)
def track(i,offset=0,height=0):
    p=points[i%N]; t=(points[(i+1)%N]-points[(i-1)%N]).normalized(); n=Vector((-t.y,t.x)); p=p+n*offset
    return (p.x,height,p.y)
with open(os.path.join(ROOT,'assets','track.json'),'w') as f: json.dump({'length':L,'width':18,'points':[[p.x,0,p.y] for p in points],'boosts':[.10,.34,.61,.84]},f)

clear()
box((85,-1,0),(408,1.7,650),'grass')
box((-132,-.3,0),(26,.8,650),'sand')
# Road ribbon, white edge stripes, alternating curbs, crash barriers.
for i in range(N):
    j=(i+1)%N
    for a,b,m,h in [(-9,9,'road',.03),(-9.25,-9,'white',.045),(9,9.25,'white',.045),(-10.3,-9.25,'red' if (i//3)%2 else 'white',.065),(9.25,10.3,'red' if (i//3)%2 else 'white',.065)]:
        poly([track(i,a,h),track(i,b,h),track(j,b,h),track(j,a,h)],[(0,1,2,3)],m)
    if i%5==0:
        a=track(i); b=track(i+2); mid=tuple((x+y)/2 for x,y in zip(a,b)); angle=math.atan2(b[0]-a[0],b[2]-a[2]); box((mid[0],.047,mid[2]),(.16,.015,1.9),'cream',angle)
    for side in [-1,1]:
        p=track(i,side*11.0,.52); q=track(j,side*11.0,.52); angle=math.atan2(q[0]-p[0],q[2]-p[2]); dist=math.dist(p,q)
        box(tuple((x+y)/2 for x,y in zip(p,q)),(.48,1.0,dist+.07),'white' if (i//7)%2 else 'cyan',angle)
        if i%4==0: box(track(i,side*11.0,1.11),(.53,.12,.55),'gold',angle)
# Start/finish checker carpet.
for i in range(18):
    for j in range(4): box((-98.5+i,.055,75+j*.85),(1,.022,.85),'white' if (i+j)%2 else 'navy')
for x in [-102, -78]:
    box((x,4.3,72),(1.2,8.6,1.2),'navy'); box((x,4.3,72),(1.3,.35,1.3),'gold')
box((-90,8.1,72),(26,2.4,1.2),'navy')
box((-90,9.45,72),(27,.3,1.5),'cyan')
for x in range(-102,-77,2): box((x,7.25,71.35),(1,.5,.1),'white' if x%4 else 'gold')

def palm(x,z,h=9):
    lean=random.uniform(-1.3,1.3)
    for j in range(5): rod((x+lean*j/5,h*j/5,z),(x+lean*(j+1)/5,h*(j+1)/5,z),.3-j*.025,'trunk',.27-j*.025,8)
    crown=(x+lean,h,z)
    for i in range(9):
        a=i*math.tau/9+random.random()*.15; dx,dz=math.cos(a),math.sin(a); v=[];f=[]
        for j in range(10):
            t=j/9; reach=t*4.5; y=h+math.sin(t*math.pi)*1.1-t*t*1.4
            width=math.sin(t*math.pi)**.75*.48
            c=Vector((crown[0]+dx*reach,y,z+dz*reach)); side=Vector((-dz,0,dx))*width
            v.extend([tuple(c-side),tuple(c+Vector((0,.12,0))),tuple(c+side)])
        for j in range(9):
            for k in range(2):f.append((j*3+k,(j+1)*3+k,(j+1)*3+k+1,j*3+k+1))
        poly(v,f,'leaflight' if i%3 else 'leaf')
    for i in range(3):ell((x+lean+(i-1)*.3,h-.35,z+.2),(.27,.32,.26),'trunk',8,5)
def flowers(x,z):
    ell((x,.4,z),(1.6,.65,1.4),'leaf',10,6)
    for j in range(5): ell((x+random.uniform(-1,1),.9,z+random.uniform(-1,1)),(.18,.18,.18),'pink' if j%2 else 'gold',6,4)
for i in range(0,N,12):
    for side in [-1,1]:
        x,_,z=track(i,side*random.uniform(15,19)); palm(x,z,random.uniform(7.8,11.5))
        x,_,z=track(i+4,side*14); flowers(x,z)

# Rich, four-sided Kenney facade buildings and skyline are assembled by
# scripts/city.gd. Keeping them separate avoids blank back faces and shares
# the same geometry/materials between repeated city blocks.
# Independence-inspired pavilion in the central park.
for x in [-21,-14,-7,0,7,14,21]:
    for z in [27,41]:
        box((x,3.0,z),(.9,6,1),'cream'); box((x,.5,z),(1.6,1,1.6),'white'); box((x,5.7,z),(1.6,.5,1.6),'gold')
box((0,.2,34),(48,.5,21),'cream'); box((0,6.4,34),(49,1.1,22),'roof'); box((0,7.4,34),(43,1,18),'roof');box((0,8.3,34),(32,.8,12),'gold')
# Central plaza, lotus reflecting pool rim and tropical park.
rod((0,-.03,-25),(0,.05,-25),24,'cream',24,64)
rod((0,.05,-25),(0,.07,-25),19,'aqua',19,64)
for i in range(18):
    a=i*math.tau/18;palm(math.cos(a)*29,-25+math.sin(a)*29,8)
# promenade street lamps, banners and covered spectators.
for i in range(0,N,20):
    p=track(i,-12.6); x,_,z=p
    rod((x,0,z),(x,6,z),.12,'navy',n=8); rod((x,6,z),(x+1,6.5,z),.1,'navy',n=8);ell((x+1,6.35,z),(.55,.18,.45),'cream',8,5)
    box((x,4.7,z+.4),(1.4,2,.06),'pink' if i%40 else 'cyan')
for x,z in [(-52,91),(113,-40),(39,-139)]:
    box((x,1,z),(15,2,5),'navy'); box((x,2,z),(15,.2,5),'cream')
    for i in range(9):
        xx=x-6+i*1.5;ell((xx,2.9,z),(.35,.5,.35),['pink','cyan','gold'][i%3],8,5);ell((xx,3.55,z),(.28,.3,.28),'muzzle',8,5)
# Seaside boulders and occasional sails.
for i in range(85):ell((-134+random.uniform(-3,3),-.4,random.uniform(-200,200)),(random.uniform(1,3),random.uniform(.8,1.5),random.uniform(1,3)),'cream',8,5)
for x,z in [(-175,-80),(-205,55),(-245,-150)]:
    ell((x,-.45,z),(2,.5,6),'roof',10,6); rod((x,0,z),(x,10,z),.09,'white',n=6)
    poly([(x,9,z),(x,1,z),(x+5,1,z)],[(0,1,2)],'cream')
flush('LotusCoast_Static',False);export('lotus_coast')

clear()
# Stylized architectural lotus monument, proportioned to dominate the skyline.
rod((0,0,0),(0,3,0),9,'cream',8,48)
rod((0,3,0),(0,6,0),7,'gold',5,40)
rod((0,6,0),(0,62,0),3.8,'aqua',2.5,40)
for y in [8,13,18,23,28,33,38,43,48,53,58]:torus((0,y,0),3.8-(y-6)*.023,.09,'cream',n=40,k=6)
rod((0,61,0),(0,65,0),5,'gold',8,48)
ell((0,72,0),(10,12,10),'pink',32,20)
for i in range(10):
    a=i*math.tau/10
    p=(math.cos(a)*7,71,math.sin(a)*7);ell(p,(3.8,9,3.8),'pink' if i%2 else 'purple',16,12)
    rod((math.cos(a)*8,65,math.sin(a)*8),(math.cos(a)*3,82,math.sin(a)*3),.14,'gold',n=6)
rod((0,82,0),(0,94,0),.65,'cream',.15,16)
rod((0,94,0),(0,103,0),.15,'gold',.03,8)
flush('LotusTower',True);export('lotus_tower')

if '--world-only' in sys.argv:
    print('WORLD_ASSET_PIPELINE_COMPLETE',round(L,2),'metres',N,'samples')
    sys.exit(0)

for color in ['blue','coral','aqua','pink']:
    clear()
    # Distinct chassis parts, low wide silhouette, front points toward -Z.
    ell((0,.6,0),(1.05,.32,1.8),color,24,12)
    ell((0,.67,-1.12),(.81,.31,.9),color,24,12)
    ell((0,.61,-1.65),(.91,.18,.42),'white',20,10)
    box((0,.39,-1.85),(1.9,.13,.3),'navy')
    for side in [-1,1]:
        ell((side*.88,.66,-.6),(.32,.34,1.1),color,20,10)
        ell((side*.59,.78,-1.65),(.27,.075,.14),'cyan',12,6)
        rod((side*.78,.7,.8),(side*.78,1.2,1.45),.09,'gold',n=8)
        rod((side*.5,.47,1.15),(side*.5,.47,1.9),.17,'navy',n=12)
        torus((side*.5,.47,1.91),.16,.055,'gold',n=12,k=6)
        box((side*.65,.92,-.25),(.14,.03,1.65),'gold')
    box((0,1.22,1.45),(2.25,.16,.38),color)
    box((0,1.31,1.45),(2.3,.05,.4),'gold')
    ell((0,.78,.35),(.63,.15,.8),'navy',18,8)
    ell((0,1.05,.8),(.55,.5,.13),'navy',16,8)
    torus((0,1.0,-.48),.3,.05,'navy',axis='x',n=16,k=6)
    flush('body',True)
    for side,label in [(-1,'left'),(1,'right')]:
        for z,axle in [(-1.13,'front'),(1.03,'back')]:
            x=side*1.08
            torus((x,.46,z),.34,.15,'rubber',axis='x',n=20,k=10)
            rod((x-side*.19,.46,z),(x+side*.2,.46,z),.27,'gold',n=16)
            rod((x+side*.201,.46,z),(x+side*.22,.46,z),.15,'navy',n=10)
            for a in range(5):
                ang=a*math.tau/5;rod((x+side*.23,.46,z),(x+side*.23,.46+math.cos(ang)*.24,z+math.sin(ang)*.24),.035,'white',n=5)
            o=flush('wheel-'+axle+'-'+label,True)
            # Move mesh coordinates into wheel-local space for correct animated pivots.
            pivot=Vector(conv((x,.46,z)))
            for v in o.data.vertices:v.co-=pivot
            o.location=pivot
    export('kart_'+color)

for animal in ['hedgehog','lion','elephant','parrot']:
    clear();color={'hedgehog':'blue','lion':'gold','elephant':'purple','parrot':'green'}[animal]
    ell((0,1.18,.19),(.43,.53,.37),color,20,12)
    ell((0,1.25,-.12),(.25,.3,.1),'muzzle',16,8)
    ell((0,1.91,.13),(.63,.62,.51),color,24,16)
    if animal=='hedgehog':
        for x,y,z in [(-.42,2.05,.3),(.42,2.05,.3),(-.36,1.7,.45),(.36,1.7,.45),(0,2.22,.37),(0,1.8,.55)]:
            rod((x*.6,y,z-.15),(x*1.8,y-.27,z+.73),.29,'blue',.015,12)
        for s in [-1,1]:
            rod((s*.42,2.2,.1),(s*.48,2.72,.1),.24,'blue',.02,12)
            rod((s*.42,2.3,-.055),(s*.48,2.59,-.05),.13,'muzzle',.01,10)
    elif animal=='lion':
        for j in range(12):
            a=j*math.tau/12;ell((math.cos(a)*.6,1.97+math.sin(a)*.59,.32),(.28,.3,.25),'trunk',12,8)
        for s in [-1,1]:ell((s*.5,2.36,.05),(.22,.22,.14),'gold',12,8)
    elif animal=='elephant':
        for s in [-1,1]:ell((s*.65,1.97,.1),(.45,.55,.14),'purple',18,12);ell((s*.66,1.97,-.02),(.3,.39,.04),'pink',14,8)
        rod((0,1.75,-.43),(0,1.32,-.62),.16,'purple',.12,16)
        rod((0,1.32,-.62),(.18,1.3,-.72),.12,'purple',.08,14)
    else:
        for j in range(3):rod((0,2.35,.05),((j-1)*.22,2.85,.2),.18,'red',.02,10)
        rod((0,1.85,-.35),(0,1.55,-.78),.28,'gold',.02,14)
    # Friendly face and sculpted muzzle, readable at racing distance.
    if animal not in ['elephant','parrot']:
        ell((0,1.72,-.33),(.48,.25,.28),'muzzle',20,10)
        ell((0,1.83,-.61),(.105,.08,.09),'black',12,8)
        rod((.08,1.6,-.57),(.3,1.65,-.53),.022,'trunk',n=6)
    for s in [-1,1]:
        ell((s*.23,2.03,-.34),(.23,.31,.14),'white',20,12)
        ell((s*.19,2.03,-.473),(.09,.17,.045),'green' if animal=='hedgehog' else 'aqua',14,8)
        ell((s*.18,2.03,-.51),(.046,.12,.025),'black',12,8)
        ell((s*.16,2.1,-.53),(.022,.04,.012),'white',10,6)
        rod((s*.36,1.4,.05),(s*.4,1.07,-.48),.12,color,n=12)
        ell((s*.4,1.07,-.48),(.17,.15,.18),'white',14,10)
    flush('driver_'+animal,True);export('driver_'+animal)
print('ASSET_PIPELINE_COMPLETE',round(L,2),'metres',N,'samples')
