"""Offline adaptation of a verified Earth2Road world to editable race-authoring data.

No downloads. Run with the SDK's bundled authoring Python dependencies.
The archived world remains read-only; course decisions are a separate file.
"""
from pathlib import Path
import argparse,hashlib,json,math,xml.etree.ElementTree as ET
import numpy as np
from pyproj import Proj
from shapely.geometry import LineString,Polygon
from shapely.ops import polygonize,unary_union
import shapely
from PIL import Image

def read(p):return json.loads(Path(p).read_text(encoding='utf-8'))
def write(p,d):
 p=Path(p);p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def sha(p):return hashlib.file_digest(Path(p).open('rb'),'sha256').hexdigest()
def import_world(world,output):
 from akadem_maps.world import validate_world
 validate_world(world)
 index=read(world/'index.json');network=ET.parse(world/'network.net.xml').getroot().find('location')
 project=Proj(network.get('projParameter'));offset=[float(v) for v in network.get('netOffset').split(',')];cx,cy=index['offset']
 def coordinate(lon,lat):
  x,y=project(lon,lat);return [x+offset[0]-cx,-(y+offset[1]-cy)]
 raw=next((world/'inputs/raw').rglob('*.osm'));osm=ET.parse(raw).getroot()
 nodes={n.get('id'):coordinate(float(n.get('lon')),float(n.get('lat'))) for n in osm.findall('node')}
 ways={w.get('id'):w for w in osm.findall('way')}
 lake=None
 for relation in osm.findall('relation'):
  tags={t.get('k'):t.get('v') for t in relation.findall('tag')}
  if tags.get('name')=='Kandy Lake' or tags.get('name:en')=='Kandy Lake':lake=relation;break
 if lake is None:raise ValueError('Select a world containing the Kandy Lake water polygon')
 lines=[]
 for m in lake.findall('member'):
  if m.get('type')=='way' and m.get('role')=='outer':lines.append(LineString([nodes[n.get('ref')] for n in ways[m.get('ref')].findall('nd')]))
 polygon=max(polygonize(unary_union(lines)),key=lambda p:p.area)
 center=np.asarray(polygon.centroid.coords[0]);ring=np.asarray(polygon.exterior.coords)-center
 buildings=[]
 for file in sorted((world/'tiles').glob('*.json')):
  for b in read(file).get('buildings',[]):
   a=np.asarray([[p[0],p[2]] for p in b['points']])-center
   if np.linalg.norm(a.mean(axis=0))<1400:buildings.append({'id':b['id'],'footprint':a.tolist(),'height':b['height'],'height_source':b.get('height_source'),'visual_source':b.get('visual_source')})
 data={'format':1,'lake':ring.tolist(),'buildings':buildings,'origin_world':center.tolist(),'source_world_sha256':sha(world/'world.json'),'osm_sha256':sha(raw),'attribution':index['attribution'],'earth2road_commit':'fec38c79441585e5ff719dd37fa516db809eef9b','lake_osm_relation':lake.get('id')}
 write(output/'geography.json',data);return data

def course(geography,output):
 lake=Polygon(geography['lake']);path=lake.buffer(38.,join_style=1).exterior
 count=1024
 a=np.array([path.interpolate(path.length*i/count).coords[0] for i in range(count)])
 # Retain recognizable lake geography while removing map-digitizing wiggles.
 smooth=np.fft.rfft(a,axis=0);smooth[17:]=0;a=np.fft.irfft(smooth,n=count,axis=0)
 area=np.sum(a[:,0]*np.roll(a[:,1],-1)-np.roll(a[:,0],-1)*a[:,1])
 if area<0:a=a[::-1]
 start=int(np.argmin(a[:,0]));a=np.roll(a,-start,axis=0)
 line=LineString(np.vstack([a,a[0]]));a=np.array([line.interpolate(line.length*i/count).coords[0] for i in range(count)])
 phase=np.arange(count)*2*math.pi/count;y=2*np.sin(phase)+.8*np.sin(2*phase);y-=y.min()-.2
 pts=np.column_stack([a[:,0],y,a[:,1]]);dist=np.linalg.norm(np.roll(pts,-1,axis=0)-pts,axis=1);cumulative=np.r_[0,np.cumsum(dist)];length=cumulative[-1]
 if not 2800<=length<=3500:raise ValueError(f'Adapted lake route is outside approved range: {length:.1f}m')
 target=np.arange(count)*length/count;closed=np.vstack([pts,pts[0]])
 pts=np.column_stack([np.interp(target,cumulative,closed[:,i]) for i in range(3)])
 length=float(np.linalg.norm(np.roll(pts,-1,axis=0)-pts,axis=1).sum())
 delta=np.roll(pts,-1,axis=0)-pts;horizontal=np.linalg.norm(delta[:,[0,2]],axis=1);grade=delta[:,1]/horizontal;curvature=np.abs(grade-np.roll(grade,1))/((horizontal+np.roll(horizontal,1))/2)
 if max(abs(grade))>.06 or max(curvature)>.001:raise ValueError('Elevation safety limits exceeded')
 route={'length':length,'width':18.,'points':pts.tolist(),'surface_profile':'arcade_elevation_v1','features':{'grid':{'start':-8.,'lanes':[-3.2,3.2]},'recoveries':[{'distance':length*i/8+2} for i in range(8)]},'sectors':[{'fraction':0,'name':'KANDY TOWN'},{'fraction':.25,'name':'LAKE PROMENADE'},{'fraction':.5,'name':'HILL COUNTRY'},{'fraction':.75,'name':'DALADA VISTA'}]}
 write(output/'course.json',route)
 write(output/'job.json',{'format':1,'id':'kandy_lake','seed':311,'course_revision':1,'source_geography_sha256':sha(output/'geography.json'),'course_sha256':sha(output/'course.json'),'origin_world':geography['origin_world'],'max_grade':float(max(abs(grade))),'minimum_vertical_radius':float(1/max(curvature)),'length_m':length,'race_adapted':True,'reference':'Kandy Lake geography, not a reconstruction of the 2014 race'})
 print(json.dumps(read(output/'job.json'),indent=2))
