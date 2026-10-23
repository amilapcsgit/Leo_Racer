"""Independent numeric audit of the baked Road Generator race ribbon."""
from pathlib import Path
import hashlib,json,numpy as np
ROOT=Path(__file__).resolve().parents[1]
route=json.loads((ROOT/'assets/tracks/colombo_city/route.json').read_text(encoding='utf-8'))
p=np.array(route['points'])[:,[0,2]];n=len(p);step=route['length']/n
a=np.roll(p,1,axis=0);c=np.roll(p,-1,axis=0)
cross=lambda x,y:x[...,0]*y[...,1]-x[...,1]*y[...,0]
area=np.abs(cross(p-a,c-a))
radii=np.linalg.norm(p-a,axis=1)*np.linalg.norm(c-p,axis=1)*np.linalg.norm(c-a,axis=1)/np.maximum(2*area,1e-12)
gaps=np.linalg.norm(c-p,axis=1);minimum=1e9;crossings=[];skip=int(np.ceil(120/step))
for i in range(n):
    indices=np.arange(i+1,n);indices=indices[np.minimum(indices-i,n-(indices-i))>=skip]
    if not len(indices):continue
    delta=p[indices]-p[i];minimum=min(minimum,float(np.linalg.norm(delta,axis=1).min()))
    ends=c[indices];ab=c[i]-p[i];cd=ends-p[indices]
    hit=(cross(ab,p[indices]-p[i])*cross(ab,ends-p[i])<0)&(cross(cd,p[i]-p[indices])*cross(cd,c[i]-p[indices])<0)
    crossings.extend([[i,int(j)] for j in indices[hit]])
checks={'length_5_to_6_km':5000<=route['length']<=6000,'flat':all(abs(x[1])<1e-4 for x in route['points']),
        'spacing_under_2_01m':float(gaps.max())<2.01,'continuous_sampling':float(gaps.min())>1.95,
        'minimum_radius_22m':float(radii.min())>=22,'no_crossings':not crossings,
        'distinct_arms_clear_50m':minimum>=50,'widths_match_samples':len(route['widths'])==n,
        'width_18_to_24m':min(route['widths'])>=17.99 and max(route['widths'])<=24.01}
report={'status':'PASS' if all(checks.values()) else 'FAIL','checks':checks,'length_m':route['length'],'samples':n,
        'minimum_radius_m':float(radii.min()),'nonlocal_center_clearance_m':minimum,'crossings':crossings,
        'sample_gap_m':[float(gaps.min()),float(gaps.max())],
        'route_sha256':hashlib.sha256((ROOT/'assets/tracks/colombo_city/route.json').read_bytes()).hexdigest()}
(ROOT/'docs/qa-colombo-city/course.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2))
assert report['status']=='PASS'
