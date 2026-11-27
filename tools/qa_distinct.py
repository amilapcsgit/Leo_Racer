"""Isolated, repeatable distinct_v2 checks. Never touches the player's profile."""
from pathlib import Path
import argparse, hashlib, json, os, subprocess, sys, time

ROOT = Path(__file__).resolve().parents[1]
QA = ROOT / 'build/distinct'
PYTHON = Path(sys.executable)
ENGINE = ROOT.parent.parent / 'tools/godot-net/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe'
ASSETS = ROOT / 'build/Release-2.3.2/GameAssets'
VEHICLES = ROOT.parent.parent / 't232/r232-complete/GameAssets/vehicles'

def prepare():
    folder = QA / 'baseline'
    folder.mkdir(parents=True, exist_ok=True)
    original = subprocess.check_output(['git', 'show', '0be45efe4bea797a7fd9b004f058789d982e9614:scripts/kart.gd'], cwd=ROOT).decode()
    physics = original.split('func _physics_process(dt: float) -> void:', 1)[1].split('\nfunc _process(', 1)[0]
    (folder / 'manual_controller.gd').write_text('extends LeoKart\nfunc _physics_process(dt: float) -> void:' + physics, encoding='utf-8')
    (folder / 'ai_controller.gd').write_text('extends LeoKart\nfunc _physics_process(dt: float) -> void:' + physics, encoding='utf-8')
    fingerprints = {}
    for key in ['content/vehicles/bigster', 'content/vehicles/duster']:
        for path in (ROOT/key).rglob('*'):
            if path.is_file():fingerprints[path.relative_to(ROOT).as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
    (QA / 'package-fingerprints.json').write_text(json.dumps(fingerprints, indent=2))

def run(label, script='tests/distinct_driving_test.gd', mode='features', render=False, compat=False, extra=(), timeout=1200, vehicles=None):
    QA.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    profile = QA/'profiles'/label
    profile.mkdir(parents=True, exist_ok=True)
    env.update(APPDATA=str(profile), LOCALAPPDATA=str(profile), DOTNET_ROOT=str(ROOT.parent.parent/'tools/dotnet'), LEO_ASSET_ROOT=str(ASSETS), VEHICLE_QA_OUTPUT=str(QA/label))
    env['PATH'] = env['DOTNET_ROOT'] + os.pathsep + env['PATH']
    cmd = [str(ENGINE), '--path', str(ROOT)]
    if not render:cmd += ['--headless', '--fixed-fps', '60']
    if compat:cmd += ['--rendering-method', 'gl_compatibility', '--rendering-driver', 'opengl3']
    if script:cmd += ['--script', 'res://'+script]
    selected_vehicles=vehicles or (ASSETS/'vehicles' if label.startswith('performance') else VEHICLES)
    cmd += ['--', '--drive-test', '--vehicles='+str(selected_vehicles), '--tracks='+str(ASSETS/'tracks'), '--distinct-mode='+mode, '--qa-output='+str(QA/label), *extra]
    started = time.monotonic()
    with (QA/(label+'.log')).open('w', encoding='utf-8') as log:
        process = subprocess.Popen(cmd, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
        (profile/'process-id.txt').write_text(str(process.pid),encoding='ascii')
        try:code=process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:process.kill();process.wait();code=-999
    text = (QA/(label+'.log')).read_text(encoding='utf-8', errors='replace')
    errors = [line for line in text.splitlines() if 'SCRIPT ERROR' in line or 'Parse Error' in line or 'Shader compilation failed' in line]
    result = dict(label=label, exit_code=code, seconds=round(time.monotonic()-started,2), errors=errors)
    print(json.dumps(result), flush=True)
    return code==0 and not errors

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('mode',choices=['prepare','features','races','pace','comparison','camera','performance']);parser.add_argument('--render',action='store_true');parser.add_argument('--compat',action='store_true');args=parser.parse_args()
    if args.mode=='prepare':prepare();sys.exit(0)
    label=args.mode+('-compatibility' if args.compat else '-forward')
    if args.mode=='camera':ok=run(label,'tests/vehicle_camera_test.gd',render=args.render,compat=args.compat)
    elif args.mode=='performance':ok=run(label,script=None,render=True,compat=args.compat,extra=['--track=kandy_lake','--track-check=performance','--vehicle=bigster'])
    else:ok=run(label,mode=args.mode,render=args.render,compat=args.compat)
    sys.exit(0 if ok else 2)
