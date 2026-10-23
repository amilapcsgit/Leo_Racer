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
occupied={};placements=[];parcels=[];minimum_clearance=1e9

def overlap(center,axes,half,c,a,h,gap=.35):
    delta=c-center
    for axis in [*axes,*a]:
        if abs(delta@axis)>sum(abs(axis@v)*r for v,r in zip(axes,half))+sum(abs(axis@v)*r for v,r in zip(a,h))+gap:return False
    return True

def fit(center,yaw,w,d):
    global minimum_clearance
    axes=np.array([[math.cos(yaw),-math.sin(yaw)],[math.sin(yaw),math.cos(yaw)]])
    half=np.array([w,d])/2+.15
    clearance=float((np.linalg.norm(np.maximum(abs((p-center)@axes.T)-half,0),axis=1)-width/2).min())
    if clearance<5.5 or center[0]-max(w,d)/2<-843:return False
    for _,(x0,z0,x1,z1) in exclusions:
        if overlap(center,axes,half,np.array([(x0+x1)/2,(z0+z1)/2]),np.eye(2),np.array([x1-x0,z1-z0])/2):return False
    key=tuple(np.floor(center/80).astype(int))
    for x in range(key[0]-2,key[0]+3):
        for z in range(key[1]-2,key[1]+3):
            for c,a,h in occupied.get((x,z),[]):
                if overlap(center,axes,half,c,a,h):return False
    occupied.setdefault(key,[]).append((center,axes,half));minimum_clearance=min(minimum_clearance,clearance)
    return True

palette=[[.94,.94,.91,1],[.82,.88,.83,1],[.92,.85,.75,1],[.83,.84,.81,1],[.97,.92,.81,1]]
recipes=[b for b in library['buildings'] if 'components' in b]
towers=[b for b in library['buildings'] if 'tower' in b['id'] and b['height']<100.]

def place(entry,center,yaw,scale=1.,kind='building',always=False,district='skyline',row=0):
    tint=rng.choice(palette) if kind=='building' else [1,1,1,1]
    if 'components' not in entry:
        placements.append({'asset':entry['path'],'position':[float(center[0]),0,float(center[1])],'yaw':yaw,'scale':scale,'kind':kind,'always':always,'tint':tint});return
    parcel_id=len(parcels)
    parcels.append({'id':parcel_id,'recipe':entry['id'],'center':center.tolist(),'yaw':yaw,'width':entry['width'],'height':entry['height'],'depth':entry['depth'],'district':district,'row':row,'tint':tint})
    c=math.cos(yaw);ss=math.sin(yaw)
    for i,part in enumerate(entry['components']):
        x,y,z=part['position'];px=center[0]+c*x+ss*z;pz=center[1]-ss*x+c*z
        placements.append({'asset':part['asset'],'position':[float(px),y,float(pz)],'yaw':yaw+part['yaw'],'scale':1.,'scale_xyz':part['scale_xyz'],
          'kind':'building' if i==0 else 'module','role':part['role'],'parcel':parcel_id,'always':False,'tint':tint})
    if entry.get('ground_module')!=46:
        for bay in range(round(entry['width']/6.912)):
            x=(bay-(entry['width']/6.912-1)/2)*6.912;z=3.79
            key=['ceylon-tea','island-bakery','coast-cafe','fort-market'][(parcel_id+bay)%4]
            placements.append({'asset':'res://assets/signs/colombo/'+key+'.svg',
                'position':[float(center[0]+c*x+ss*z),2.75,float(center[1]-ss*x+c*z)],
                'yaw':yaw,'scale':1.,'kind':'shop_sign','parcel':parcel_id,'always':False,'tint':[1,1,1,1]})

def district_at(point):
    if point[0]<-560:return 'waterfront'
    if point[1]<-400:return 'fort'
    if point[0]>250:return 'commercial'
    return 'lotus_beira'

