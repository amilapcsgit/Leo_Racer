"""Reproducible final 2.6 assembly; never writes earlier preview outputs."""
from pathlib import Path
import argparse, json, os, shutil, subprocess, zipfile, time
import city_packs, content, verify_distinct as verify
from release_231 import files as release_files, payload, sha, dump

def files(folder):
 return [p for p in release_files(folder) if p.name not in ["smoke-test.json","race-test.json"]]
R=Path(__file__).resolve().parents[1]
BASE=R/'build/Release-2.6.0-Final'
OUT=R/'dist/release-2.6.0'
Q=R/'build/qa26-final'

def functional_gate():
 for renderer in ['forward','compatibility']:
  report=json.loads((Q/('ui-'+renderer)/'ui.json').read_text(encoding='utf-8'))
  assert report['status']=='PASS',renderer
  assert json.loads((Q/('polish-'+renderer)/'polish.json').read_text(encoding='utf-8'))['status']=='PASS',renderer

def stage():
 functional_gate()
 assert (BASE/'LeoRacer.exe').is_file()
 assert not (BASE/'GameAssets/catalog.json').exists(),'Use a freshly exported destination'
 city_packs.split(BASE,True)
 source=R/'build/lighting-content/GameAssets'
 for name in ['vehicles','tracks','environments','licenses']:
  shutil.copytree(source/name,BASE/'GameAssets'/name,dirs_exist_ok=True)
 catalog=json.loads((BASE/'GameAssets/catalog.json').read_text(encoding='utf-8'))
 catalog.update(vehicle_api=2,core={'min':'2.6.0','max_major':2})
 neutral=BASE/'GameAssets/environments/dusk-neutral.pck'
 catalog['packs'].append({'id':'environments/dusk-neutral','file':'environments/dusk-neutral.pck','sha256':sha(neutral),'bytes':neutral.stat().st_size})
 dump(BASE/'GameAssets/catalog.json',catalog)
 engine,entries=city_packs.read_pack(BASE/'LeoRacer.pck')
 entries['assets/config/official-track-content.json']=(R/'assets/config/official-track-content.json').read_bytes()
 # Keep opt-in diagnostic entry points available even when the editor's
 # filesystem snapshot predates their first import. Gameplay stays compiled.
 for name in ['release26_ui_check','release26_content_check','release26_polish_check']:
  path='scripts/content/'+name+'.gd'
  if path not in entries and path+'.remap' not in entries:entries[path]=(R/path).read_bytes()
 city_packs.write_pack(BASE/'LeoRacer.pck',engine,entries)
 assert len(list((BASE/'GameAssets/vehicles').glob('*/vehicle.json')))==21
 assert len(list((BASE/'GameAssets/tracks').glob('*/manifest.json')))==3
 for pack in catalog['packs']:
  assert sha(BASE/'GameAssets'/pack['file'])==pack['sha256'],pack['file']
 for source_name,dest_name in [('installer/InstallerContent.ps1','InstallerContent.ps1'),('assets/config/default-roster-v1.json','default-roster-v1.json'),('docs/RELEASE_NOTES_260_FINAL.md','RELEASE_NOTES.md'),('docs/VALIDATION_260_FINAL.md','TEST_REPORT.md')]:
  shutil.copy2(R/source_name,BASE/dest_name)
 (BASE/'README.txt').write_text('LEO RACER 2.6.0\n\nRun LeoRacer.exe; keep the complete folder together. No SDK, account or network required.\n21 cars and three tracks. Use Play Compatibility.cmd if Vulkan is unavailable.\nStatic and Dusk to Night are selectable in setup.\nExtract portable releases into a NEW folder. Back up your previous game and custom content before upgrading. The installer tracks managed content and backs up modified files under ContentBackups. Unrelated custom content and user profiles are preserved.\nProfiles and records use the existing Windows user-data location.\nSee TEST_REPORT.md for validation and remaining performance/shutdown warnings.\nCredits and source terms: GameAssets/licenses and each vehicle LICENSE.txt.\n',encoding='utf-8')
 (BASE/'Play Compatibility.cmd').write_text('@echo off\ncd /d "%~dp0"\nstart "" "LeoRacer.exe" --rendering-method gl_compatibility --rendering-driver opengl3\n',encoding='ascii')
 dump(BASE/'release-build.json',{'version':'2.6.0','core_sha256':sha(BASE/'LeoRacer.pck'),'default_vehicles':21,'tracks':3})
 OUT.mkdir(parents=True,exist_ok=True)
 print('FINAL26_STAGED',flush=True)

