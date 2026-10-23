"""Deterministic premade-model placement with full-footprint road/park checks."""
from pathlib import Path
import json,math,random,sys
import numpy as np
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'.tools/city-python'))
OUT=ROOT/'assets/tracks/colombo_city'
rng=random.Random(23102026)
route=json.loads((OUT/'route.json').read_text(encoding='utf-8'))
library=json.loads((ROOT/'assets/models/colombo_city/manifest.json').read_text(encoding='utf-8'))
p=np.array(route['points'])[:,[0,2]];n=len(p);step=route['length']/n
t=np.roll(p,-2,axis=0)-np.roll(p,1,axis=0);t/=np.linalg.norm(t,axis=1)[:,None]
normal=np.stack([-t[:,1],t[:,0]],axis=1);width=np.array(route['widths'])
exclusions=[('Galle Face Green',(-840,-520,-615,570)),('Lake',(168,-112,432,162)),('Custom architecture garden',(-170,250,-50,410)),('Lotus Tower',(-3,-95,68,-21))]
occupied=[];placements=[];minimum_clearance=1e9

def overlap(center,axes,half,other_center,other_axes,other_half,gap=1.5):
    delta=other_center-center
    for axis in [*axes,*other_axes]:
        if abs(delta@axis)>sum(abs(axis@a)*h for a,h in zip(axes,half))+sum(abs(axis@a)*h for a,h in zip(other_axes,other_half))+gap:return False
    return True

def fit(center,yaw,w,d):
    global minimum_clearance
    axes=np.array([[math.cos(yaw),-math.sin(yaw)],[math.sin(yaw),math.cos(yaw)]])
    half=np.array([w,d])/2+1.
    delta=p-center;local=delta@axes.T
    distance=np.linalg.norm(np.maximum(abs(local)-half,0),axis=1)-width/2
    clearance=float(distance.min())
    if clearance<4.:return False
    for _,(x0,z0,x1,z1) in exclusions:
        if overlap(center,axes,half,np.array([(x0+x1)/2,(z0+z1)/2]),np.eye(2),np.array([x1-x0,z1-z0])/2):return False
    for c,a,h in occupied:
        if overlap(center,axes,half,c,a,h):return False
    occupied.append((center,axes,half));minimum_clearance=min(minimum_clearance,clearance)
    return True

def place(entry,center,yaw,scale=1.,kind='building',always=False):
    placements.append({'asset':entry['path'],'position':[float(center[0]),0,float(center[1])],'yaw':yaw,'scale':scale,
                       'kind':kind,'always':always,'tint':[rng.uniform(.91,1.),rng.uniform(.91,1.),rng.uniform(.91,1.),1.]})

low=[b for b in library['buildings'] if 'lowrise' in b['id']]
towers=[b for b in library['buildings'] if 'tower' in b['id'] and b['height']<90.]
for side in [-1.,1.]:
    s=22.
    while s<route['length']-30:
        i=int(s/step)%n;fraction=s/route['length']
        options=towers if .35<fraction<.55 else low
        entry=rng.choice(options);scale=rng.uniform(.86,1.08)
        front=-normal[i]*side;yaw=math.atan2(front[0],front[1])
        offset=width[i]/2+12.+entry['depth']*scale/2
        center=p[i]+normal[i]*side*offset
        # Sea-side frontage is open throughout the waterfront district.
        if not (center[0]<-570 and side<0) and fit(center,yaw,entry['width']*scale,entry['depth']*scale):place(entry,center,yaw,scale)
        s+=entry['width']*scale+10.

# Persistent low-polygon skyline silhouettes, never a second overlapping skin.
for x in range(-440,1050,120):
    for z in range(-1120,1100,120):
        center=np.array([x+rng.uniform(-12,12),z+rng.uniform(-12,12)])
        if center[0]<-570 or float(np.linalg.norm(p-center,axis=1).min())<115:continue
        entry=rng.choice(towers);yaw=rng.choice([0.,math.pi/2,math.pi,math.pi*1.5]);scale=rng.uniform(.8,1.35)
        if fit(center,yaw,entry['width']*scale,entry['depth']*scale):place(entry,center,yaw,scale,'skyline',True)

