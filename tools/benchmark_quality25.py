"""Matched native-executable benchmarks; no SDK, one renderer process at a time."""
from pathlib import Path
import argparse, json, os, subprocess, time, shutil
import city_packs
from quality25 import ROOT,QA,RC,SELECTED,dump,sha
def instrument(folder,baseline):
    target=QA/'benchmark-copies'/('rc' if baseline else 'candidate');target.mkdir(parents=True,exist_ok=True)
    for name in ['LeoRacer.exe','LeoRacer.console.exe','LeoRacer.pck','data_LeoRacer_windows_x86_64','GameAssets']:
        source=folder/name
        if source.is_dir():shutil.copytree(source,target/name,dirs_exist_ok=True)
        else:shutil.copy2(source,target/name)
    engine,entries=city_packs.read_pack(target/'LeoRacer.pck');before=entries.copy()
    key='scripts/content/track_check.gd'
    entries.pop(key+'.remap',None);entries[key]=(ROOT/'tests/quality25_benchmark.gd').read_bytes()
    city_packs.write_pack(target/'LeoRacer.pck',engine,entries)
    changed=[key for key in set(before)|set(entries) if before.get(key)!=entries.get(key)]
    assert set(changed)<= {'scripts/content/track_check.gd','scripts/content/track_check.gd.remap'}
    dump(target/'instrumentation.json',{'source_core_sha256':sha(folder/'LeoRacer.pck'),'instrumented_core_sha256':sha(target/'LeoRacer.pck'),'changed_diagnostic_resources':changed,'gameplay_resources_unchanged':True})
    return target
def run(folder,compat,baseline,extras=False):
    original=folder;folder=instrument(folder,baseline)
    label=('baseline' if baseline else 'candidate')+('-compatibility' if compat else '-forward')+('-extras' if extras else '')
    out=QA/'performance'/label;out.mkdir(parents=True,exist_ok=True)
    assert not (out/'performance.json').exists(),'Archive the old measurement before repeating it'
    profile=out/'profile';profile.mkdir(exist_ok=True)
    env=os.environ.copy();env.update(APPDATA=str(profile),LOCALAPPDATA=str(profile),DOTNET_ROOT=str(profile/'no-sdk'))
    env['PATH']=os.pathsep.join(p for p in env['PATH'].split(os.pathsep) if 'dotnet' not in p.lower())
    cmd=[str(folder/'LeoRacer.console.exe')]
    if compat:cmd+=['--rendering-method','gl_compatibility','--rendering-driver','opengl3']
    cmd+=['--','--drive-test','--track=kandy_lake','--track-check=performance','--qa-output='+str(out),'--vehicles='+str(SELECTED)]
    if baseline:cmd+=['--baseline']
    if extras:cmd+=['--extra-baselines']
    start=time.monotonic()
    with (out/'process.log').open('w',encoding='utf-8') as log:
        result=subprocess.run(cmd,cwd=folder,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=900,creationflags=0x08000000)
    text=(out/'process.log').read_text(encoding='utf-8',errors='replace')
    errors=[line for line in text.splitlines() if any(word in line for word in ['SCRIPT ERROR','Parse Error','Shader compilation failed','Parameter "material" is null'])]
    dump(out/'process.json',{'exit':result.returncode,'errors':errors,'seconds':time.monotonic()-start,'core_sha256':sha(original/'LeoRacer.pck'),'instrumented_core_sha256':sha(folder/'LeoRacer.pck')})
    assert result.returncode==0 and not errors,(label,errors)
    print('QUALITY25_BENCHMARK_COMPLETE',label,flush=True)
def summarize(folder):
    measurements={}
    for label in ['baseline-forward','baseline-compatibility','candidate-forward','candidate-compatibility']:
        measurements[label]=json.loads((QA/'performance'/label/'performance.json').read_text())
    for label in ['baseline-forward','baseline-compatibility']:
        extra=QA/'performance'/(label+'-extras')/'performance.json'
        if extra.exists():measurements[label]+=json.loads(extra.read_text())
    expected={(track,humans) for track in ['astra_coast','colombo_city','kandy_lake'] for humans in [1,2]}
    for label,rows in measurements.items():
        assert len(rows)==6 and {(row['track'],row['humans']) for row in rows}==expected,('Incomplete benchmark matrix',label)
    gates=[]
    for label in ['candidate-forward','candidate-compatibility']:
        for row in measurements[label]:
            gates.append({'gate':label+'/'+row['track']+'/'+str(row['humans'])+'/60fps','pass':row['p95_ms']<=16.7,'p95_ms':row['p95_ms']})
            if label=='candidate-compatibility':
                old=next(x for x in measurements['baseline-compatibility'] if x['humans']==row['humans'] and x['track']==row['track'])
                gates.append({'gate':'Compatibility versus matched RC/'+row['track']+'/'+str(row['humans']),'pass':row['p95_ms']<=old['p95_ms']*1.1,'baseline':old['p95_ms'],'candidate':row['p95_ms']})
    report={'status':'PASS' if all(g['pass'] for g in gates) else 'FAIL','gates':gates,'measurements':measurements,'candidate_core_sha256':sha(folder/'LeoRacer.pck'),'rc_core_sha256':sha(RC/'LeoRacer.pck')}
    dump(QA/'performance-acceptance.json',report);print(json.dumps(report),flush=True)
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('mode',choices=['baseline','baseline-extras','candidate','summary']);p.add_argument('--folder',type=Path,default=ROOT/'build/Quality25-M1');a=p.parse_args()
    if a.mode=='summary':summarize(a.folder)
    else:
        for compat in [False,True]:run(RC if a.mode.startswith('baseline') else a.folder,compat,a.mode.startswith('baseline'),a.mode=='baseline-extras')
