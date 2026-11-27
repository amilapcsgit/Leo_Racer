"""Summarize retained native matrix evidence without mixing source and native timings."""
import argparse
import json
import statistics
from pathlib import Path
from stage_ultra_content import ROOT


def read_phase(phase):
    directory=ROOT/'build/qa280'/('profile-'+phase)
    cases={}
    for renderer in ['forward','compatibility']:
        report_path=directory/renderer/'profile.json'
        if not report_path.exists():
            continue
        report=json.loads(report_path.read_text(encoding='utf-8'))
        for row in report['cases']:
            if not row['warmup']:
                cases.setdefault((renderer,row['track'],row['players']),[]).append(row)
    return cases


def memory_peaks(phase):
    directory=ROOT/'build/qa280'/('profile-'+phase)
    path=directory/'memory.jsonl'
    if not path.exists():
        return {}
    samples=[json.loads(line) for line in path.read_text(encoding='utf-8-sig').splitlines() if line.strip()]
    pids=list(dict.fromkeys(row['pid'] for row in samples))
    peaks={}
    for index,renderer in enumerate(['forward','compatibility']):
        report_path=directory/renderer/'profile.json'
        if not report_path.exists(): continue
        report=json.loads(report_path.read_text(encoding='utf-8'))
        pid=report.get('os_process_id')
        # The frozen baseline has no PID field and only benchmark processes were observed.
        if pid is None and phase=='native-before-valid' and index<len(pids): pid=pids[index]
        values=[row['peak_working_set_bytes'] for row in samples if row['pid']==pid]
        if values: peaks[renderer]=max(values)/1024**3
    return peaks


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--before',default='native-before-valid')
    parser.add_argument('--after',default='native-after')
    parser.add_argument('--output',type=Path,default=ROOT/'docs/CORE280_PERFORMANCE.md')
    args=parser.parse_args()
    before,after=read_phase(args.before),read_phase(args.after)
    lines=['# Leo Racer 2.8 moving-race performance','',
           'Native QA candidates, RTX A1000 6 GB Laptop GPU, 1920×1080 output, 1× real time, Auto environment detail, highest graphics preset, Chase camera, Bigster P1/Duster P2, six racers. One complete one-lap warm-up followed by three measured one-lap races per track/player/renderer combination. Physics, HUD and audio remain active. VSync is disabled and FPS is uncapped.','',
           'Each range below contains the minimum and maximum per-race p95 across the three measured races; the target passes only when all three complete and their worst p95 is at most 16.67 ms. Loading is excluded from frame samples and retained separately in raw JSON.','',
           '| Renderer | Track | Players | Before p95 ms | After p95 ms | After p50 / p99 median ms | Before / after longest frame ms | Target |',
           '|---|---|---:|---:|---:|---:|---:|---|']
    summary=[]
    for renderer in ['forward','compatibility']:
        for track in ['astra_coast','colombo_city','kandy_lake','wennappuwa']:
            for players in [1,2]:
                key=(renderer,track,players)
                old,new=before.get(key,[]),after.get(key,[])
                valid=lambda rows: len(rows)==3 and all(row['complete'] for row in rows)
                def spread(rows):
                    return f"{min(r['p95_ms'] for r in rows):.2f}–{max(r['p95_ms'] for r in rows):.2f}" if valid(rows) else 'incomplete'
                goal='PASS' if valid(new) and max(r['p95_ms'] for r in new)<=16.67 else ('MISS' if valid(new) else 'INCOMPLETE')
                middle=f"{statistics.median(r['p50_ms'] for r in new):.2f} / {statistics.median(r['p99_ms'] for r in new):.2f}" if valid(new) else '—'
                def stall(rows):
                    return f"{max(r['peak_ms'] for r in rows):.2f}" if valid(rows) else 'incomplete'
                lines.append(f'| {renderer} | {track} | {players} | {spread(old)} | {spread(new)} | {middle} | {stall(old)} / {stall(new)} | {goal} |')
                summary.append({'renderer':renderer,'track':track,'players':players,'before':old,'after':new,'target':goal})
    lines += ['', '## Loading, resolution and Auto detail', '',
              'Race-start loading is the median of the three measured starts in milliseconds, separate from racing. Tier percentages count sampled frames (0=Low, 1=Medium, 2=High). View dimensions are actual render viewports; 3D scale is reported separately.', '',
              '| Renderer / track / players | Before / after start ms | After views and 3D scale | Before / after tier frame percentages |',
              '|---|---:|---|---|']
    def tiers(rows):
        counts={}
        for row in rows:
            for key,value in row['tier_frames'].items(): counts[key]=counts.get(key,0)+value
        total=sum(counts.values())
        return ', '.join(f'{key}:{100*value/total:.0f}%' for key,value in sorted(counts.items())) if total else 'unavailable'
    for row in summary:
        old,new=row['before'],row['after']
        load=lambda rows: f"{statistics.median(r['loading_ms'] for r in rows):.0f}" if len(rows)==3 else 'incomplete'
        views=sorted({f"{v['size'][0]}×{v['size'][1]} at {v['scale_3d']:.2f}×" for r in new for v in r['views']})
        lines.append(f"| {row['renderer']} / {row['track']} / {row['players']} | {load(old)} / {load(new)} | {', '.join(views) or 'incomplete'} | {tiers(old)} / {tiers(new)} |")
    old_memory,new_memory=memory_peaks(args.before),memory_peaks(args.after)
    lines += ['', '## Observed process memory','',
              '| Renderer | Before peak working set GiB | After peak working set GiB |',
              '|---|---:|---:|']
    for renderer in ['forward','compatibility']:
        old=f"{old_memory[renderer]:.2f}" if renderer in old_memory else 'unavailable'
        new=f"{new_memory[renderer]:.2f}" if renderer in new_memory else 'unavailable'
        lines.append(f'| {renderer} | {old} | {new} |')
    lines += ['', '## Evidence and interpretation','',
        f'- Raw before: `build/qa280/profile-{args.before}/`; raw after: `build/qa280/profile-{args.after}/`. Each contains per-frame samples, per-race load/frame/tier/view data, screenshots and process logs.',
        '- Native static-memory monitors can report zero in release builds. Use the separate `memory.jsonl` OS working-set samples; console-launcher memory is explicitly labeled and is not game memory. Working-set sampling is every two seconds and includes loading.',
        '- The frozen original baseline has cumulative per-track tile counters and lifetime tile maxima. Treat those as cumulative, derive count/time deltas between adjacent rows, and do not describe them as per-race peaks. Candidate probes reset tile metrics per race.',
        '- A cooperative tile slice can exceed its target during an atomic operation. Compare recorded slice peaks and the full frame distribution; do not infer a hard bound.',
        '- Source/editor timing is a separate experiment and is not used for native improvement percentages.',
        '- Budget misses remain explicit. No larger shadow/mirror/content cuts or release publication are part of this change.','',
        '## Reproduce','',
        'Use the pinned Godot/.NET toolchain and verified content locks. Prepare distinct frozen candidates with `tools/prepare_core280_candidate.py LABEL`, then run `tools/profile_core280.py --phase PHASE --export ABSOLUTE_CANDIDATE_PATH`. Run GPU matrices serially. Run correctness checks with `tools/run_core280_validation.py`; `--benchmark` performs the candidate matrix only after source/native checks pass.','']
    args.output.write_text('\n'.join(lines),encoding='utf-8')
    target=ROOT/'build/qa280/core280-summary.json'
    target.write_text(json.dumps(summary,indent=2),encoding='utf-8')
    print(json.dumps({'cases':len(summary),'pass':sum(x['target']=='PASS' for x in summary),'miss':sum(x['target']=='MISS' for x in summary),'incomplete':sum(x['target']=='INCOMPLETE' for x in summary)}))


if __name__=='__main__': main()
