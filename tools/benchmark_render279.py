"""Run the same renderer diagnostic in isolated copies of native releases."""
from pathlib import Path
import argparse
import json
import os
import re
import shutil
import subprocess
import time
import city_packs
from stage_ultra_content import ROOT, sha

ADAPTER = '''extends Node
var root: Window:
 get:return get_tree().root
var process_frame: Signal:
 get:return get_tree().process_frame
var physics_frame: Signal:
 get:return get_tree().physics_frame
func _ready() -> void:_initialize()
func quit(code: int=0) -> void:get_tree().quit(code)
func create_timer(seconds: float) -> SceneTreeTimer:return get_tree().create_timer(seconds)
'''

def run(source, label, compatibility=False, probe='split', performance=False):
    source = Path(source).resolve()
    if not re.fullmatch(r'[a-zA-Z0-9_-]+', label):
        raise ValueError('Use a simple artifact label')
    out = ROOT / 'build/qa279' / label
    target = out / 'native-copy'
    if target.exists():
        raise RuntimeError('Preserve completed native probe: ' + str(target))
    out.mkdir(parents=True, exist_ok=True)

    def link(src, dst):
        try:
            os.link(src, dst)
        except OSError:
            shutil.copy2(src, dst)
        return str(dst)

    shutil.copytree(source, target, copy_function=link,
                    ignore=shutil.ignore_patterns('LeoRacer.pck', 'QA', '*.log'))
    engine, entries = city_packs.read_pack(source / 'LeoRacer.pck')
    script_name = 'render_split279_probe' if probe == 'split' else 'render_world279_test'
    script = (ROOT / 'tests' / (script_name + '.gd')).read_text(encoding='utf-8')
    script = script.replace('extends SceneTree', ADAPTER, 1)
    script = script.replace('.prepare(self,', '.prepare(get_tree(),')
    key = 'tests/native270/visual.gd'
    entries.pop(key + '.remap', None)
    entries[key] = script.expandtabs(4).encode('utf-8')
    city_packs.write_pack(target / 'LeoRacer.pck', engine, entries)
    profile = out / 'profile'
    profile.mkdir(exist_ok=True)
    env = dict(os.environ, APPDATA=str(profile), LOCALAPPDATA=str(profile),
               DOTNET_ROOT=str(profile / 'no-sdk'), LEO_ASSET_ROOT=str(target / 'GameAssets'))
    env['PATH'] = os.pathsep.join(p for p in env.get('PATH', '').split(os.pathsep)
                                  if not any(word in p.lower() for word in ['dotnet', '.tools']))
    command = [str(target / 'LeoRacer.console.exe'), '--position', '-3200,-3200']
    if compatibility:
        command += ['--rendering-method', 'gl_compatibility', '--rendering-driver', 'opengl3']
    command += ['--', '--drive-test', '--ultra-check=visual', '--track=kandy_lake',
                '--vehicles=' + str(target / 'GameAssets/vehicles'),
                '--tracks=' + str(target / 'GameAssets/tracks'), '--qa-output=' + str(out)]
    if performance:
        command.append('--performance')
    began = time.monotonic()
    print('NATIVE_RENDER279_START', label, flush=True)
    with (out / 'process.log').open('w', encoding='utf-8') as log:
        process = subprocess.Popen(command, cwd=target, env=env, stdout=log,
                                   stderr=subprocess.STDOUT,
                                   creationflags=subprocess.CREATE_NO_WINDOW)
        while process.poll() is None:
            time.sleep(.5)
            text = (out / 'process.log').read_text(encoding='utf-8', errors='replace')
            if 'Parse Error' in text or 'SCRIPT ERROR' in text or time.monotonic() - began > 600:
                process.kill()
                break
        code = process.wait()
    text = (out / 'process.log').read_text(encoding='utf-8', errors='replace')
    errors = [line for line in text.splitlines()
              if any(term in line for term in ['SCRIPT ERROR', 'ERROR:', 'Shader compilation failed'])]
    warnings = [line for line in text.splitlines()
                if any(term in line for term in ['leaked', 'resources still in use', 'Pages in use'])]
    report_name = 'split-probe279.json' if probe == 'split' else 'render-world279.json'
    report_file = out / report_name
    report = json.loads(report_file.read_text()) if report_file.exists() else {}
    wrapper = dict(functional_status='PASS' if code == 0 and not errors and report else 'FAIL',
                   exit_code=code, seconds=round(time.monotonic() - began, 2),
                   source_export=str(source), source_core_sha256=sha(source / 'LeoRacer.pck'),
                   probe=probe, renderer='compatibility' if compatibility else 'forward_plus',
                   errors=errors, shutdown_warnings=warnings)
    (out / 'process.json').write_text(json.dumps(wrapper, indent=2), encoding='utf-8')
    print('NATIVE_RENDER279_COMPLETE', label, json.dumps(wrapper), flush=True)
    if report:
        print('NATIVE_RENDER279_RESULTS', label, json.dumps(report), flush=True)
    return wrapper['functional_status'] == 'PASS'

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--export', required=True, type=Path)
    parser.add_argument('--label', required=True)
    parser.add_argument('--compatibility', action='store_true')
    parser.add_argument('--probe', choices=['split', 'world'], default='split')
    parser.add_argument('--performance', action='store_true')
    args = parser.parse_args()
    raise SystemExit(0 if run(args.export, args.label, args.compatibility, args.probe, args.performance) else 1)
