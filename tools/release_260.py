"""Local v2.6 preview assembly. No network publication command exists here."""
from pathlib import Path
import argparse,hashlib,json,shutil,subprocess,zipfile
import city_packs,content
from release_231 import payload,files
ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'build/Preview-2.6.0'
OUT=ROOT/'dist/preview-2.6.0'
QA=ROOT/'build/qa260'
def sha(p):return content.sha(p)
def dump(p,v):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(v,indent=2)+'\n',encoding='utf-8')
def require_gates():
 report=json.loads((QA/'acceptance.json').read_text(encoding='utf-8'))
 assert report['status']=='PASS','Functional and performance gates must pass before building the preview'
def bundle_tracks():
 engine,entries=city_packs.read_pack(BASE/'LeoRacer.pck')
 trusted=json.loads(entries['assets/config/official-track-content.json'])
 for track in ['astra_coast','colombo_city','kandy_lake']:
  target=BASE/'GameAssets/tracks'/track
  if not (target/'manifest.json').exists():
   source=ROOT/'build/preview260/GameAssets/tracks'/track
   assert (source/'manifest.json').is_file(),'Missing bundled track: '+track
   shutil.copytree(source,target,dirs_exist_ok=True)
  data=json.loads((target/'manifest.json').read_text(encoding='utf-8'))
  trusted[track+':'+str(int(data['course_revision']))]=[pack['sha256'] for pack in data['packs']]
 entries['assets/config/official-track-content.json']=json.dumps(trusted,sort_keys=True).encode()
 city_packs.write_pack(BASE/'LeoRacer.pck',engine,entries)
 if (BASE/'release-build.json').exists():
  report=json.loads((BASE/'release-build.json').read_text(encoding='utf-8'));report['core_sha256']=sha(BASE/'LeoRacer.pck');dump(BASE/'release-build.json',report)
def stage():
 require_gates()
 assert (BASE/'LeoRacer.exe').is_file(),'Export the Windows preview first'
 if not (BASE/'GameAssets/catalog.json').exists():city_packs.split(BASE,True)
 destination=BASE/'GameAssets/vehicles'
 assert not destination.exists() or not any(destination.glob('*/vehicle.json')),'Use a fresh preview output'
 for key in content.roster_ids():content.vehicle(key,destination,content.RUNTIME/key)
 neutral=ROOT/'build/preview260/GameAssets/environments/dusk-neutral.pck'
 target=BASE/'GameAssets/environments/dusk-neutral.pck';target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(neutral,target)
 catalog=json.loads((BASE/'GameAssets/catalog.json').read_text(encoding='utf-8'))
 catalog.update(vehicle_api=2,core={'min':'2.6.0','max_major':2})
 catalog['packs'].append({'id':'environments/dusk-neutral','file':'environments/dusk-neutral.pck','sha256':sha(target),'bytes':target.stat().st_size})
 dump(BASE/'GameAssets/catalog.json',catalog)
 shutil.copy2(ROOT/'assets/config/default-roster-v1.json',BASE/'default-roster-v1.json')
 shutil.copy2(ROOT/'installer/InstallerContent.ps1',BASE/'InstallerContent.ps1')
 shutil.copy2(ROOT/'docs/QUALITY260.md',BASE/'TEST_REPORT.md')
 shutil.copy2(ROOT/'docs/RELEASE_NOTES_260.md',BASE/'RELEASE_NOTES.md')
 (BASE/'README.txt').write_text('LEO RACER 2.6.0 PREVIEW\n\nRun LeoRacer.exe; keep the complete folder together. No SDK or network required.\n21 default cars, including Duster_My_2014 and Dacia Duster 2024. Bigster remains the fallback.\nUse Play Compatibility.cmd if Vulkan is unavailable. Choose Static or Dusk to Night in race setup.\nFor an upgrade, back up the old game folder and use the supplied installer ownership script, or extract into a new folder. Do not merge obsolete low-poly vehicle files by hand.\nKeep custom cars and player profiles backed up. Profiles and earlier records retain their existing user-data location.\nAttribution: GameAssets/licenses and individual vehicle LICENSE.txt files.\nLocal preview only; see TEST_REPORT.md for gates, hardware and known shutdown warnings.\n',encoding='utf-8')
 (BASE/'Play Compatibility.cmd').write_text('@echo off\ncd /d "%~dp0"\nstart "" "LeoRacer.exe" --rendering-method gl_compatibility --rendering-driver opengl3\n',encoding='ascii')
 dump(BASE/'release-build.json',{'version':'2.6.0-preview','branch':'release/2.6.0','default_vehicles':21,'tracks':3,'public_release':False,'core_sha256':sha(BASE/'LeoRacer.pck')})
 bundle_tracks()
 manifest()
 print('PREVIEW260_STAGED',flush=True)
