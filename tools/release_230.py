"""Explicit, offline release assembly; original supplied sources stay local."""
from pathlib import Path
import argparse, hashlib, json, shutil, subprocess, zipfile
import content

ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'build/Release-2.3.0'
ADDONS=ROOT/'build/a'
OUT=ROOT/'dist/release-2.3.0'
SPEC=json.loads((ROOT/'content/releases/2.3.0.json').read_text(encoding='utf-8'))
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):
 with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def dump(p,value):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(value,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
def files(folder):return sorted(p for p in folder.rglob('*') if p.is_file() and p.suffix not in ['.pdb','.log'] and not p.name.startswith('.'))
def nsis(value):return str(value).replace('$','$$').replace('"','$\\"')
def payload(items,base):
 lines=[]
 for p in items:
  relative=p.relative_to(base);parent=str(relative.parent).replace('/','\\')
  short=ROOT/'build/nsis-files'/sha(p);short.parent.mkdir(parents=True,exist_ok=True)
  if not short.exists():shutil.copy2(p,short)
  lines+=['SetOutPath "$PLUGINSDIR\\payload'+('\\'+nsis(parent) if parent!='.' else '')+'"','File "/oname='+nsis(p.name)+'" "'+nsis('..\\'+str(short.relative_to(ROOT)))+'"']
 return '\n'.join(lines)+'\n'
def assemble():
 assert (BASE/'LeoRacer.exe').is_file()
 if not (BASE/'GameAssets/catalog.json').exists():
  import city_packs
  city_packs.split(BASE,True)
 local=ROOT/'build/Kandy-dev/GameAssets/vehicles'
 for key in SPEC['default_vehicles']:
  content.vehicle(key,BASE/'GameAssets/vehicles',local/key if key=='bigster' else None)
 for row in SPEC['optional_vehicles']:content.vehicle(row['id'],ADDONS/'GameAssets/vehicles',local/row['id'])
 assert len(list((BASE/'GameAssets/vehicles').glob('*/vehicle.json')))==16
 assert len(list((ADDONS/'GameAssets/vehicles').glob('*/vehicle.json')))==32
 for key in ['astra_coast','colombo_city','kandy_lake']:
  shutil.copytree(ROOT/'build/Kandy-dev/GameAssets/tracks'/key,BASE/'GameAssets/tracks'/key,dirs_exist_ok=True,ignore=shutil.ignore_patterns('staging'))
 shutil.copy2(ROOT/'installer/InstallerContent.ps1',BASE/'InstallerContent.ps1')
 (BASE/'README.txt').write_text('Leo Racer 2.3.0 - offline Windows release\n\nRun LeoRacer.exe. All three tracks and the original 16 cars are included.\nThe complete installer offers 32 additional cars, initially unchecked. Portable users can copy selected GameAssets/vehicles folders from the separate add-on ZIP.\nNo downloads, account or online services are required. Imported cars remain modded/unranked and have no visible driver. Settings and records retain their existing user-data location.\nKandy is a race-adapted 2.83km course, with an artistically relocated Mahaweli Seya landmark. Compatibility mode has occasional frame spikes; Forward+ is recommended.\nExisting and user-modified files are preserved by installer ownership tracking; replaced modifications are backed up under ContentBackups. Deselecting a previously installed optional car does not remove it.\nSee GameAssets/licenses and each vehicle LICENSE.txt for attribution.\n',encoding='utf-8')
 for name,args in [('Play Compatibility.cmd','--rendering-method gl_compatibility --rendering-driver opengl3'),('Play Kandy.cmd','-- --track=kandy_lake')]:
  (BASE/name).write_text('@echo off\r\ncd /d "%~dp0"\r\nstart "" "LeoRacer.exe" '+args+'\r\n',encoding='ascii')
 dump(BASE/'GameAssets/licenses/Imported-cars-permission.json',SPEC['redistribution_confirmation'])
 dump(ADDONS/'GameAssets/licenses/Imported-cars-permission.json',SPEC['redistribution_confirmation'])
 OUT.mkdir(parents=True,exist_ok=True)
 notices=['LEO RACER 2.3.0 - CONTENT ATTRIBUTION','User confirmation: '+SPEC['redistribution_confirmation']['statement']]
 for folder in [BASE/'GameAssets/vehicles',ADDONS/'GameAssets/vehicles']:
  for p in sorted(folder.glob('*/LICENSE.txt')):notices+=['\n'+p.parent.name,p.read_text(encoding='utf-8-sig')]
 (OUT/'ATTRIBUTION-2.3.0.txt').write_text('\n'.join(notices),encoding='utf-8')
 (ROOT/'installer/release-required.nsh').write_text(payload(files(BASE),BASE),encoding='utf-8')
 sections=[];descriptions=[];selection=['StrCpy $R3 ",$CarSelection,"']
 for i,row in enumerate(SPEC['optional_vehicles']):
  key=row['id'];folder=ADDONS/'GameAssets/vehicles'/key;size=sum(p.stat().st_size for p in files(folder))
  sections+=['Section /o "'+nsis(row['name'])+' ('+f'{size/1e6:.1f}'+' MB)" CAR_'+str(i),payload(files(folder),ADDONS),'SectionEnd']
  descriptions.append('!insertmacro MUI_DESCRIPTION_TEXT ${CAR_'+str(i)+'} "'+nsis(row['name'])+' - '+f'{size/1e6:.1f}'+' MB installed. Optional, modded/unranked; no visible driver."')
  selection+=['${StrStr} $R2 $R3 ",'+key+',"','${If} $CarSelection == "all"','${OrIf} $R2 != ""','SectionSetFlags ${CAR_'+str(i)+'} ${SF_SELECTED}','${EndIf}']
 (ROOT/'installer/release-cars.nsh').write_text('\n'.join(sections),encoding='utf-8')
 (ROOT/'installer/release-descriptions.nsh').write_text('\n'.join(descriptions),encoding='utf-8')
 (ROOT/'installer/release-selection.nsh').write_text('\n'.join(selection),encoding='utf-8')
 dump(ROOT/'build/release-2.3/payload.json',{'version':'2.3.0','default_vehicles':SPEC['default_vehicles'],'optional_vehicles':SPEC['optional_vehicles'],'base_files':{p.relative_to(BASE).as_posix():sha(p) for p in files(BASE)},'addon_files':{p.relative_to(ADDONS).as_posix():sha(p) for p in files(ADDONS)}})
 print('RELEASE_ASSEMBLED defaults=16 optional=32')
def archive(folder,target,prefix):
 with zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED,compresslevel=4) as z:
  for p in files(folder):z.write(p,(Path(prefix)/p.relative_to(folder)).as_posix())
 with zipfile.ZipFile(target) as z:assert z.testzip() is None
