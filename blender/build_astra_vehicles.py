"""Original Astra racers and Shaven Leo. Blender 4.5, metres, Godot -Z forward.

blender --background --factory-startup --python blender/build_astra_vehicles.py
All four wheel objects have applied identity bases and independent X axles.
No purchased, downloaded, or trademarked mesh geometry is used.
"""
import bpy
import json
import math
import hashlib
import struct
from pathlib import Path
from collections import defaultdict
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/models/astra'
SRC = OUT / 'source'
AUDIT = ROOT / 'docs/qa-astra/model-audit.json'
OUT.mkdir(parents=True, exist_ok=True)
SRC.mkdir(parents=True, exist_ok=True)
SRC.joinpath('.gdignore').write_text('', encoding='utf-8')
AUDIT.parent.mkdir(parents=True, exist_ok=True)
B = defaultdict(lambda: [[], []])
M = {}
REPORT = {'authorship': 'Original procedural Blender artwork for Leo Racer, 2026',
          'license': 'CC0-1.0; authored for this project', 'forward': '-Z', 'units': 'metres',
          'wheel_contract': 'Independent mesh nodes; identity local bases; X axles; Y=.49', 'models': {}}


def material(name, hex_color, rough=.3, metal=0., glow=0.):
    rgb = [int(hex_color[i:i+2], 16)/255. for i in (0, 2, 4)]
    linear = [v / 12.92 if v <= .04045 else ((v+.055)/1.055)**2.4 for v in rgb]
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*linear, 1.)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*linear, 1.)
    p.inputs['Roughness'].default_value = rough
    p.inputs['Metallic'].default_value = metal
    p.inputs['Coat Weight'].default_value = .35 if rough < .4 else .05
    p.inputs['Coat Roughness'].default_value = .14
    if glow:
        p.inputs['Emission Color'].default_value = (*linear, 1.)
        p.inputs['Emission Strength'].default_value = glow
    M[name] = m


for args in [
    ('blue', '1d4ed8', .2, .9), ('coral', 'd32235', .23, .7),
    ('gold', 'd4af37', .2, .9), ('ivory', 'eee7d6', .27, .3),
    ('navy', '111d32', .3, .4), ('rubber', '14191d', .84, 0),
    ('tread', '242a30', .75, 0), ('carbon', '18232b', .43, .35),
    ('cyan', '40eaff', .17, .35, 3), ('red_lamp', 'ff3538', .2, .2, 2),
    ('amber', 'ff9b1e', .2, .4, 1.4), ('orange', 'ff7c21', .38, .2),
    ('green', '00a46a', .26, .7), ('glass', '063a50', .12, .6),
    ('white', 'f8fcff', .4, .1), ('skin', 'b97549', .55, 0),
    ('skin_shadow', '955334', .57, 0), ('mouth', '341b21', .61, 0),
    ('brown', '3b271f', .65, 0), ('iris', '694926', .35, 0),
    ('silver', 'bcc9d3', .22, .8)]:
    material(*args)


def conv(p):
    return Vector((p[0], -p[2], p[1]))


def clear():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    B.clear()


def poly(v, f, m):
    vs, fs = B[m]
    off = len(vs)
    vs.extend(v)
    fs.extend([tuple(off+i for i in face) for face in f])


def box(p, s, m):
    x, y, z = p
    a, b, c = [n*.5 for n in s]
    poly([(x+dx, y+dy, z+dz) for dx, dy, dz in [
        (-a,-b,-c),(a,-b,-c),(a,b,-c),(-a,b,-c),
        (-a,-b,c),(a,-b,c),(a,b,c),(-a,b,c)]],
        [(0,3,2,1),(4,5,6,7),(0,1,5,4),(3,7,6,2),(0,4,7,3),(1,2,6,5)], m)


def ell(p, s, m, n=24, rings=12):
    v, f = [], []
    for j in range(rings+1):
        a = math.pi*j/rings
        for i in range(n):
            b = math.tau*i/n
            v.append((p[0]+s[0]*math.sin(a)*math.cos(b),
                      p[1]+s[1]*math.cos(a), p[2]+s[2]*math.sin(a)*math.sin(b)))
    for j in range(rings):
        for i in range(n):
            f.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
    poly(v, f, m)