def manifest():
 size_file=BASE/'asset-sizes.json'
 sizes=json.loads(size_file.read_text(encoding='utf-8')) if size_file.exists() else {}
 sizes.update(core_bytes=(BASE/'LeoRacer.pck').stat().st_size,installed_bytes=sum(p.stat().st_size for p in files(BASE)),default_vehicles=21,compiled_vehicle_bytes=sum(p.stat().st_size for p in files(BASE/'GameAssets/vehicles')),tracks={p.name:sum(f.stat().st_size for f in files(p)) for p in (BASE/'GameAssets/tracks').iterdir() if p.is_dir()})
 dump(size_file,sizes)
 dump(BASE/'required-payload.json',{'files':{p.relative_to(BASE).as_posix():sha(p) for p in files(BASE) if p.name!='required-payload.json' and not p.relative_to(BASE).as_posix().startswith('GameAssets/tracks/')}})
 OUT.mkdir(parents=True,exist_ok=True)
 script=(ROOT/'installer/FocusedCars250.nsi').read_text(encoding='utf-8').replace('2.5.0','2.6.0').replace('release-2.6.0','preview-2.6.0').replace('release250-','release260-').replace('20 tested cars','21 tested cars').replace('20 cars','21 cars').replace('20 default cars','21 default cars').replace('Name \"Leo Racer 2.6.0\"','Name \"Leo Racer 2.6.0 preview\"').replace('Leo Racer offline installer','Leo Racer offline preview installer')
 (ROOT/'installer/StreamedCars260.nsi').write_text(script,encoding='utf-8')
 tracks=json.loads((ROOT/'content/releases/2.3.2.json').read_text(encoding='utf-8'))['tracks']
 for suffix in ['required','tracks','descriptions','selection']:
  if suffix=='required':text=payload([p for p in files(BASE) if not p.relative_to(BASE).as_posix().startswith('GameAssets/tracks/')],BASE)
  elif suffix=='tracks':text='\n'.join('Section "'+row['name']+'" TRACK_'+str(i)+'\nSectionIn 1 2\n'+payload(files(BASE/'GameAssets/tracks'/row['id']),BASE)+'SectionEnd' for i,row in enumerate(tracks))
  elif suffix=='descriptions':text='\n'.join('!insertmacro MUI_DESCRIPTION_TEXT ${TRACK_'+str(i)+'} "'+row['name']+'; solo and split-screen."' for i,row in enumerate(tracks))
  else:text=(ROOT/'installer/release250-selection.nsh').read_text(encoding='utf-8')
  (ROOT/('installer/release260-'+suffix+'.nsh')).write_text(text,encoding='utf-8')
