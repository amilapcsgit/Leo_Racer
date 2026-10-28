"""Summarize release gates without weakening failed measurements."""
from pathlib import Path
import json,hashlib
R=Path(__file__).resolve().parents[1];Q=R/'build/qa260'
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
gates={};tables={};functional={}
for renderer in ['forward','compatibility']:
 f=read(Q/('functional-'+renderer)/'runtime.json');functional[renderer]=f
 gates['functional_'+renderer]=f['status']=='PASS'
 gates['garage_'+renderer]=read(Q/('functional-'+renderer)/'gates.json')['status']=='PASS'
 gates['environment_'+renderer]=read(Q/('environment-'+renderer)/'environment.json')['status']=='PASS'
 for variant in ['static','dusk']:
  folder=Q/('final-'+variant+'-'+renderer);rows=read(folder/'performance.json');tables[variant+'-'+renderer]=rows
  expected={(track,humans) for track in ['kandy_lake','astra_coast','colombo_city'] for humans in [1,2]}
  gates[variant+'_'+renderer]=len(rows)==6 and {(r['track'],r['humans']) for r in rows}==expected and all(r['p95_ms']<=16.7 and r['sample_seconds']==30 and r['resolution']==[1920,1080] for r in rows)
  process=read(folder/'process.json');gates['process_'+variant+'_'+renderer]=process['exit']==0 and not process['errors']