def rod(a, b, radius, m, radius2=None, n=12):
    a, b = Vector(a), Vector(b)
    d = (b-a).normalized()
    t = d.cross(Vector((0,1,0)))
    if t.length < .01:
        t = d.cross(Vector((1,0,0)))
    t.normalize()
    q = d.cross(t).normalized()
    v, f = [], []
    for p, r in [(a,radius),(b,radius if radius2 is None else radius2)]:
        for i in range(n):
            v.append(tuple(p+r*(t*math.cos(i*math.tau/n)+q*math.sin(i*math.tau/n))))
    f = [tuple(range(n-1,-1,-1)), tuple(range(n,2*n))]
    for i in range(n):
        f.append((i,(i+1)%n,(i+1)%n+n,i+n))
    poly(v, f, m)


def ring(p, radius, tube, m, axis='x', n=40, k=10):
    v, f = [], []
    for i in range(n):
        a = i*math.tau/n
        for j in range(k):
            b = j*math.tau/k
            r = radius+tube*math.cos(b)
            if axis == 'x':
                off = (tube*math.sin(b), r*math.cos(a), r*math.sin(a))
            else:
                off = (r*math.cos(a), r*math.sin(a), tube*math.sin(b))
            v.append(tuple(p[t]+off[t] for t in range(3)))
    for i in range(n):
        for j in range(k):
            f.append((i*k+j,((i+1)%n)*k+j,((i+1)%n)*k+(j+1)%k,i*k+(j+1)%k))
    poly(v,f,m)


def loft(rings, m, n=32):
    """Each ring is z, half-width, half-height, vertical centre."""
    v, f = [], []
    for z, w, h, cy in rings:
        for i in range(n):
            a = math.tau*i/n
            v.append((w*math.cos(a),cy+h*math.sin(a),z))
    for j in range(len(rings)-1):
        for i in range(n):
            f.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
    f.extend([tuple(range(n-1,-1,-1)),tuple(range((len(rings)-1)*n,len(rings)*n))])
    poly(v,f,m)


def stripe(z1, z2, y1, y2, width=.16, m='gold', x=0):
    poly([(x-width/2,y1,z1),(x+width/2,y1,z1),
          (x+width/2,y2,z2),(x-width/2,y2,z2)],[(0,1,2,3)],m)


def flush(name, pivot=(0,0,0), smooth=True):
    objects = []
    pivot = conv(pivot)
    for key, (v, f) in B.items():
        if not v:
            continue
        mesh = bpy.data.meshes.new(name+'_'+key)
        mesh.from_pydata([conv(p)-pivot for p in v],[],f)
        mesh.materials.append(M[key])
        mesh.update()
        uv = mesh.uv_layers.new(name='UVMap')
        for p in mesh.polygons:
            p.use_smooth = smooth
            for li in p.loop_indices:
                co = mesh.vertices[mesh.loops[li].vertex_index].co
                uv.data[li].uv = (co.x, co.y)
        ob = bpy.data.objects.new(name+'_'+key,mesh)
        bpy.context.collection.objects.link(ob)
        ob.location = pivot
        objects.append(ob)
    B.clear()
    bpy.ops.object.select_all(action='DESELECT')
    for ob in objects:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    ob = objects[0]
    ob.name = name
    ob.rotation_euler = (0,0,0)
    ob.scale = (1,1,1)
    return ob


def wheel(x, z, axle, side, radius=.49, width=.34):
    p = (x,radius,z)
    ring(p,radius-.105,.105,'rubber',n=40,k=10)
    for dx in [-.095,0,.095]:
        ring((x+dx,radius,z),radius-.012,.009,'tread',n=40,k=4)
    sign = -1 if x < 0 else 1
    rod((x-width*.42,radius,z),(x+width*.42,radius,z),radius*.64,'gold',n=24)
    outside = x+sign*width*.44
    rod((outside,radius,z),(outside+sign*.012,radius,z),radius*.49,'carbon',n=24)
    for i in range(7):
        a = i*math.tau/7
        rod((outside+sign*.024,radius,z),
            (outside+sign*.025,radius+math.cos(a)*radius*.57,z+math.sin(a)*radius*.57),
            .026,'gold',n=5)
        ell((outside+sign*.026,radius+math.cos(a)*.11,z+math.sin(a)*.11),(.018,.023,.023),'silver',8,5)
    rod((outside,radius,z),(outside+sign*.045,radius,z),.07,'gold',n=16)
    ring((outside+sign*.033,radius,z),radius*.7,.016,'ivory',n=32,k=5)
    flush('wheel-%s-%s'%(axle,side),p)


def four_wheels(front=-1.22,rear=1.12,width=.94,front_width=None):
    for z, axle in [(front,'front'),(rear,'back')]:
        for sign, side in [(-1,'left'),(1,'right')]:
            wheel(sign*(front_width if axle=='front' and front_width else width),z,axle,side)