for row in range(2):
 for side in [-1.,1.]:
    s=16.;index=0
    while s<route['length']-20:
        i=int(s/step)%n;district=district_at(p[i])
        options=[r for r in recipes if (r['floors']>=2 if district in ('fort','commercial') else True)]
        entry=rng.choice(options);w=entry['width'];d=entry['depth']
        i=int((s+w/2)/step)%n
        front=-normal[i]*side;yaw=math.atan2(front[0],front[1])
        center=p[i]+normal[i]*side*(width[i]/2+7.8+d/2+row*19.)
        if not (p[i,0]<-560 and center[0]<p[i,0]) and fit(center,yaw,w,d):place(entry,center,yaw,district=district,row=row)
        # Narrow joins form terraces; wider breaks every six frontages become alleys.
        s+=w+(.95 if index%6 else 7.);index+=1

# Cluster the skyline behind streets, with broad gaps for protected landmark views.
for x in range(-380,1050,110):
 for z in range(-1120,1100,110):
    center=np.array([x+rng.uniform(-22,22),z+rng.uniform(-22,22)])
    if float(np.linalg.norm(p-center,axis=1).min())<95:continue
    if -100<center[0]<100 and -220<center[1]<180:continue
    entry=rng.choice(towers);yaw=rng.choice([0.,math.pi/2,math.pi,math.pi*1.5]);scale=rng.uniform(.78,1.32)
    if fit(center,yaw,entry['width']*scale,entry['depth']*scale):place(entry,center,yaw,scale,'skyline',True)

modules={m['source_node_index']:m for m in json.loads((ROOT/'assets/models/colombo_city/modules.json').read_text())['modules']}
for index,s in enumerate(np.arange(14,route['length'],36)):
    i=int(s/step)%n;yaw=math.atan2(t[i,0],t[i,1])
    for side in [-1.,1.]:
        center=p[i]+normal[i]*side*(width[i]/2+3.7)
        if center[0]<-848:continue
        # Existing palms remain, with fewer identical pairs and space for shop doors.
        if index%3==0:
            placements.append({'asset':f'res://assets/models/srilanka/phoenix_{(index//3)%3}_lod.glb','position':[float(center[0]),0,float(center[1])],'yaw':rng.random()*math.tau,'scale':rng.uniform(.68,.88),'kind':'palm','always':False,'tint':[1,1,1,1]})
        else:
            m=modules[44 if index%3==1 else rng.choice([58,60,62])]
            placements.append({'asset':m['path'],'position':[float(center[0]),.04,float(center[1])],'yaw':yaw+(math.pi if side<0 else 0),'scale':.75,'kind':'street_prop','always':False,'tint':[1,1,1,1]})
for x in [-824.,-637.]:
 for z in range(-480,550,55):
    placements.append({'asset':'res://assets/models/srilanka/phoenix_1_lod.glb','position':[x,0,z],'yaw':rng.random()*math.tau,'scale':rng.uniform(.76,.94),'kind':'palm','always':False,'tint':[1,1,1,1]})
for i in range(180):
    angle=i*math.tau/180.;center=np.array([300+math.cos(angle)*135.,25+math.sin(angle)*135.])
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
      'parcels':parcels,'module_recipes':'res://assets/models/colombo_city/recipes.json','minimum_building_road_edge_clearance_m':minimum_clearance,'signs':[str(p.relative_to(ROOT)).replace('\\','/') for p in sorted(SIGNS.glob('*.svg'))]}
(OUT/'placements.json').write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')
report={'status':'PASS','buildings':sum(e['kind']=='building' for e in placements),'skyline':sum(e['kind']=='skyline' for e in placements),
        'palms':sum(e['kind']=='palm' for e in placements),'railings':sum(e['kind']=='railing' for e in placements),
        'minimum_building_road_edge_clearance_m':minimum_clearance,'premade_building_variants':len(library['buildings']),'assembled_recipes':len(recipes),'secondary_row_buildings':sum(x['row']==1 for x in parcels),'districts':sorted({x['district'] for x in parcels}),
        'exclusions':[name for name,_ in exclusions]}
(ROOT/'docs/qa-colombo-city/placement.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2))