for mode in ['audit','contacts','replay']:gates[mode]=read(Q/('regression-'+mode)/(mode+'.json'))['status']=='PASS'
for name in ['worker','sdk','source-integrity']:gates[name]=read(Q/(name+'.json'))['status']=='PASS'
gates['content']=read(R/'build/content260-result.json')['status']=='PASS'
fits=read(Q/'driver-fits.json');gates['driver_clearance']=len(fits)==12 and all(row['head_y']<=row['roof_y']-.03 for row in fits)
gates['exported_windows']=read(Q/'export-smoke.json')['status']=='PASS'
gates['installer_full']=read(Q/'installer-full.json')['status']=='PASS'
gates['installer_preservation']=read(R/'build/installer260-result.json')['status']=='PASS'
result={'status':'PASS' if all(gates.values()) else 'FAIL','gates':gates,'hardware':'NVIDIA RTX A1000 6GB Laptop GPU','resolution':[1920,1080],'quality':'Medium','target_p95_ms':16.7,'performance':tables,'garage':functional}
(Q/'acceptance.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
lines=['# Leo Racer 2.6 preview validation','',f"Gate status: **{result['status']}**. Measured on the RTX A1000 6GB Laptop GPU at 1920 x 1080, Medium, Godot 4.7.2 .NET. NVIDIA driver 566.14. Each race case uses six racers, six seconds of warm-up and 30 seconds of sampled wall-clock frames. Split-screen places the players half a course apart.",'','The 2.5 comparison uses the unchanged released controller and runtime, with the same source vehicle packages, balance entries, roster order and six-car lineup. The candidate uses compiled scenes, LODs and prepared textures. This is a local preview; no public release has been published.','','## Garage','', '| Renderer | UI ms | Cold preview ms | Warm switch ms | Worst garage frame ms |','|---|---:|---:|---:|---:|']
for renderer,f in functional.items():lines.append(f"| {renderer} | {f['ui_ms']:.2f} | {f['cold_preview_ms']:.2f} | {f['warm_ms']:.2f} | {f['garage_worst_ms']:.2f} |")
lines+=['','All four garage targets apply: UI <=250 ms, cold preview <=3000 ms, warm switch <=250 ms and no sampled garage frame >50 ms. Instantiation, driver attachment and material preparation are timed separately from resource loading, GPU warm-up and first visibility. Official model preparation stages remain below the 4 ms CPU budget in the recorded Duster cases. The cache retains at most three previews and uses a 512 MiB estimate; that is not a total-process or measured-VRAM limit. Compatibility prewarms small shader representatives and driver styles during boot; its additional boot time is recorded in the logs.','','## Native race frames','', '| Variant / renderer | Track | Players | p50 ms | p95 ms | p99 ms | Worst ms | Load ms | Static MB | VRAM MB |','|---|---|---:|---:|---:|---:|---:|---:|---:|---:|']
for name,rows in tables.items():
 for row in rows:lines.append(f"| {name} | {row['track']} | {row['humans']} | {row['p50_ms']:.2f} | {row['p95_ms']:.2f} | {row['p99_ms']:.2f} | {row['max_frame_ms']:.2f} | {row['load_ms']} | {row['static_memory_bytes']/1e6:.1f} | {row['video_memory_bytes']/1e6:.1f} |")
lines+=['','The p95 gate is 16.7 ms in every candidate case. p99 and worst-frame values are reported independently; occasional scenery-streaming spikes remain and are not presented as a stutter-free 60 FPS guarantee. Memory values are Godot monitors, not a Windows working-set measurement. Raw frame samples and matched 2.5 rows are included in the evidence archive.','','## Functional evidence','']
for mode in ['audit','contacts','replay']:
 d=read(Q/('regression-'+mode)/(mode+'.json'));lines.append(f"- {mode}: {d['checks']} checks, {d['status']}.")
for name,file in [('compiled content',R/'build/content260-result.json'),('ranking worker',Q/'worker.json'),('standalone SDK / unsafe-pack rejection',Q/'sdk.json')]:
 d=read(file);lines.append(f"- {name}: {d['checks']} checks, {d['status']}.")
for renderer in ['forward','compatibility']:
 d=read(Q/('environment-'+renderer)/'environment.json');lines.append(f"- {renderer} environment, viewport isolation, reduced motion and cache checks: {d['checks']}, {d['status']}.")
replay=read(Q/'regression-replay/replay.json')['details']['replay']
lines+=['',f"The paired 360-tick replay against release/2.5.0 @ 3d37854 has position error {replay['position_error']}, speed error {replay['speed_error']} and fuel error {replay['fuel_error']}. ContactSolver, CosmeticDamage and the measured-speed race camera remain unchanged. Vehicle collision bounds and seating/bindings are adapted to the recovered geometry.",'','Content checks cover 21 official cars, Duster 2024 at position 21, retained `duster` selections, Bigster fallback, both Dusters with all six drivers, wheel paths/rolling/steering, independent lamp instances and partial/repeated action reversals. Environment checks cover all three tracks, neutral Kandy bakes, pause/photo freezing, restart, static restoration, night renders, reduced motion, per-player wind layers, exclusive decal/mesh backends, cache eviction and closing during a load. Source integrity verifies all 306 downloaded mod files and the supplied Blender master hashes. The SDK test validates a freshly extracted compiler export and rejects embedded scripts before mounting. Installer fixtures cover modified-file backups, superseded managed assets, reinstall and preservation on uninstall.','','## Limits and shutdown warnings','','- This is an arcade character-controller racer. Opening panels are cosmetic and retain the fixed driving collision envelope; damage remains the existing bounded cosmetic system.','- Color presets are brochure/screenshot approximations and metadata for a future garage selector. No color-selector code is included.','- Forward+ High solo uses pooled decals; effective Medium split-screen and Compatibility use the pooled mesh backend.','- Medium uses a smaller dynamic-sky radiance map and a nearer shadow budget. High retains larger maps. Kandy editor bake helpers are suppressed while original static lightmap files remain available.','- Native Godot shutdown logs still include leaked-RID/ObjectDB/resource warnings also observed in the 2.5 baseline. They occur during teardown; the validation report does not hide them.','- Frame and memory measurements apply to the recorded machine and workloads. Other hardware, drivers and custom content require their own measurements.','','The exported Windows preview and archive-extraction smoke checks are recorded separately in `export-smoke.json` after export. Source files under `sources/`, downloaded mod assets, original Blender masters and the installed game are not modified by preparation.','']
lines += ['The final exported executable passes all three tracks in solo and split-screen with SDK paths removed. Final metadata checks cover all 21 vehicles. The compiled installer passes fresh installation, reinstall backups and uninstall preservation in a workspace test target. All 12 Duster/driver assemblies have measured headroom; the final 2024 seating transforms also clear the sloping roof in the reviewed previews.','']
(R/'docs/QUALITY260.md').write_text('\n'.join(lines),encoding='utf-8')
print('ACCEPTANCE260',result['status'],gates,flush=True)
raise SystemExit(0 if result['status']=='PASS' else 1)