def seat(z=.28,y=.78):
    ell((0,y,z),(.48,.12,.62),'carbon',24,8)
    ell((0,y+.25,z+.43),(.44,.42,.14),'carbon',24,12)
    for sign in [-1,1]:
        rod((sign*.32,y+.15,z+.4),(sign*.32,y+.42,z+.4),.045,'orange',n=8)
    ring((0,y+.25,z-.67),.26,.038,'carbon',axis='z',n=24,k=8)


def rear_pack(z, body, width=1.06,y=1.28):
    for sign in [-1,1]:
        rod((sign*.69,.68,z-.21),(sign*.69,y,z),.052,'gold',n=10)
        box((sign*width,y,z),(.075,.35,.58),body)
        rod((sign*.5,.47,z-.22),(sign*.5,.47,z+.39),.14,'carbon',n=20)
        ring((sign*.5,.47,z+.4),.138,.028,'gold',axis='z',n=24,k=8)
        ring((sign*.5,.47,z+.408),.095,.02,'cyan',axis='z',n=24,k=6)
        ell((sign*.67,.84,z+.19),(.17,.055,.035),'red_lamp',16,8)
    loft([(z-.24,width,.055,y),(z+.20,width,.055,y+.04)],body,24)
    box((0,y+.062,z+.03),(width*2,.025,.40),'gold')
    box((0,.32,z+.28),(1.65,.12,.28),'carbon')
    for x in [-.6,-.3,0,.3,.6]:
        box((x,.28,z+.28),(.045,.22,.28),'carbon')


def formula(name,body):
    clear()
    loft([(-2.05,.10,.065,.49),(-1.80,.25,.12,.51),(-1.15,.36,.21,.58),
          (-.48,.47,.26,.65),(.25,.47,.22,.64),(1.10,.48,.21,.61),(1.54,.32,.14,.59)],body)
    # Sidepods and sculpted raised wheel guards retain a low open-wheel silhouette.
    for sign in [-1,1]:
        ell((sign*.60,.55,.25),(.28,.23,.94),body,24,12)
        ell((sign*.69,.65,-.12),(.08,.105,.33),'carbon',16,8)
        rod((sign*.36,.42,-1.18),(sign*.91,.43,-1.22),.045,'carbon',n=8)
        rod((sign*.4,.63,-.65),(sign*.91,.53,-1.22),.035,'silver',n=8)
        rod((sign*.41,.43,.82),(sign*.91,.45,1.12),.052,'carbon',n=8)
        rod((sign*.42,.54,-.55),(sign*.60,.87,-.57),.025,'gold',n=8)
        ell((sign*.62,.87,-.59),(.13,.055,.08),body,16,8)
        ell((sign*.67,.62,-1.65),(.18,.045,.08),'cyan',16,8)
        box((sign*.59,.71,.13),(.065,.025,.98),'gold')
    loft([(-1.93,1.04,.045,.35),(-1.65,1.04,.055,.36)],body,24)
    box((0,.416,-1.79),(2.08,.025,.15),'gold')
    for sign in [-1,1]:
        box((sign*1.04,.42,-1.79),(.055,.25,.34),body)
    stripe(-1.86,-.51,.639,.925,.15,'ivory' if body=='coral' else 'gold')
    seat(.26,.78)
    rear_pack(1.65,body,y=1.31)
    flush('body')
    four_wheels()
    export(name,dict(driver_position=[0,0,0],driver_scale=[1,1,1],
                     collision_size=[2.20,1.4,3.8],collision_position=[0,.78,0],
                     wheel_radius=.49,exhausts=[[-.5,.47,2.05],[.5,.47,2.05]]))