def installer():
 functional_gate();OUT.mkdir(parents=True,exist_ok=True)
 script=(R/'installer/FocusedCars250.nsi').read_text(encoding='utf-8').replace('2.5.0','2.6.0').replace('release250-','release26-final-').replace('20 tested cars','21 tested cars').replace('20 cars','21 cars').replace('20 default cars','21 default cars').replace('selected 20 vehicles','selected 21 vehicles')
 (R/'installer/Release26Final.nsi').write_text(script,encoding='utf-8')
 tracks=json.loads((R/'content/releases/2.3.2.json').read_text(encoding='utf-8'))['tracks']
 for suffix in ['required','tracks','descriptions','selection']:
  if suffix=='required':text=payload([p for p in files(BASE) if not p.relative_to(BASE).as_posix().startswith('GameAssets/tracks/')],BASE)
  elif suffix=='tracks':text='\n'.join('Section "'+row['name']+'" TRACK_'+str(i)+'\nSectionIn 1 2\n'+payload(files(BASE/'GameAssets/tracks'/row['id']),BASE)+'SectionEnd' for i,row in enumerate(tracks))
  elif suffix=='descriptions':text='\n'.join('!insertmacro MUI_DESCRIPTION_TEXT ${TRACK_'+str(i)+'} "'+row['name']+'; solo and split-screen."' for i,row in enumerate(tracks))
  else:text=(R/'installer/release250-selection.nsh').read_text(encoding='utf-8')
  (R/('installer/release26-final-'+suffix+'.nsh')).write_text(text,encoding='utf-8')
 env=dict(os.environ,TEMP=str(Q/'installer-temp'),TMP=str(Q/'installer-temp'));Path(env['TEMP']).mkdir(exist_ok=True)
 with (Q/'installer-build.log').open('w',encoding='utf-8') as log:
  subprocess.run([str(R/'.tools/nsis/nsis-3.13/Bin/makensis.exe'),'/V3','installer/Release26Final.nsi'],cwd=R,env=env,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=1200)
 dest=R.parent.parent/('i26final-'+sha(BASE/'LeoRacer.pck')[:8]+'-'+str(int(time.time())))
 assert dest.resolve().is_relative_to(R.parent.parent.resolve()) and not dest.exists(),'Preserve previous installations'
 def run(exe,args):subprocess.run([str(exe),*args],cwd=R,env=env,check=True,timeout=900,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
 setup=OUT/'LeoRacer-Setup.exe';args=['/S','/CONTENTTEST','/TESTDIR='+str(dest),'/D='+str(dest)]
 run(setup,args)
 assert len(list((dest/'GameAssets/vehicles').glob('*/vehicle.json')))==21
 assert len(list((dest/'GameAssets/tracks').glob('*/manifest.json')))==3
 assert sha(dest/'LeoRacer.pck')==sha(BASE/'LeoRacer.pck')
 verify.QA=Q/'installed';verify.QA.mkdir(exist_ok=True)
 assert verify.run('content',dest,args=['--verify-content'],vehicles=dest/'GameAssets/vehicles')
 custom=dest/'GameAssets/vehicles/unmanaged-test/keep.txt';custom.parent.mkdir();custom.write_text('preserve custom',encoding='utf-8')
 readme=dest/'README.txt';readme.write_text('modified managed file',encoding='utf-8');run(setup,args)
 assert custom.read_text()=='preserve custom'
 assert any(p.read_text(encoding='utf-8')=='modified managed file' for p in (dest/'ContentBackups').rglob('*README.txt'))
 readme.write_text('preserve on uninstall',encoding='utf-8')
 run(dest/'Uninstall.exe',['/S','/CONTENTTEST','_?='+str(dest)])
 assert not (dest/'LeoRacer.exe').exists() and custom.read_text()=='preserve custom' and readme.read_text()=='preserve on uninstall'
 dump(Q/'installer-full.json',{'status':'PASS','cars':21,'tracks':3,'core_sha256':sha(BASE/'LeoRacer.pck'),'installer_sha256':sha(setup),'clean_install':True,'reinstall_backup':True,'uninstall_preservation':True})
 print('FINAL26_INSTALLER_PASS',flush=True)

def archive(name,mapping):
 target=OUT/name
 with zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED,compresslevel=4) as z:
  for name,p in sorted(mapping.items()):z.write(p,name)
 with zipfile.ZipFile(target) as z:assert z.testzip() is None
 print('ARCHIVE_VERIFIED',target.name,flush=True)
 return target