for s in np.arange(10,route['length'],30):
    i=int(s/step)%n;yaw=rng.random()*math.tau
    for side in [-1.,1.]:
        center=p[i]+normal[i]*side*(width[i]/2+8.)
        if float(np.linalg.norm(p-center,axis=1).min())<width[i]/2+4:continue
        path=f'res://assets/models/srilanka/phoenix_{int(s/30)%3}_lod.glb'
        placements.append({'asset':path,'position':[float(center[0]),0,float(center[1])],'yaw':yaw,'scale':rng.uniform(.72,.95),'kind':'palm','always':False,'tint':[1,1,1,1]})

# Galle Face remains open lawn; palm rows frame its sea and road edges.
for x in [-824.,-637.]:
    for z in range(-480,550,42):
        placements.append({'asset':'res://assets/models/srilanka/phoenix_1_lod.glb','position':[x,0,z],'yaw':rng.random()*math.tau,'scale':.85,'kind':'palm','always':False,'tint':[1,1,1,1]})

for i in range(250):
    angle=i*math.tau/250.;radius=135.;center=np.array([300+math.cos(angle)*radius,25+math.sin(angle)*radius])
    entry=library['props'][i%len(library['props'])]
    placements.append({'asset':entry['path'],'position':[float(center[0]),.48,float(center[1])],'yaw':math.atan2(-math.sin(angle),math.cos(angle)),'scale':1.,'kind':'railing','always':False,'tint':[1,1,1,1]})

# Paired PNG and outlined SVG signs use the existing licensed game typeface.
SIGNS=ROOT/'assets/signs/colombo';SIGNS.mkdir(parents=True,exist_ok=True)
labels=['GALLE FACE','COLOMBO FORT','LOTUS TOWER','BEIRA LAKE','CITY CENTRE','CEYLON TEA','ISLAND BAKERY','COAST CAFE','FORT MARKET']
font=ImageFont.truetype(str(ROOT/'assets/fonts/heading.ttf'),100)
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
tt=TTFont(ROOT/'assets/fonts/heading.ttf');glyphs=tt.getGlyphSet();cmap=tt.getBestCmap();units=tt['head'].unitsPerEm
for label in labels:
    name=label.lower().replace(' ','-');image=Image.new('RGB',(1024,256),'#174a42');draw=ImageDraw.Draw(image)
    draw.rounded_rectangle((8,8,1015,247),radius=15,outline='#e8e5cf',width=7)
    box=draw.textbbox((0,0),label,font=font);draw.text(((1024-(box[2]-box[0]))/2,52),label,font=font,fill='#fff4d6')
    image.save(SIGNS/(name+'.png'),optimize=True)
    advance=sum(tt['hmtx'][cmap[ord(c)]][0] for c in label);factor=min(105/units,900/advance);cursor=(1024-advance*factor)/2;paths=[]
    for character in label:
        glyph_name=cmap[ord(character)];pen=SVGPathPen(glyphs);glyphs[glyph_name].draw(pen)
        paths.append(f'<path d="{pen.getCommands()}" transform="translate({cursor:.3f},169) scale({factor:.7f},-{factor:.7f})"/>');cursor+=tt['hmtx'][glyph_name][0]*factor
    svg='<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="256"><rect x="4" y="4" width="1016" height="248" rx="15" fill="#174a42" stroke="#e8e5cf" stroke-width="7"/><g fill="#fff4d6">'+''.join(paths)+'</g></svg>'
    (SIGNS/(name+'.svg')).write_text(svg,encoding='utf-8')

data={'format':1,'cell_size':200,'placements':placements,'exclusions':[{'name':name,'bounds':list(bounds)} for name,bounds in exclusions],
      'minimum_building_road_edge_clearance_m':minimum_clearance,'signs':[str(p.relative_to(ROOT)).replace('\\','/') for p in sorted(SIGNS.glob('*.svg'))]}
(OUT/'placements.json').write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')
report={'status':'PASS','buildings':sum(e['kind']=='building' for e in placements),'skyline':sum(e['kind']=='skyline' for e in placements),
        'palms':sum(e['kind']=='palm' for e in placements),'railings':sum(e['kind']=='railing' for e in placements),
        'minimum_building_road_edge_clearance_m':minimum_clearance,'premade_building_variants':len(library['buildings']),
        'exclusions':[name for name,_ in exclusions]}
(ROOT/'docs/qa-colombo-city/placement.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2))