def roadster():
    clear()
    loft([(-2.01,.31,.08,.46),(-1.82,.69,.18,.52),(-1.32,.91,.30,.61),
          (-.75,.90,.34,.65),(-.15,.76,.29,.65),(.55,.77,.29,.63),
          (1.15,.85,.26,.61),(1.68,.65,.16,.56)],'blue')
    # Swept fenders, gold blade accents, and real intake mouths.
    for sign in [-1,1]:
        ell((sign*.77,.66,-.79),(.27,.33,1.05),'blue',28,14)
        ell((sign*.82,.62,.77),(.27,.28,.8),'blue',24,12)
        ell((sign*.64,.52,-1.81),(.25,.10,.06),'carbon',20,8)
        poly([(sign*.34,.71,-1.78),(sign*.78,.83,-1.52),(sign*.91,.72,-1.48),
              (sign*.72,.64,-1.72)],[(0,1,2,3)],'cyan')
        rod((sign*.9,.34,-1.58),(sign*.91,.34,.9),.035,'gold',n=10)
        ell((sign*.67,.83,-.02),(.105,.06,.25),'carbon',16,8)
        rod((sign*.65,.91,-.4),(sign*.95,1.02,-.38),.03,'gold',n=8)
        ell((sign*.97,1.02,-.4),(.12,.06,.085),'blue',16,8)
    box((0,.34,-1.89),(1.85,.08,.18),'carbon')
    box((0,.39,-1.97),(1.74,.035,.10),'gold')
    stripe(-1.99,-.52,.552,.992,.18)
    for x in [-.28,.28]:
        stripe(-1.76,-.6,.704,.985,.045,'ivory',x)
    ell((0,.91,.12),(.61,.11,.76),'carbon',28,10)
    seat(.30,.84)
    rear_pack(1.64,'blue',y=1.35)
    flush('body')
    four_wheels(front=-1.18,rear=1.02,width=.94)
    export('kart_roadster_gold',dict(driver_position=[0,.06,0],driver_scale=[1,1,1],
           collision_size=[2.2,1.4,3.85],collision_position=[0,.78,0],wheel_radius=.49,
           exhausts=[[-.5,.47,2.04],[.5,.47,2.04]]))


def tuk():
    clear()
    loft([(-1.82,.35,.08,.47),(-1.43,.47,.27,.61),(-.65,.65,.26,.63),
          (.15,.76,.29,.65),(1.38,.80,.29,.65),(1.75,.65,.22,.61)],'green')
    # Three-wheel silhouette uses close paired front wheels for shared controls.
    for sign in [-1,1]:
        ell((sign*.68,.72,1.04),(.24,.27,.76),'green',24,12)
        box((sign*.74,.86,.53),(.09,.35,1.52),'coral')
        rod((sign*.70,1.0,.20),(sign*.70,1.93,.20),.045,'gold',n=10)
        rod((sign*.70,1.0,1.32),(sign*.70,1.93,1.32),.045,'gold',n=10)
        # Slim roof sits behind driver, leaving every selectable head visible.
        rod((sign*.70,1.93,.2),(sign*.70,1.93,1.34),.065,'carbon',n=12)
        box((sign*.77,.45,.35),(.20,.08,1.80),'gold')
        ell((sign*.32,.79,-1.51),(.15,.12,.055),'cyan',20,10)
        ell((sign*.33,.57,-1.58),(.08,.05,.03),'amber',12,6)
        ell((sign*.58,.9,1.62),(.09,.16,.035),'red_lamp',12,8)
        rod((sign*.26,.78,-.75),(sign*.68,1.04,-.75),.026,'silver',n=8)
        ell((sign*.70,1.08,-.77),(.11,.13,.06),'carbon',16,8)
    loft([(.10,.76,.07,1.95),(.5,.79,.10,2.0),(1.36,.76,.07,1.95)],'carbon',24)
    box((0,2.05,.72),(1.53,.04,1.14),'ivory')
    box((0,1.08,1.5),(1.39,.17,.09),'gold')
    box((0,.45,-1.77),(.96,.14,.18),'carbon')
    box((0,.54,-1.84),(.86,.075,.10),'gold')
    ell((0,.83,-1.42),(.16,.16,.06),'ivory',20,10)
    seat(-.20,.84)
    rear_pack(1.72,'green',width=.91,y=1.26)
    flush('body')
    four_wheels(front=-1.28,rear=1.06,width=.83,front_width=.17)
    export('kart_race_tuk',dict(driver_position=[0,.06,-.44],driver_scale=[.94,.94,.94],
           collision_size=[2.05,2.1,3.65],collision_position=[0,1.06,0],wheel_radius=.49,
           exhausts=[[-.5,.47,2.12],[.5,.47,2.12]]))


