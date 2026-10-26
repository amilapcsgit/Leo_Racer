"""Serial GPU profiles so independent game instances cannot distort comparisons."""
from qa_kandy231 import ROOT,run
import shutil,json,sys
WORK=ROOT/'build/kandy231'
for label,folder in [('baseline','build/Release-2.3.0/GameAssets/tracks'),('updated','build/kandy231/tracks')]:
 if '--updated-only' in sys.argv and label=='baseline':continue
 for compat in [False,True]:
  for single in [False,True]:
   renderer='gl_compatibility' if compat else 'forward_plus'
   name='profile-'+label+'-'+renderer+('-single' if single else '-split')
   args=['--track=kandy_lake','--tracks='+folder]+(['--single-player'] if single else ['--separated-players'])
   assert run('res://tests/kandy_performance.gd',name,args,headless=False,compat=compat),name
   source=ROOT/('build/kandy/performance-'+renderer+('' if single else '-separated')+'.json');shutil.copy2(source,WORK/(name+'.json'))
print('KANDY_PROFILES_COMPLETE')
