"""Package the offline Kandy development profile and independently installable content.
Never exports an executable or changes the local community vehicle collection.
"""
from pathlib import Path
import argparse,hashlib,json,zipfile,shutil,subprocess
ROOT=Path(__file__).resolve().parents[1]
def sha(path):
 with path.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def dump(path,data):path.write_text(json.dumps(data,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
def zip_tree(source,target,root_name,predicate=lambda p:True):
 with zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED,compresslevel=4) as z:
  for p in sorted(source.rglob('*')):
   rel=p.relative_to(source)
   if p.is_file() and predicate(rel):z.write(p,(Path(root_name)/rel).as_posix())
 with zipfile.ZipFile(target) as z:
  bad=z.testzip();assert bad is None,bad
 return {'file':target.name,'installed_bytes':sum(p.stat().st_size for p in source.rglob('*') if p.is_file() and predicate(p.relative_to(source))),'compressed_bytes':target.stat().st_size,'sha256':sha(target)}
def game_file(p):
 if p.parts[0]=='GameAssets':
  if len(p.parts)>2 and p.parts[1]=='vehicles':return p.parts[2] in ['bigster','duster']
  return '__pycache__' not in p.parts
 if p.parts[0] in ['Tools','data_LeoRacer_windows_x86_64']:return True
 return len(p.parts)==1 and p.name in ['LeoRacer.exe','LeoRacer.console.exe','LeoRacer.pck','README.txt','Play Compatibility.cmd','Play Kandy.cmd','Vehicle Workshop.cmd','development-build.json']
def sdk_file(p):
 return not any(v in ['.godot','__pycache__','exported','exported-test','rebuilt-world','rebuilt-world.logs','.author-scratch','.git'] or v.startswith('.bake-') for v in p.parts) and not p.name.endswith(('.pyc','.pyo'))
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--extract',action='store_true');a=parser.parse_args()
 game=ROOT/'build/Kandy-dev';sdk=ROOT/'build/TrackSDK';out=ROOT/'dist/kandy-development';out.mkdir(parents=True,exist_ok=True)
 commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
 metadata={'version':'2.3.0-kandy-dev','branch':'kandy','source_commit':commit,'profile':'dev','vehicles':['bigster','duster'],'local_installed_vehicle_folders':len(list((game/'GameAssets/vehicles').glob('*/vehicle.json'))),'tracks':['astra_coast','colombo_city','kandy_lake'],'offline':True,'public_release':False,'engine':'Godot 4.7.2 checked/debug'}
 dump(game/'development-build.json',metadata)
 (game/'README.txt').write_text('Leo Racer - Kandy development build, offline\n\nStart LeoRacer.exe or Play Kandy.cmd. The portable ZIP contains Bigster and Duster; six racers reuse these cars. Both previous tracks are retained. The local Kandy-dev folder also retains all your community car folders. Compatible community folders can be copied under GameAssets/vehicles.\n\nKandy Lake is a 2.83 km clockwise, three-lap race-adapted course. It is development content and remains unranked. Existing track IDs/revisions and user-data locations are unchanged. Checkpoint-024 Bigster headlights/brake lamps need this development core. Its 1.3 scale, pivots, driver fits and supplied detailed geometry are preserved.\n\nFor an existing installation, back up old Bigster outside vehicles discovery before replacing it. Keep your original stable game folder. Never delete user-added car folders when updating. Portable packages do not uninstall or reset settings/rankings. All tools/assets load locally. No release has been published.\n\nSeparate track and vehicle ZIPs contain a folder to copy into GameAssets/tracks or GameAssets/vehicles. Future API3 track folders need no executable rebuild. The complete offline SDK includes the editor, authoring plugins, Python, archived geography and notices.\n',encoding='utf-8')
 (game/'Play Kandy.cmd').write_text('@echo off\ncd /d "%~dp0"\nstart "" "LeoRacer.exe" -- --track=kandy_lake\n',encoding='ascii')
 packages={}
 packages['game']=zip_tree(game,out/'LeoRacer-Kandy-dev-win64.zip','LeoRacer',game_file)
 packages['track']=zip_tree(game/'GameAssets/tracks/kandy_lake',out/'KandyLake-1.0.0-track.zip','kandy_lake',lambda p:'staging' not in p.parts)
 packages['bigster']=zip_tree(game/'GameAssets/vehicles/bigster',out/'Bigster-024-vehicle.zip','bigster')
 packages['sdk']=zip_tree(sdk,out/'SriLanka-TrackSDK-win64.zip','TrackSDK',sdk_file)
 packages['exe_bytes']=(game/'LeoRacer.exe').stat().st_size;packages['core_pck_bytes']=(game/'LeoRacer.pck').stat().st_size
 packages['core_and_managed_bytes']=sum(p.stat().st_size for p in game.rglob('*') if p.is_file() and game_file(p.relative_to(game)) and p.relative_to(game).parts[0]!='GameAssets')
 packages['shared_assets_bytes']=sum(p.stat().st_size for p in (game/'GameAssets').rglob('*') if p.is_file() and p.relative_to(game/'GameAssets').parts[0] not in ['vehicles','tracks'])
 packages['tracks_bytes']={p.name:sum(f.stat().st_size for f in p.rglob('*') if f.is_file()) for p in (game/'GameAssets/tracks').iterdir() if p.is_dir()}
 packages['vehicle_dev_bytes']=sum(p.stat().st_size for id in ['bigster','duster'] for p in (game/'GameAssets/vehicles'/id).rglob('*') if p.is_file())
 packages['local_full_install_bytes']=sum(p.stat().st_size for p in game.rglob('*') if p.is_file())
 packages['exe_sha256']=sha(game/'LeoRacer.exe');packages['core_sha256']=sha(game/'LeoRacer.pck');packages['source_commit']=commit
 dump(out/'package-sizes.json',packages)
 (out/'SHA256SUMS.txt').write_text(''.join(v['sha256']+'  '+v['file']+'\n' for v in packages.values() if isinstance(v,dict) and 'file' in v),encoding='utf-8')
 if a.extract:
  destination=ROOT/'build/Kandy-offline-extracted';destination.mkdir(parents=True,exist_ok=True)
  with zipfile.ZipFile(out/packages['game']['file']) as z:z.extractall(destination)
  assert sha(destination/'LeoRacer/LeoRacer.exe')==packages['exe_sha256']
  assert sha(destination/'LeoRacer/LeoRacer.pck')==packages['core_sha256']
 print(json.dumps(packages,indent=2))
if __name__=='__main__':main()
