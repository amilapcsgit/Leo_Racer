"""Exercise selected payloads and ownership using isolated, short workspace paths."""
from pathlib import Path
import json,os,subprocess
from release_230 import ROOT,SPEC,OUT,sha,dump
SETUP=OUT/'LeoRacer-Setup-2.3.0.exe'
def run(exe,args):
 env=os.environ.copy();temporary=ROOT.parent.parent/'t';temporary.mkdir(exist_ok=True);env['TEMP']=env['TMP']=str(temporary)
 p=subprocess.run([str(exe),*args],cwd=ROOT,env=env,timeout=600)
 assert p.returncode==0,(str(exe),p.returncode)
def installed(folder):return sorted(p.parent.name for p in (folder/'GameAssets/vehicles').glob('*/vehicle.json'))
def main():
 ids=[r['id'] for r in SPEC['optional_vehicles']];defaults=SPEC['default_vehicles'];rows=[]
 cases=[('default',[]),('individual',ids[:1]),('mixed',ids[:2]),('all',ids)]
 for index,(name,selected) in enumerate(cases):
  folder=ROOT/('k'+str(index));assert not folder.exists(),'Review existing test installation before reuse: '+str(folder)
  selection='all' if name=='all' else ','.join(selected)
  run(SETUP,['/S','/CONTENTTEST','/CARS='+selection,'/D='+str(folder)])
  assert installed(folder)==sorted(defaults+selected),(name,installed(folder))
  record=json.loads((folder/'.leo-installer-owned.json').read_text(encoding='utf-8'))
  assert all((folder/path).is_file() for path in record['files'])
  if name=='mixed':
   custom=folder/'GameAssets/vehicles/my_car';custom.mkdir();(custom/'keep.txt').write_text('user content',encoding='utf-8')
   changed=folder/'GameAssets/vehicles'/ids[0]/'LICENSE.txt';changed.write_text('user annotation',encoding='utf-8')
   # Re-run with no optional cars: previous selection and edits must survive.
   run(SETUP,['/S','/CONTENTTEST','/D='+str(folder)])
   assert installed(folder)==sorted(defaults+selected)
   assert changed.read_text(encoding='utf-8')=='user annotation'
   # Selecting it again backs up the edit before restoring packaged content.
   run(SETUP,['/S','/CONTENTTEST','/CARS='+ids[0],'/D='+str(folder)])
   assert any(p.read_text(encoding='utf-8')=='user annotation' for p in (folder/'ContentBackups').rglob('*LICENSE.txt'))
   changed.write_text('retain on uninstall',encoding='utf-8')
  run(folder/'Uninstall.exe',['/S','/CONTENTTEST','_?='+str(folder)])
  assert not (folder/'LeoRacer.exe').exists()
  if name=='mixed':
   assert changed.read_text(encoding='utf-8')=='retain on uninstall'
   assert (custom/'keep.txt').read_text(encoding='utf-8')=='user content'
  rows.append({'case':name,'default_cars':16,'optional_cars':len(selected),'status':'PASS'})
  print('INSTALLER_CASE_PASS',name,flush=True)
 dump(ROOT/'build/release-2.3/qa/installer.json',{'status':'PASS','cases':rows,'upgrade_additions':True,'deselection_preserves_existing':True,'modified_backups':True,'uninstall_preserves_custom_and_modified':True})
if __name__=='__main__':main()
