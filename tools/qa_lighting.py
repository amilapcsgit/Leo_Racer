"""Independent native/source checks; never overwrite the accepted 2.6 evidence."""
from pathlib import Path
import argparse,os
import qa260
R=Path(__file__).resolve().parents[1]
Q=R/'build/qa-lighting';Q.mkdir(exist_ok=True)
qa260.Q=Q
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('phase',choices=['presentation','world','functional','content','environment','performance']);p.add_argument('--compat',action='store_true');p.add_argument('--track');p.add_argument('--players',type=int);p.add_argument('--impact-only',action='store_true');p.add_argument('--dusk',action='store_true');a=p.parse_args()
 scripts={'presentation':'tests/lighting_presentation_test.gd','world':'tests/lighting_world_test.gd','functional':'tests/release260_runtime_test.gd','content':'tests/release260_content_test.gd','environment':'tests/release260_environment_test.gd'}
 os.environ['LEO_ASSET_ROOT']=str(R/'build/lighting-content/GameAssets')
 extra=[]
 if a.track:extra+=['--qa-track='+a.track,'--lighting-track='+a.track]
 if a.players:extra+=['--qa-humans='+str(a.players),'--players='+str(a.players)]
 if a.impact_only:extra+=['--impact-only']
 if a.dusk:extra+=['--qa-dusk']
 label=a.phase+('-dusk' if a.dusk else '')+('-compatibility' if a.compat else '-forward')+('-'+a.track if a.track else '')+('-'+str(a.players)+'p' if a.players else '')+('-impact' if a.impact_only else '')
 if a.phase=='performance':
  qa260.run(label,'',a.compat,extra=['--track-check=performance',*extra],exe=R/'build/native-lighting/LeoRacer.console.exe',vehicles=R/'build/lighting-content/GameAssets/vehicles',tracks=R/'build/lighting-content/GameAssets/tracks')
 else:qa260.run(label,scripts[a.phase],a.compat,extra=extra,vehicles=R/'build/lighting-content/GameAssets/vehicles',tracks=R/'build/lighting-content/GameAssets/tracks')
