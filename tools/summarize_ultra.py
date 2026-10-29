"""Collect measured release evidence without turning performance misses into PASS."""
import json
from pathlib import Path
from stage_ultra_content import ROOT

def summarize():
    qa=ROOT/'build/qa270';rows=[];processes=[]
    for path in sorted(qa.glob('performance/*/performance.json')):
        for row in json.loads(path.read_text(encoding='utf-8')):
            rows.append(dict(case=path.parent.name,**row))
    for path in sorted(qa.glob('*/process.json')):
        report=json.loads(path.read_text(encoding='utf-8'));report['case']=path.parent.name;processes.append(report)
    result={'native_processes':processes,'performance_rows':rows,'race_p95_goal_ms':16.7,'race_p95_misses':[row for row in rows if row['p95_ms']>16.7]}
    (qa/'summary.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    lines=['# Measured native performance','','Medium quality, 1920×1080, six racers; 6-second warmup and 30-second samples. Separate isolated 2.6 and 2.7 diagnostic copies use the same probe.','','| Build / renderer / lighting | Track | Humans | p50 ms | p95 ms | p99 ms | 16.7 ms p95 goal |','|---|---|---:|---:|---:|---:|---|']
    for row in rows:
        lines.append('| '+row['case']+' | '+row['track']+' | '+str(row['humans'])+' | '+f"{row['p50_ms']:.2f} | {row['p95_ms']:.2f} | {row['p99_ms']:.2f}"+' | '+('MISS' if row['p95_ms']>16.7 else 'PASS')+' |')
    (qa/'PERFORMANCE.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    print('Performance rows',len(rows),'p95 misses',len(result['race_p95_misses']))

if __name__=='__main__':summarize()
