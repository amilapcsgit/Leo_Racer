"""Package the complete .NET game and unpack it to a fresh verification path."""
from pathlib import Path
import hashlib, json, shutil, zipfile, argparse, subprocess
p=argparse.ArgumentParser();p.add_argument("--version",default="1.5.0");p.add_argument("--checksums-only",action="store_true");p.add_argument("--branch",default="ModularGarage");args=p.parse_args()
ROOT=Path(__file__).resolve().parent.parent
BUILD=ROOT/'build/ModularGarage'
DIST=ROOT/'dist'
DIST.mkdir(exist_ok=True)
FOLDER='Leo Racer Bigster RC' if args.branch=='bigster' else 'Leo Racer Modular Garage'
SUFFIX='BigsterRC' if args.branch=='bigster' else 'ModularGarage'
if args.checksums_only:
 entries=[]
 for path in sorted(DIST.iterdir()):
  if path.suffix in ['.zip','.exe','.json'] and args.version in path.name:
   entries.append(hashlib.sha256(path.read_bytes()).hexdigest()+'  '+path.name)
 (DIST/'SHA256SUMS.txt').write_text('\n'.join(entries)+'\n')
 raise SystemExit()
assert (BUILD/'Leo Racer.exe').is_file()
assert (BUILD/'Leo Racer Launcher.exe').is_file()
assert (BUILD/'data_LeoRacer_windows_x86_64/LeoRacer.dll').is_file()
assert (BUILD/'libterrain.windows.release.x86_64.dll').is_file()
for name in ['coreclr.dll','hostfxr.dll','hostpolicy.dll','System.Private.CoreLib.dll']:
 assert list((BUILD/'data_LeoRacer_windows_x86_64').rglob(name)), 'Missing bundled runtime: '+name
shutil.copytree(ROOT/'licenses',BUILD/'licenses',dirs_exist_ok=True)
(BUILD/'Play Leo Racer.cmd').write_text('@echo off\nstart "" "%~dp0Leo Racer.exe"\n')
(BUILD/'Play Compatibility Mode.cmd').write_text('@echo off\nstart "" "%~dp0Leo Racer.exe" --rendering-method gl_compatibility --rendering-driver opengl3\n')
(BUILD/'README.txt').write_text(f'''LEO RACER / v{args.version}

Extract this entire folder, then run Leo Racer Launcher.exe.
Keep data_LeoRacer_windows_x86_64 and libterrain.windows.release.x86_64.dll
beside the executable. No editor or .NET SDK installation is needed.

W/S or arrows: accelerate, brake/reverse. A/D or arrows: steer.
SPACE: drift. SHIFT: nitro. R: recover. H: horn. ESC: pause. F8: hide HUD.
Reduced Motion is available in Settings. Controller input is supported.

Use Play Compatibility Mode.cmd if Vulkan is unavailable.
Three laps of the 1.9 km circuit, six racers, six drivers and sixteen vehicles.
Tap accelerate on the final countdown beat for a launch boost.
Slipstream behind another racer to recharge nitro. Hold/release drift for turbo.
Existing preferences are retained; Astra has a separate best-time record.

Source and setup: https://github.com/amilapcsgit/Leo_Racer/tree/{args.branch}
Component notices are in licenses/. See source docs/MODULAR_GARAGE_VALIDATION.md
for verification results and engine cleanup-warning notes.

Bigster RC: LB/RB cycles cars in the garage. Use the name keyboard with A.
Pause > Change Car retains the race. Continue swaps only your car; changed
races cannot set records. Start New Race restarts; Back cancels the changes.
Duster: 165/198 km/h. Bigster: 180/225 km/h with electric boost and braking regen.

''')
exe_hash=hashlib.sha256((BUILD/'Leo Racer.exe').read_bytes()).hexdigest()
manifest={'version':args.version,'branch':args.branch,'godot':'4.7.2 .NET','architecture':'Windows x86_64','exe_sha256':exe_hash,'runtime_bundled':True,'terrain_library_bundled':True}
manifest['commit']=subprocess.check_output(['git','-c','safe.directory='+ROOT.as_posix(),'-C',str(ROOT),'rev-parse','HEAD']).decode().strip()
manifest['source_tree']=subprocess.check_output(['git','-c','safe.directory='+ROOT.as_posix(),'-C',str(ROOT),'rev-parse','HEAD^{tree}']).decode().strip()
(BUILD/'build-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
archive=DIST/f'LeoRacer-Windows-{args.version}-{SUFFIX}.zip'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for path in sorted(BUILD.rglob('*')):
  if not path.is_file(): continue
  rel=path.relative_to(BUILD)
  if rel.parent==Path('.') and path.suffix in ['.log','.png','.json'] and path.name!='build-manifest.json': continue
  z.write(path,Path(FOLDER)/rel)
fresh=ROOT/('build/qa-bigster-fresh' if args.branch=='bigster' else 'build/qa-modular-garage-fresh')
fresh.mkdir(parents=True,exist_ok=True)
with zipfile.ZipFile(archive) as z:
 assert z.testzip() is None
 z.extractall(fresh)
manifest.update(zip_sha256=hashlib.sha256(archive.read_bytes()).hexdigest(),zip_bytes=archive.stat().st_size,exe_bytes=(BUILD/'Leo Racer.exe').stat().st_size)
(DIST/f'BUILDINFO-{args.version}.json').write_text(json.dumps(manifest,indent=2)+'\n')
(ROOT/('docs/qa-bigster/build-manifest.json' if args.branch=='bigster' else 'docs/qa-modular-garage/build-manifest.json')).write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps(manifest,indent=2))
print('FRESH_TEST_PATH',fresh/FOLDER)
