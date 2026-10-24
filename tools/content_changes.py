"""Dependency-aware check/build selection for the modularity branch."""
import argparse, json, subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def select(paths):
    result={'core':False,'full_roster':False,'vehicles':[],'tracks':[],'docs_only':True}
    sources=json.loads((ROOT/'content/vehicle-sources.json').read_text())
    for path in paths:
        if path.startswith(('docs/','README','sdk/README')):continue
        result['docs_only']=False
        vehicle=next((key for key,v in sources.items() if path==v['model'].removeprefix('res://') or path.startswith('content/vehicles/'+key+'/')),None)
        if vehicle:
            if vehicle not in result['vehicles']:result['vehicles'].append(vehicle)
        elif path.startswith('assets/tracks/'):
            key=path.split('/')[2]
            if key not in result['tracks']:result['tracks'].append(key)
        elif path.startswith(('sdk/track-kit/','tools/build_track_content')):
            if 'community_example' not in result['tracks']:result['tracks'].append('community_example')
        else:
            result['core']=True
            if path.startswith(('scripts/catalog/','scripts/content/','scripts/kart','scripts/local/race_rules','tools/city_packs','tools/content.py')):result['full_roster']=True
    result['vehicles'].sort();result['tracks'].sort()
    return result
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--base',default='HEAD^');parser.add_argument('--output',type=Path);args=parser.parse_args()
    paths=subprocess.check_output(['git','diff','--name-only',args.base,'HEAD'],cwd=ROOT,text=True).splitlines()
    result=select(paths);text=json.dumps(result,indent=2)
    if args.output:args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(text+'\n')
    print(text)
