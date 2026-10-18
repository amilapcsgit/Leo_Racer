"""Build the deterministic Astra coast/harbor/garden circuit; audit geometric safety."""
from __future__ import annotations
import bisect, json, math
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
# Clockwise, start / finish stays on the original western grid.
CONTROL = [(-90,78),(-90,10),(-90,-110),(-90,-220),(-75,-280),(-20,-310),(80,-310),(110,-270),(160,-235),(215,-265),(255,-310),(300,-300),(315,-245),(295,-180),(235,-130),(200,-70),(220,-15),(290,20),(315,80),(290,140),(220,165),(160,150),(125,195),(65,235),(-10,235),(-70,205),(-90,150),(-90,115)]

def spline(a,b,c,d,t):
    return tuple(.5*((2*b[k])+(-a[k]+c[k])*t+(2*a[k]-5*b[k]+4*c[k]-d[k])*t*t+(-a[k]+3*b[k]-3*c[k]+d[k])*t*t*t) for k in (0,1))
def distance(a,b):return math.hypot(a[0]-b[0],a[1]-b[1])
def cross(a,b,c):return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
def intersects(a,b,c,d):return cross(a,b,c)*cross(a,b,d)<0 and cross(c,d,a)*cross(c,d,b)<0

def build():
    dense=[]
    for i,b in enumerate(CONTROL):
        for j in range(120):dense.append(spline(CONTROL[(i-1)%len(CONTROL)],b,CONTROL[(i+1)%len(CONTROL)],CONTROL[(i+2)%len(CONTROL)],j/120))
    dense.append(dense[0]); cumulative=[0.0]
    for a,b in zip(dense,dense[1:]):cumulative.append(cumulative[-1]+distance(a,b))
    length=cumulative[-1]; n=round(length/2); step=length/n; points=[]
    for i in range(n):
        s=i*step;j=bisect.bisect_right(cumulative,s)-1;t=(s-cumulative[j])/(cumulative[j+1]-cumulative[j])
        points.append(tuple(dense[j][k]+t*(dense[j+1][k]-dense[j][k]) for k in (0,1)))
    radii=[]
    for i,b in enumerate(points):
        a,c=points[(i-1)%n],points[(i+1)%n];area=abs(cross(a,b,c));radii.append(distance(a,b)*distance(b,c)*distance(a,c)/(2*area) if area>1e-8 else 1e9)
    minimum=(1e9,None);crossings=[]
    # Exclude local neighbors within 80m travelled: road-width clearance is
    # meaningful only between distinct circuit arms, not along the same bend.
    skip=math.ceil(80/step)
    for i,a in enumerate(points):
        b=points[(i+1)%n]
        for j in range(i+skip,n):
            if min(j-i,n-(j-i))<skip:continue
            d=distance(a,points[j])
            if d<minimum[0]:minimum=(d,[i,j])
            if intersects(a,b,points[j],points[(j+1)%n]):crossings.append([i,j])
    sectors=[{'fraction':0.0,'name':'GALLe FACE // COAST RUN'.upper()},{'fraction':.23,'name':'PORT CITY // NORTH ESSES'},{'fraction':.40,'name':'HARBOR HAIRPIN'},{'fraction':.55,'name':'LOTUS LAGOON CAUSEWAY'},{'fraction':.72,'name':'INDEPENDENCE GARDENS'},{'fraction':.88,'name':'FORT QUARTER // HOME STRAIGHT'}]
    data={'name':'Astra Lotus Coast Grand Prix','version':1,'length':round(length,6),'width':18.0,'points':[[round(x,5),0,round(z,5)] for x,z in points],'boosts':[.075,.185,.315,.48,.59,.705,.835,.955],'sectors':sectors,'features':{'coast_straight':{'start':0.0,'end':.17},'harbor_hairpin':{'start':.36,'end':.44},'lagoon_causeway':{'start':.49,'end':.60},'garden_esses':{'start':.69,'end':.86},'lagoon_center':[215,0,-80],'lagoon_radius':[85,125]}}
    audit={'status':'PASS','length_m':round(length,3),'previous_length_m':758,'length_multiple':round(length/758,3),'samples':n,'step_m':round(step,6),'minimum_radius_m':round(min(radii),3),'minimum_nonlocal_center_clearance_m':round(minimum[0],3),'closest_nonlocal_indices':minimum[1],'local_exclusion_distance_m':80,'centerline_self_crossings':crossings,'minimum_road_edge_clearance_m':round(minimum[0]-18,3),'conservative_segment_clearance_m':round(minimum[0]-2*step,3),'start':[points[0][0],0,points[0][1]],'start_heading':[round((points[1][k]-points[-1][k])/distance(points[1],points[-1]),6) for k in (0,1)],'boost_pads':len(data['boosts']),'features':data['features'],'assertions':{'lap_1600_to_2000m':1600<=length<=2000,'radius_at_least_15m':min(radii)>=15,'nonlocal_clearance_at_least_45m':minimum[0]>=45,'no_self_crossings':not crossings,'sample_spacing_under_2_1m':step<2.1}}
    if not all(audit['assertions'].values()):audit['status']='FAIL'
    (ROOT/'assets/track-astra.json').write_text(json.dumps(data,separators=(',',':'))+'\n',encoding='utf8')
    folder=ROOT/'docs/qa-astra';folder.mkdir(parents=True,exist_ok=True)
    (folder/'track-audit.json').write_text(json.dumps(audit,indent=2)+'\n',encoding='utf8')
    print(json.dumps(audit,indent=2))
    if audit['status']!='PASS':raise SystemExit(1)
if __name__=='__main__':build()