def package():
 require_gates();OUT.mkdir(parents=True,exist_ok=True)
 smoke=json.loads((QA/'export-smoke.json').read_text(encoding='utf-8'))
 assert smoke['status']=='PASS' and smoke['core_sha256']==sha(BASE/'LeoRacer.pck')
 installed=json.loads((QA/'installer-full.json').read_text(encoding='utf-8'))
 assert installed['status']=='PASS' and installed['core_sha256']==sha(BASE/'LeoRacer.pck') and installed['installer_sha256']==sha(OUT/'LeoRacer-Setup.exe')
 shutil.copy2(ROOT/'docs/QUALITY260.md',OUT/'TEST_REPORT.md')
 shutil.copy2(ROOT/'docs/RELEASE_NOTES_260.md',OUT/'RELEASE_NOTES.md')
 content.sdk();shutil.copy2(ROOT/'dist/LeoRacer-Contributor-SDK.zip',OUT/'LeoRacer-Contributor-SDK-2.6.0.zip')
 artifacts=[]
 def archive(name,mapping):
  path=OUT/name
  with zipfile.ZipFile(path,'w',zipfile.ZIP_DEFLATED,compresslevel=4) as z:
   for name,source in sorted(mapping.items()):z.write(source,name)
  with zipfile.ZipFile(path) as z:assert z.testzip() is None
  artifacts.append(path)
 archive('LeoRacer-2.6.0-preview-win64.zip',{'LeoRacer/'+p.relative_to(BASE).as_posix():p for p in files(BASE)})
 roots=['functional-forward','functional-compatibility','environment-forward','environment-compatibility','final-static-forward','final-static-compatibility','final-dusk-forward','final-dusk-compatibility','baseline-forward','baseline-compatibility','regression-audit','regression-contacts','regression-replay','compile-reports','export','captures-forward','captures-compatibility']
 evidence={p.relative_to(QA).as_posix():p for root in roots for p in (QA/root).rglob('*') if p.is_file() and p.suffix in ['.json','.png','.log'] and not any('profile' in part for part in p.relative_to(QA).parts)}
 evidence.update({p.name:p for p in QA.glob('*.json') if not p.name.startswith('baseline_')})
 evidence['TEST_REPORT.md']=ROOT/'docs/QUALITY260.md'
 archive('LeoRacer-2.6.0-Evidence.zip',evidence)
 for key,name in [('duster','Duster_My_2014'),('duster_2024','Duster_2024')]:
  mapping={'GameAssets/vehicles/'+key+'/'+p.relative_to(BASE/'GameAssets/vehicles'/key).as_posix():p for p in files(BASE/'GameAssets/vehicles'/key)}
  mapping['INSTALLATION.txt']=BASE/'README.txt'
  for renderer in ['forward','compatibility']:
   for image in (QA/('captures-'+renderer)).glob(name+'*.png'):mapping['Previews/'+renderer+'/'+image.name]=image
  archive(name+'-LeoRacer-2.6.zip',mapping)
 masters=ROOT.parent.parent
 archive('Duster-2.6-Blender-Masters.zip',{'Duster_My_2014.blend':masters/'Duster_My_2014/Duster_My_2014.blend','Duster_2024.blend':masters/'Duster_2024/Duster_2024_runtime.blend','source-integrity.json':QA/'source-integrity.json'})
 if (OUT/'LeoRacer-Setup.exe').exists():artifacts.append(OUT/'LeoRacer-Setup.exe')
 artifacts += [OUT/'LeoRacer-Contributor-SDK-2.6.0.zip',OUT/'TEST_REPORT.md',OUT/'RELEASE_NOTES.md']
 rows=[{'name':p.name,'bytes':p.stat().st_size,'sha256':sha(p)} for p in artifacts]
 (OUT/'SHA256SUMS.txt').write_text(''.join(row['sha256']+'  '+row['name']+'\n' for row in rows),encoding='utf-8')
 dump(OUT/'preview-manifest.json',{'version':'2.6.0-preview','public_release':False,'commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'cars':21,'tracks':3,'artifacts':rows})
 print('PREVIEW260_PACKAGED',flush=True)
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('action',choices=['stage','bundle_tracks','manifest','package']);args=parser.parse_args();globals()[args.action]()
