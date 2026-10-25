"""Release checks with isolated profiles; no imported-car driver combinations."""
from pathlib import Path
import concurrent.futures,json,os,shutil,subprocess,sys
from release_230 import ROOT,BASE,ADDONS,SPEC,dump
import batch_vehicles
QA=ROOT/'build/release-2.3/qa'
def game(args,label,folder=BASE):
 QA.mkdir(parents=True,exist_ok=True);env=os.environ.copy();env['APPDATA']=str(QA/'profiles'/label)
 Path(env['APPDATA']).mkdir(parents=True,exist_ok=True)
 p=subprocess.run([str(folder/'LeoRacer.console.exe'),'--headless','--','--drive-test',*args],env=env,cwd=folder,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=240)
 text=p.stdout+p.stderr;(QA/(label+'.log')).write_text(text,encoding='utf-8')
 assert p.returncode==0 and 'SCRIPT ERROR' not in text,(label,p.returncode,text[-2000:])
 return text
def cars():
 combined=QA/'all-vehicles';combined.mkdir(parents=True,exist_ok=True)
 for source in [BASE/'GameAssets/vehicles',ADDONS/'GameAssets/vehicles']:shutil.copytree(source,combined,dirs_exist_ok=True)
 text=game(['--validate-vehicles','--vehicles='+str(combined)],'all-48')
 marker=next(line for line in text.splitlines() if line.startswith('VEHICLE_VALIDATION '));report=json.loads(marker.split(' ',1)[1])
 assert report['status']=='PASS' and len(report['vehicles'])==48
 assert sum(row['official'] for row in report['vehicles'])==16
 dump(QA/'all-48.json',report)
 if (QA/'addon-motion.json').exists() and json.loads((QA/'addon-motion.json').read_text(encoding='utf-8'))['status']=='PASS':
  print('ALL_48_PASS; unchanged 32-car wheel report retained',flush=True);return
 def check(row):
  result=batch_vehicles.godot({'id':row['id'],'mode':'validate','folder':str(ADDONS/'GameAssets/vehicles'/row['id'])})
  assert result.get('ok'),(row['id'],result)
  return {'id':row['id'],**result}
 with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:rows=list(pool.map(check,SPEC['optional_vehicles']))
 dump(QA/'addon-motion.json',{'status':'PASS','cars':rows,'driver_tests':0});print('ALL_48_AND_32_WHEEL_CHECKS_PASS',flush=True)
def races():
 jobs=[(track,mode) for track in ['astra_coast','colombo_city','kandy_lake'] for mode in ['single','split']]
 def check(job):
  track,mode=job;label=track+'-'+mode;output=QA/label
  text=game(['--track='+track,'--track-check='+mode,'--qa-output='+str(output)],label)
  report=json.loads((output/(mode+'-'+track+'.json')).read_text(encoding='utf-8'));assert report['status']=='PASS';return report
 with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:rows=list(pool.map(check,jobs))
 dump(QA/'races.json',{'status':'PASS','races':rows});print('ALL_SIX_RACES_PASS',flush=True)
if __name__=='__main__':
 {'cars':cars,'races':races}[sys.argv[1]]()