def bus():
    clear()
    # Compact coach with open driver cab. Detailed glowing route plaque is mesh-authored.
    loft([(-2.02,.67,.18,.65),(-1.78,.89,.37,.73),(-.9,.89,.38,.75),
          (.9,.89,.38,.75),(1.82,.79,.29,.69),(2.02,.60,.13,.62)],'coral',32)
    box((0,1.18,.68),(1.73,.25,2.25),'ivory')
    for sign in [-1,1]:
        box((sign*.85,1.63,.72),(.09,.7,2.10),'coral')
        for z in [-.08,.57,1.22]:
            box((sign*.905,1.62,z),(.035,.46,.49),'glass')
            box((sign*.927,1.35,z),(.045,.045,.57),'gold')
        box((sign*.89,.83,.4),(.04,.13,2.67),'gold')
        ell((sign*.62,.83,-1.96),(.22,.12,.045),'cyan',20,10)
        ell((sign*.66,.50,-1.94),(.17,.055,.04),'amber',16,8)
        ell((sign*.66,.85,1.89),(.11,.18,.035),'red_lamp',16,8)
        box((sign*.91,.40,.18),(.18,.09,3.0),'carbon')
        rod((sign*.88,1.12,-1.0),(sign*1.03,1.30,-1.1),.03,'gold',n=8)
        ell((sign*1.035,1.30,-1.12),(.08,.13,.07),'coral',16,8)
    loft([(-.4,.86,.065,2.02),(.0,.91,.12,2.08),(1.73,.87,.09,2.04)],'ivory',24)
    for x in [-.48,.48]:
        box((x,2.18,.72),(.14,.045,1.77),'gold')
    box((0,1.98,-.43),(1.57,.22,.13),'carbon')
    # Route 27 gold bars imply a small illuminated destination screen at racing distance.
    for x in [-.56,-.39,-.22,-.05,.12,.29,.46]:
        box((x,1.99,-.51),(.10,.065,.025),'amber')
    box((0,.61,-2.02),(1.02,.26,.055),'carbon')
    for y in [.52,.61,.70]:
        box((0,y,-2.06),(.94,.024,.024),'silver')
    box((0,.35,-2.05),(1.82,.09,.18),'gold')
    box((0,.31,1.96),(1.7,.12,.22),'carbon')
    seat(-.98,.91)
    rear_pack(1.72,'coral',width=.98,y=2.28)
    flush('body')
    four_wheels(front=-1.24,rear=1.22,width=.94)
    export('kart_race_bus',dict(driver_position=[0,.12,-1.2],driver_scale=[.89,.89,.89],
           collision_size=[2.2,2.3,4.2],collision_position=[0,1.17,0],wheel_radius=.49,
           exhausts=[[-.5,.47,2.12],[.5,.47,2.12]]))


def human():
    clear()
    # Friendly original shaved-head human, seated exactly like the existing drivers.
    ell((0,1.15,.20),(.39,.47,.32),'blue',28,16)
    ell((0,1.40,.16),(.45,.18,.30),'blue',24,10)
    rod((0,1.47,.14),(0,1.65,.14),.17,'skin',n=20)
    for sign in [-1,1]:
        ell((sign*.35,.88,-.08),(.16,.20,.32),'blue',20,10)
        rod((sign*.34,1.35,.07),(sign*.46,1.15,-.19),.12,'blue',n=16)
        rod((sign*.46,1.15,-.19),(sign*.39,1.05,-.49),.105,'blue',n=16)
        rod((sign*.40,1.31,-.03),(sign*.49,1.15,-.24),.045,'orange',n=10)
        ell((sign*.39,1.05,-.49),(.16,.14,.17),'ivory',20,12)
        ell((sign*.40,1.13,-.50),(.115,.045,.105),'orange',16,8)
        ell((sign*.33,.77,-.29),(.16,.12,.28),'carbon',20,10)
        rod((sign*.25,1.42,-.065),(sign*.19,1.04,-.12),.04,'orange',n=10)
    # Tailored suit centre, shoulder piping, collar and belt buckle.
    box((0,1.20,-.12),(.055,.51,.035),'gold')
    box((0,.94,-.11),(.53,.065,.045),'carbon')
    box((0,.95,-.15),(.10,.08,.025),'gold')
    ell((-.20,1.31,-.125),(.075,.09,.025),'orange',12,8)
    for sign in [-1,1]:
        rod((sign*.14,1.51,.03),(sign*.34,1.47,.025),.042,'ivory',n=10)
    # Exaggerated animated-feature proportions, rounded cheeks and subtle scalp crown.
    ell((0,1.99,.12),(.48,.57,.43),'skin',32,20)
    ell((0,1.72,-.10),(.39,.28,.36),'skin',28,16)
    for sign in [-1,1]:
        ell((sign*.47,1.95,.085),(.115,.18,.09),'skin',20,12)
        ell((sign*.49,1.96,.012),(.063,.10,.025),'skin_shadow',16,8)
        ell((sign*.26,1.81,-.27),(.16,.16,.13),'skin',24,12)
        ell((sign*.19,2.05,-.247),(.16,.18,.105),'white',24,16)
        ell((sign*.17,2.045,-.34),(.074,.105,.033),'iris',20,12)
        ell((sign*.17,2.05,-.369),(.043,.077,.022),'mouth',16,10)
        ell((sign*.145,2.086,-.389),(.021,.028,.012),'white',12,8)
        rod((sign*.07,2.24,-.285),(sign*.30,2.255,-.237),.04,'brown',n=12)
    ell((0,1.94,-.355),(.10,.13,.12),'skin',24,14)
    ell((0,1.80,-.347),(.235,.102,.033),'mouth',28,12)
    ell((0,1.833,-.378),(.19,.041,.014),'ivory',24,10)
    ell((0,1.73,-.30),(.16,.055,.065),'skin',20,10)
    # Back-mounted gold racing chevrons are readable from the chase camera.
    for y in [1.10,1.22,1.34]:
        rod((-.20,y,.478),(0,y-.08,.515),.025,'orange',n=8)
        rod((0,y-.08,.515),(.20,y,.478),.025,'orange',n=8)
    flush('Shaven_Leo')
    export('driver_human',dict(display_name='Shaven Leo',driver_position=[0,0,0],
           driver_scale=[1,1,1],seated=True,compatible_with='all Astra and original karts'))


