"""Reproducible lamp-only GLB derivative; source checkpoint is never written."""
from pathlib import Path
import argparse, copy, hashlib, json, struct, shutil
ROOT=Path(__file__).resolve().parents[1]

def author(source, destination):
    source=Path(source);destination=Path(destination)
    blob=(source/'model.glb').read_bytes();length,kind=struct.unpack_from('<II',blob,12)
    doc=json.loads(blob[20:20+length]);offset=20+length
    size,kind=struct.unpack_from('<II',blob,offset);binary=bytearray(blob[offset+8:offset+8+size])
    parents={child:i for i,n in enumerate(doc['nodes']) for child in n.get('children',[])}
    def path(i):return (path(parents[i])+'/' if i in parents else '')+doc['nodes'][i].get('name',str(i)).replace('.', '_')
    paths={n.get('name'):path(i) for i,n in enumerate(doc['nodes'])}
    def values(index):
        a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']]
        fmt={5121:'B',5123:'H',5125:'I',5126:'f'}[a['componentType']]
        width={'SCALAR':1,'VEC3':3}[a['type']];stride=v.get('byteStride',struct.calcsize(fmt)*width)
        start=v.get('byteOffset',0)+a.get('byteOffset',0)
        return [struct.unpack_from('<'+fmt*width,binary,start+i*stride) for i in range(a['count'])]
    def indices(items):
        binary.extend(b'\0'*(-len(binary)%4));start=len(binary)
        binary.extend(struct.pack('<'+'I'*len(items),*items))
        view=len(doc['bufferViews']);doc['bufferViews'].append({'buffer':0,'byteOffset':start,'byteLength':len(items)*4,'target':34963})
        index=len(doc['accessors']);doc['accessors'].append({'bufferView':view,'componentType':5125,'count':len(items),'type':'SCALAR','min':[min(items)],'max':[max(items)]})
        return index
    def material(name,color):
        index=len(doc['materials'])
        doc['materials'].append({'name':name,'doubleSided':True,'pbrMetallicRoughness':{'baseColorFactor':[*color,1],'metallicFactor':0,'roughnessFactor':.24},'emissiveFactor':[0,0,0]})
        return index
    reverse_material=material('Lamp_Reverse_Bumper_White_232',[.65,.68,.7])
    led_material=material('Lamp_Tail_Y_LED_232',[.45,.004,.008])
    def positions(items):
        binary.extend(b'\0'*(-len(binary)%4));start=len(binary)
        binary.extend(struct.pack('<'+'f'*len(items)*3,*(v for item in items for v in item)))
        view=len(doc['bufferViews']);doc['bufferViews'].append({'buffer':0,'byteOffset':start,'byteLength':len(items)*12,'target':34962})
        index=len(doc['accessors']);doc['accessors'].append({'bufferView':view,'componentType':5126,'count':len(items),'type':'VEC3','min':[min(v[a] for v in items) for a in range(3)],'max':[max(v[a] for v in items) for a in range(3)]})
        return index
    corrections=[]
    for m in doc['materials']:
        if m['name'].startswith('Lamp_TailBrake_dust25_re'):
            m['pbrMetallicRoughness']['baseColorFactor']=[.11,.002,.004,1]
            m['emissiveFactor']=[0,0,0]
            m.get('extensions',{}).pop('KHR_materials_emissive_strength',None)
        if m['name'].startswith('Lamp_Indicator_dust25_pov'):
            m['pbrMetallicRoughness']['baseColorFactor']=[.035,.028,.018,1]
    template_vertices=None
    for name in ['dust25_taillight_L','dust25_taillight_R']:
        node=next(n for n in doc['nodes'] if n.get('name')==name);mesh=doc['meshes'][node['mesh']]
        for primitive in list(mesh['primitives']):
            if doc['materials'][primitive.get('material',0)]['name']!='Lamp_TailBrake_dust25_re.001_Runtime':continue
            vertices=values(primitive['attributes']['POSITION']);old=[v[0] for v in values(primitive['indices'])]
            # Inset optical rails follow the actual lens surface. The broad red lens
            # and the central indicator remain passive; neither is a reverse lamp.
            strips=[];triangles=[]
            upper={0,1,12,13,14,15,20,21,22,23};lower={2,3,4,5,6,7,8,9,10,11,24,25}
            inner={0,1,14,20,23,2,5,6,8,9,25}
            if template_vertices is None:template_vertices=vertices
            else:
                # Mirrored source meshes have different vertex ordering.
                mapping={}
                for i,p in enumerate(template_vertices):
                    reflected=[-p[0],p[1],p[2]]
                    j=min(range(len(vertices)),key=lambda j:sum((vertices[j][a]-reflected[a])**2 for a in range(3)))
                    assert sum((vertices[j][a]-reflected[a])**2 for a in range(3))<1e-10
                    mapping[i]=j
                upper={mapping[i] for i in upper};lower={mapping[i] for i in lower};inner={mapping[i] for i in inner}
            # Clip within each original triangle, retaining every surface fold.
            # A quad spanning a non-planar lens can sink underneath it and flicker.
            def clip(poly,limit,above):
                result=[]
                for a,b in zip(poly,poly[1:]+poly[:1]):
                    ia=a[3]>=limit if above else a[3]<=limit;ib=b[3]>=limit if above else b[3]<=limit
                    if ia:result.append(a)
                    if ia!=ib:
                        t=(limit-a[3])/(b[3]-a[3]);result.append([a[j]+(b[j]-a[j])*t for j in range(4)])
                return result
            for i in range(0,len(old),3):
                tri=old[i:i+3]
                if not (set(tri)<=upper or set(tri)<=lower):continue
                poly=[[*vertices[j],float(j in inner)] for j in tri]
                poly=clip(clip(poly,.28,True),.72,False)
                start=len(strips)
                strips.extend([[p[0],p[1],p[2]-.002] for p in poly])
                for k in range(1,len(poly)-1):triangles.extend([start,start+k,start+k+1])
            mesh['primitives'].append({'attributes':{'POSITION':positions(strips)},'indices':indices(triangles),'material':led_material})
            corrections.append({'node':paths[name],'role':'red_y_signature','led_triangles':len(triangles)//3,'upper_reverse_targets':0})
    # This model called both lower optical units reflectors. The right-hand rear
    # bumper unit (negative source X, before the model's 180-degree rotation) is
    # the white reversing lamp. The opposite unit retains its red lens.
    bumper_name='dust25_bumper_a_R__Reflector_Lens_L'
    bumper=next(n for n in doc['nodes'] if n.get('name')==bumper_name)
    mesh=doc['meshes'][bumper['mesh']]
    for primitive in list(mesh['primitives']):
        vertices=values(primitive['attributes']['POSITION']);white=[v[0] for v in values(primitive['indices'])]
        primitive['material']=reverse_material
        corrections.append({'node':paths[bumper_name],'role':'bumper_reverse','reverse_triangles':len(white)//3,'raw_max_height':max(vertices[i][1] for i in white)})
    # The separate chrome optical cells below the Y signature are the main
    # headlamp reflectors, not the DRL strip or the surrounding black housing.
    for suffix in ['L','R']:
        node=next(n for n in doc['nodes'] if n.get('name')=='dust25_headlight_'+suffix+'.001')
        for primitive in doc['meshes'][node['mesh']]['primitives']:
            if doc['materials'][primitive['material']]['name']=='dust25_chrf.001_Runtime':
                optic=copy.deepcopy(doc['materials'][primitive['material']]);optic['name']='Lamp_Head_Main_'+suffix+'_232';optic['pbrMetallicRoughness']['metallicFactor']=0
                primitive['material']=len(doc['materials']);doc['materials'].append(optic)
    doc['buffers'][0]['byteLength']=len(binary)
    encoded=json.dumps(doc,separators=(',',':')).encode();encoded+=b' '*(-len(encoded)%4);binary.extend(b'\0'*(-len(binary)%4))
    result=struct.pack('<III',0x46546C67,2,28+len(encoded)+len(binary))+struct.pack('<II',len(encoded),0x4E4F534A)+encoded+struct.pack('<II',len(binary),0x004E4942)+binary
    destination.mkdir(parents=True,exist_ok=True);(destination/'model.glb').write_bytes(result)
    data=json.loads((source/'vehicle.json').read_text(encoding='utf-8-sig'))
    data['version']='1.2.1';data['core']['min']='2.3.2';data['lighting']=[]
    def lamp(role,name,material,anchor=None,**extra):
        group={'role':role,'targets':[{'node':paths[name],'material':material}],**extra}
        if anchor is not None:group['anchor']=anchor
        data['lighting'].append(group)
    for side,suffix in [(-1,'R'),(1,'L')]:
        lamp('head','dust25_headlight_'+suffix+'.001','Lamp_Head_dust25_led'+suffix+'.001_Runtime')
        lamp('head','dust25_headlight_'+suffix+'.001','Lamp_Head_Main_'+suffix+'_232',[-side*.62,.85,-2.10],range=26,energy=2.2)
        lamp('brake','dust25_taillight_'+suffix,'Lamp_Tail_Y_LED_232')
    lamp('reverse',bumper_name,'Lamp_Reverse_Bumper_White_232',[.75,.45,2.39],range=3.5,energy=.5)
    lamp('brake','dust25_tailgate_chmsl','Lamp_TailBrake_dust25_brake.001_Runtime',running=False)
    data['actions']=[{'slot':1,'name':'Sunroof','type':'transform','duration':1.6,'targets':[{'node':paths['Bigster_Sunroof_Opening_Glass'],'open_position':[0,.065,-.68]}]}]
    (destination/'vehicle.json').write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')
    for name in ['thumbnail.png','LICENSE.txt']:
        if (source/name).exists() and (source/name).resolve()!=(destination/name).resolve():shutil.copy2(source/name,destination/name)
    report={'source_sha256':hashlib.sha256(blob).hexdigest(),'output_sha256':hashlib.sha256(result).hexdigest(),'source_unchanged':hashlib.sha256((source/'model.glb').read_bytes()).hexdigest()==hashlib.sha256(blob).hexdigest(),'corrections':corrections,'sunroof_slide_local':[0,.065,-.68]}
    (destination/'feature-authoring.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report))
    return data

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--source',type=Path,required=True);parser.add_argument('--output',type=Path,required=True);args=parser.parse_args();author(args.source,args.output)
