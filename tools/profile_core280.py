"""Run isolated, real-time 1080p moving-race evidence; never run GPU cases in parallel."""
from pathlib import Path
import argparse
import ctypes
import json
import os
import re
import subprocess
import time
from stage_ultra_content import ROOT


def run(renderer, phase, track=None, players=None, repeats=3, export=None, grass="current"):
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.-]*', phase) or phase in {'.','..'}:
        raise ValueError('Use a simple phase label, without path separators')
    if export:
        export = Path(export).resolve()
    out = ROOT / 'build' / 'qa280' / ('profile-' + phase) / renderer
    if track:
        out = out / (track + '-' + str(players or 'both') + 'p')
    out.mkdir(parents=True, exist_ok=True)
    if (out / 'process.log').exists():
        raise RuntimeError('Preserve existing measurement logs; choose a new phase: ' + str(out))
    profile = out / 'profile'
    profile.mkdir(exist_ok=True)
    env = os.environ.copy()
    env.update(APPDATA=str(profile), LOCALAPPDATA=str(profile))
    assets = Path(export) / 'GameAssets' if export else ROOT / 'build/content-baseline/GameAssets'
    env['LEO_ASSET_ROOT'] = str(assets)
    if export:
        command = [str(Path(export) / 'LeoRacer.console.exe')]
    else:
        engine = ROOT / '.tools/godot/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe'
        if not engine.exists():
            engine = ROOT.parent.parent / 'tools/godot-net/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe'
        sdk = ROOT / '.tools/dotnet'
        if not sdk.exists():
            sdk = ROOT.parent.parent / 'tools/dotnet'
        env['DOTNET_ROOT'] = str(sdk)
        env['PATH'] = str(sdk) + os.pathsep + env['PATH']
        command = [str(engine), '--path', str(ROOT), '--script', 'res://tests/core280_profile.gd']
    command += ['--position', '0,0', '--resolution', '1920x1080']
    if renderer == 'compatibility':
        command += ['--rendering-method', 'gl_compatibility', '--rendering-driver', 'opengl3']
    command += ['--', '--drive-test', '--qa-output=' + str(out), '--qa-repeats=' + str(repeats), '--qa-grass=' + grass,
                '--vehicles=' + str(assets / 'vehicles'), '--tracks=' + str(assets / 'tracks')]
    if export:
        command += ['--ultra-check=core280_profile']
    if track:
        command += ['--qa-track=' + track]
    if players:
        command += ['--qa-players=' + str(players)]
    started = time.monotonic()
    peak_working_set = 0
    class MemoryCounters(ctypes.Structure):
        _fields_ = [('cb', ctypes.c_ulong), ('PageFaultCount', ctypes.c_ulong)] + [(name, ctypes.c_size_t) for name in
            ['PeakWorkingSetSize', 'WorkingSetSize', 'QuotaPeakPagedPoolUsage', 'QuotaPagedPoolUsage',
             'QuotaPeakNonPagedPoolUsage', 'QuotaNonPagedPoolUsage', 'PagefileUsage', 'PeakPagefileUsage']]
    game_handle = None
    game_pid = None
    if os.name == 'nt':
        kernel = ctypes.windll.kernel32
        kernel.OpenProcess.argtypes = [ctypes.c_uint32, ctypes.c_int, ctypes.c_uint32]
        kernel.OpenProcess.restype = ctypes.c_void_p
        kernel.CloseHandle.argtypes = [ctypes.c_void_p]
    with (out / 'process.log').open('w', encoding='utf-8') as log:
        process = subprocess.Popen(command, cwd=Path(export) if export else ROOT, env=env,
                                   stdout=log, stderr=subprocess.STDOUT,
                                   creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
        while process.poll() is None:
            time.sleep(2)
            text = (out / 'process.log').read_text(encoding='utf-8', errors='replace')
            if os.name == 'nt':
                if game_handle is None:
                    match = re.search(r'^CORE280_GAME_PID (\d+)', text, re.MULTILINE)
                    if match:
                        game_pid = int(match.group(1))
                        game_handle = kernel.OpenProcess(0x0410, False, game_pid)
                counters = MemoryCounters()
                counters.cb = ctypes.sizeof(counters)
                handle = game_handle or int(process._handle)
                if ctypes.windll.psapi.GetProcessMemoryInfo(ctypes.c_void_p(handle), ctypes.byref(counters), counters.cb):
                    if game_handle:
                        memory_row = {'pid': game_pid, 'working_set_bytes': counters.WorkingSetSize,
                                      'peak_working_set_bytes': counters.PeakWorkingSetSize}
                        matrix = ROOT / 'build' / 'qa280' / ('profile-' + phase)
                        with (matrix / 'memory.jsonl').open('a', encoding='utf-8') as memory:
                            memory.write(json.dumps(memory_row) + chr(10))
                    else:
                        peak_working_set = max(peak_working_set, counters.PeakWorkingSetSize)
            if any(term in text for term in ['SCRIPT ERROR', 'Parse Error', 'Shader compilation failed']) or time.monotonic()-started > 14400:
                process.kill()
                break
        code = process.wait()
        if game_handle:
            kernel.CloseHandle(game_handle)
    text = (out / 'process.log').read_text(encoding='utf-8', errors='replace')
    texture_shutdown = re.compile(r"ERROR: (?:Texture with GL ID of \d+: leaked \d+ bytes\.|\d+ RID allocations of type 'PN13RendererDummy14TextureStorage12DummyTextureE' were leaked at exit\.)")
    errors = [line for line in text.splitlines() if line.startswith('ERROR:') and not texture_shutdown.fullmatch(line)]
    result = {'exit_code': code, 'seconds': round(time.monotonic()-started, 2), 'command': command,
              'launcher_peak_working_set_bytes': peak_working_set,
              'runtime_errors': list(dict.fromkeys(errors)), 'runtime_error_count':len(errors),
              'shutdown_warnings': [line for line in text.splitlines() if 'leaked' in line or 'resources still in use' in line],
              'status': 'PASS' if code == 0 and not errors and 'CORE280_PROFILE_DONE' in text and '"status":"FAIL"' not in text else 'FAIL'}
    (out / 'process.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(json.dumps(result), flush=True)
    if result['status'] != 'PASS':
        print('\n'.join(text.splitlines()[-25:]), flush=True)
    return result['status'] == 'PASS'


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--phase', required=True)
    parser.add_argument('--renderer', choices=['forward', 'compatibility', 'both'], default='both')
    parser.add_argument('--track', choices=['astra_coast', 'colombo_city', 'kandy_lake', 'wennappuwa'])
    parser.add_argument('--players', type=int, choices=[1, 2])
    parser.add_argument('--repeats', type=int, default=3)
    parser.add_argument('--export', type=Path)
    parser.add_argument('--grass', choices=['current','off','sparse','field'], default='current')
    args = parser.parse_args()
    renderers = ['forward', 'compatibility'] if args.renderer == 'both' else [args.renderer]
    ok = True
    for renderer in renderers:
        if not run(renderer, args.phase, args.track, args.players, args.repeats, args.export, args.grass):
            ok = False
    raise SystemExit(0 if ok else 1)