def terrain(world,geography,output):
 index=read(world/'index.json');location=ET.parse(world/'network.net.xml').getroot().find('location');projection=Proj(location.get('projParameter'))
 net=np.array([float(v) for v in location.get('netOffset').split(',')]);center=np.array(geography['origin_world']);origin=np.array(index['offset'])
 size=512;spacing=6.;axis=np.arange(size)*spacing-1536.;x,z=np.meshgrid(axis,axis)
 lon,lat=projection(x+center[0]+origin[0]-net[0],-(z+center[1])+origin[1]-net[1],inverse=True)
 zoom=12;n=2**zoom;u=(lon+180)/360*n;v=(1-np.arcsinh(np.tan(np.radians(lat)))/np.pi)/2*n
 tx=np.floor(u).astype(int);ty=np.floor(v).astype(int);height=np.zeros_like(x)
 tiles={}
 for a,b in set(zip(tx.ravel(),ty.ravel())):
  p=next((world/'inputs/raw').rglob(f'terrain/{zoom}/{a}/{b}.png'),None)
  if p is None:raise ValueError(f'Missing archived terrain tile {a}/{b}')
  image=np.asarray(Image.open(p).convert('RGB'),dtype=float);tile=image[:,:,0]*256+image[:,:,1]+image[:,:,2]/256-32768
  mask=(tx==a)&(ty==b);px=np.clip(((u[mask]-a)*256).astype(int),0,255);py=np.clip(((v[mask]-b)*256).astype(int),0,255);height[mask]=tile[py,px]
  tiles[str(p.name)]=sha(p)
 lake=Polygon(geography['lake']);points=shapely.points(x.ravel(),z.ravel());inside=shapely.contains(lake,points).reshape(x.shape)
 height-=float(np.median(height[inside]));height=np.maximum(height,-2.)
 route=read(output/'course.json');p=np.asarray(route['points']);line=LineString(p[:,[0,2]])
 distances=shapely.distance(line,points).reshape(x.shape);at=shapely.line_locate_point(line,points)
 spans=np.r_[0,np.cumsum(np.linalg.norm(np.diff(p[:,[0,2]],axis=0),axis=1))]
 road_y=np.interp(at,spans,p[:,1]).reshape(x.shape)
 blend=np.clip((distances-15)/55,0,1);blend=blend*blend*(3-2*blend)
 height=height*blend+(road_y-.3)*(1-blend);height[inside]=-2.4
 (output/'terrain.r32').write_bytes(height.astype('<f4').tobytes())
 write(output/'terrain.json',{'format':1,'size':size,'spacing':spacing,'origin':[-1536,-1536],'source':'Archived Mapzen Terrarium DEM, flattened outside the race corridor','terrain_sha256':sha(output/'terrain.r32'),'minimum':float(height.min()),'maximum':float(height.max())})
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--world',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 data=import_world(a.world,a.output)
 # Existing authored course edits are authoritative across geography refreshes.
 if not (a.output/'course.json').exists():course(data,a.output)
 terrain(a.world,data,a.output)
if __name__=='__main__':main()