def package():
 OUT.mkdir(exist_ok=True)
 archive(BASE,OUT/'LeoRacer-2.3.0-win64.zip','LeoRacer')
 archive(ADDONS,OUT/'LeoRacer-AdditionalCars-2.3.0.zip','')
 archive(BASE/'GameAssets/tracks/kandy_lake',OUT/'LeoRacer-KandyLake-2.3.0.zip','GameAssets/tracks/kandy_lake')
 commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
 sizes={'version':'2.3.0','commit':commit,'base_installed_bytes':sum(p.stat().st_size for p in files(BASE)),'optional_cars_installed_bytes':sum(p.stat().st_size for p in files(ADDONS)),'exe_bytes':(BASE/'LeoRacer.exe').stat().st_size,'core_bytes':(BASE/'LeoRacer.pck').stat().st_size,'default_cars':16,'optional_cars':32}
 sizes['complete_installed_bytes']=sizes['base_installed_bytes']+sizes['optional_cars_installed_bytes'];dump(OUT/'SIZES-2.3.0.json',sizes)
 artifact_names=['LeoRacer-Setup-2.3.0.exe','LeoRacer-2.3.0-win64.zip','LeoRacer-AdditionalCars-2.3.0.zip','LeoRacer-KandyLake-2.3.0.zip','ATTRIBUTION-2.3.0.txt','SIZES-2.3.0.json','RELEASE_NOTES-2.3.0.md']
 rows=[{'name':name,'bytes':(OUT/name).stat().st_size,'sha256':sha(OUT/name)} for name in artifact_names]
 (OUT/'SHA256SUMS.txt').write_text(''.join(row['sha256']+'  '+row['name']+'\n' for row in rows),encoding='utf-8')
 rows.append({'name':'SHA256SUMS.txt','bytes':(OUT/'SHA256SUMS.txt').stat().st_size,'sha256':sha(OUT/'SHA256SUMS.txt')})
 dump(OUT/'release-manifest.json',{'version':'2.3.0','commit':commit,'files':rows})
 print('RELEASE_PACKAGED',json.dumps(sizes))
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('target',choices=['assemble','package']);a=p.parse_args();assemble() if a.target=='assemble' else package()
