"""Package the complete .NET game and unpack it to a fresh verification path."""
from pathlib import Path
import hashlib, json, shutil, zipfile
ROOT=Path(__file__).resolve().parent.parent
BUILD=ROOT/'build/SriLanka'
DIST=ROOT/'dist'
DIST.mkdir(exist_ok=True)
assert (BUILD/'Leo Racer.exe').is_file()
assert (BUILD/'data_LeoRacer_windows_x86_64/LeoRacer.dll').is_file()
shutil.copytree(ROOT/'licenses',BUILD/'licenses',dirs_exist_ok=True)
(BUILD/'Play Leo Racer.cmd').write_text('@echo off\nstart "" "%~dp0Leo Racer.exe"\n')
(BUILD/'Play Compatibility Mode.cmd').write_text('@echo off\nstart "" "%~dp0Leo Racer.exe" --rendering-method gl_compatibility --rendering-driver opengl3\n')
(BUILD/'README.txt').write_text('''LEO RACER - SRI LANKA 2026 / v1.3.0

Extract this entire folder, then run Play Leo Racer.cmd or Leo Racer.exe.
Keep data_LeoRacer_windows_x86_64 and libterrain.windows.release.x86_64.dll
beside the executable. No editor or .NET SDK installation is needed.

W/S or arrows: accelerate, brake/reverse. A/D or arrows: steer.
SPACE: drift. SHIFT: nitro. R: recover. ESC: pause. F8: hide HUD.
Reduced Motion is available in Settings. Controller input is supported.

Use Play Compatibility Mode.cmd if Vulkan is unavailable.
Three laps, six racers, four drivers, four independently selectable karts.
Existing preferences and best times are retained.

Source and setup: https://github.com/amilapcsgit/Leo_Racer/tree/srilanka
Component notices are in licenses/. See source docs/SRILANKA_VALIDATION.md
for verification results and engine cleanup-warning notes.
''')
exe_hash=hashlib.sha256((BUILD/'Leo Racer.exe').read_bytes()).hexdigest()
manifest={'version':'1.3.0','branch':'srilanka','godot':'4.7.2 .NET','architecture':'Windows x86_64','exe_sha256':exe_hash,'runtime_bundled':True,'terrain_library_bundled':True}
(BUILD/'build-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
archive=DIST/'LeoRacer-Windows-v1.3-SriLanka.zip'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for path in sorted(BUILD.rglob('*')):
  if not path.is_file(): continue
  rel=path.relative_to(BUILD)
  if rel.parent==Path('.') and path.suffix in ['.log','.png','.json'] and path.name!='build-manifest.json': continue
  z.write(path,Path('Leo Racer Sri Lanka')/rel)
fresh=ROOT/'build/qa-srilanka-fresh'
fresh.mkdir(parents=True,exist_ok=True)
with zipfile.ZipFile(archive) as z:
 assert z.testzip() is None
 z.extractall(fresh)
manifest.update(zip_sha256=hashlib.sha256(archive.read_bytes()).hexdigest(),zip_bytes=archive.stat().st_size,exe_bytes=(BUILD/'Leo Racer.exe').stat().st_size)
(ROOT/'docs/qa-srilanka/build-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps(manifest,indent=2))
print('FRESH_TEST_PATH',fresh/'Leo Racer Sri Lanka')