def package():
 functional_gate();assert json.loads((Q/'installer-full.json').read_text())['core_sha256']==sha(BASE/'LeoRacer.pck')
 smoke=json.loads((Q/'export-smoke.json').read_text(encoding='utf-8'))
 assert smoke['status']=='PASS' and smoke['core_sha256']==sha(BASE/'LeoRacer.pck')
 artifacts=[archive('LeoRacer-2.6.0-win64.zip',{'LeoRacer/'+p.relative_to(BASE).as_posix():p for p in files(BASE)})]
 content.sdk();shutil.copy2(R/'dist/LeoRacer-Contributor-SDK.zip',OUT/'LeoRacer-Contributor-SDK-2.6.0.zip')
 art={p.relative_to(R/'assets/ui').as_posix():p for p in [*(R/'assets/ui/art').glob('home-*-v26.png'),R/'assets/ui/art/garage-skyline-v26.png',R/'assets/ui/art/artwork-v26.json',*(R/'assets/ui/boot/tracks').glob('*/*.png')]}
 artifacts.append(archive('LeoRacer-2.6.0-UI-Art.zip',art))
 for key,name in [('duster','Duster_My_2014'),('duster_2024','Duster_2024')]:
  mapping={'GameAssets/vehicles/'+key+'/'+p.relative_to(BASE/'GameAssets/vehicles'/key).as_posix():p for p in files(BASE/'GameAssets/vehicles'/key)};mapping['INSTALLATION.txt']=BASE/'README.txt'
  artifacts.append(archive(name+'-LeoRacer-2.6.zip',mapping))
 masters=R.parent.parent
 artifacts.append(archive('Duster-2.6-Blender-Masters.zip',{'Duster_My_2014.blend':masters/'Duster_My_2014/Duster_My_2014.blend','Duster_2024.blend':masters/'Duster_2024/Duster_2024_runtime.blend','source-integrity.json':R/'build/qa260/source-integrity.json'}))
 evidence={p.relative_to(Q).as_posix():p for p in Q.rglob('*') if p.is_file() and p.suffix in ['.json','.png','.log','.mp4'] and not any('profile' in part or part.startswith('preflight') for part in p.relative_to(Q).parts)}
 for name in ['regression-audit','regression-contacts','regression-replay','cold-contact-forward','cold-contact-compatibility']:
  for p in (R/'build/qa-lighting'/name).rglob('*'):
   if p.is_file() and p.suffix in ['.json','.log']:evidence['prior-unchanged-physics/'+name+'/'+p.name]=p
 artifacts.append(archive('LeoRacer-2.6.0-Evidence.zip',evidence))
 for src,name in [('docs/RELEASE_NOTES_260_FINAL.md','RELEASE_NOTES.md'),('docs/VALIDATION_260_FINAL.md','TEST_REPORT.md')]:shutil.copy2(R/src,OUT/name)
 artifacts += [OUT/n for n in ['LeoRacer-Setup.exe','LeoRacer-Contributor-SDK-2.6.0.zip','RELEASE_NOTES.md','TEST_REPORT.md']]
 rows=[{'name':p.name,'bytes':p.stat().st_size,'sha256':sha(p)} for p in artifacts]
 sums=OUT/'SHA256SUMS.txt';sums.write_text(''.join(r['sha256']+'  '+r['name']+'\n' for r in rows),encoding='utf-8');rows.append({'name':sums.name,'bytes':sums.stat().st_size,'sha256':sha(sums)})
 dump(OUT/'release-manifest.json',{'version':'2.6.0','commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=R,text=True).strip(),'cars':21,'tracks':3,'files':rows})

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('action',choices=['stage','installer','package']);a=p.parse_args();globals()[a.action]()