def export(name, metadata):
    objects = [o for o in bpy.context.scene.objects if o.type=='MESH']
    pts = [o.matrix_world @ v.co for o in objects for v in o.data.vertices]
    lo = [min(p[i] for p in pts) for i in range(3)]
    hi = [max(p[i] for p in pts) for i in range(3)]
    tris = sum(sum(len(p.vertices)-2 for p in ob.data.polygons) for ob in objects)
    wheels = []
    for ob in objects:
        if ob.name.startswith('wheel-'):
            assert all(abs(v)<1e-7 for v in ob.rotation_euler), ob.name
            assert all(abs(v-1)<1e-7 for v in ob.scale), ob.name
            loc = ob.location
            wheels.append({'name':ob.name,'godot_center':[round(loc.x,5),round(loc.z,5),round(-loc.y,5)],
                           'local_basis_identity':True,'axis':'X'})
    if name.startswith('kart_'):
        assert len(wheels)==4
        assert tris < 30000, (name,tris)
    bpy.context.scene['leo_asset'] = name
    bpy.context.scene['license'] = 'CC0-1.0 original Leo Racer artwork'
    for ob in objects:
        ob['leo_asset'] = name
    bpy.ops.wm.save_as_mainfile(filepath=str(SRC/(name+'.blend')))
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',
        export_apply=True,export_yup=True,export_animations=False,export_cameras=False,
        export_lights=False,export_extras=True)
    raw = (OUT/(name+'.glb')).read_bytes()
    chunk_length, chunk_type = struct.unpack_from('<II',raw,12)
    assert chunk_type == 0x4e4f534a
    gltf = json.loads(raw[20:20+chunk_length])
    exported_wheels = [node for node in gltf['nodes'] if node.get('name','').startswith('wheel-')]
    for node in exported_wheels:
        assert 'rotation' not in node and 'scale' not in node and 'matrix' not in node, node
        assert abs(node['translation'][1]-.49) < 1e-5
    if name.startswith('kart_'):
        assert len(exported_wheels) == 4
    metadata.update({'triangles':tris,'mesh_nodes':len(objects),'wheels':wheels,
                     'godot_bounds_min':[round(lo[0],4),round(lo[2],4),round(-hi[1],4)],
                     'godot_bounds_max':[round(hi[0],4),round(hi[2],4),round(-lo[1],4)],
                     'glb':'assets/models/astra/'+name+'.glb',
                     'editable_source':'assets/models/astra/source/'+name+'.blend',
                     'glb_bytes':len(raw),'glb_sha256':hashlib.sha256(raw).hexdigest(),
                     'exported_wheel_contract_verified':len(exported_wheels)==4 if name.startswith('kart_') else None})
    REPORT['models'][name] = metadata
    print('ASTRA_EXPORTED',name,tris,'triangles',flush=True)


formula('kart_formula_blue','blue')
formula('kart_formula_red','coral')
roadster()
tuk()
bus()
human()
AUDIT.write_text(json.dumps(REPORT,indent=2)+'\n',encoding='utf-8')
print('ASTRA_MODEL_PIPELINE_COMPLETE',str(AUDIT),flush=True)
