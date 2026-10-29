"""Reproducible 2.7 assembly and ownership-preserving Windows installer."""
from pathlib import Path
import argparse, json, os, shutil, subprocess, zipfile
import city_packs
from stage_ultra_content import ROOT, sha
BASE=ROOT/'build/Release-2.7.0-Ultra'
OUT=ROOT/'dist/release-2.7.0'
QA=ROOT/'build/qa270'
def files(root):return sorted(p for p in root.rglob('*') if p.is_file() and not p.name.endswith('.log'))
def dump(path,value):path.write_text(json.dumps(value,indent=2)+'\n',encoding='utf-8')
def inject_checks(entries):
    # Release templates intentionally ignore --script. Opt-in bootstrap probes
    # adapt the same SceneTree tests to Nodes, without a second test implementation.
    mapping={'finish':'ultra_finish_test','core':'ultra_core_test','visual':'ultra_visual_test','previews':'ultra_preview_test','physics':'ultra_physics_test','garage':'release260_runtime_test','contacts':'release260_collision_test','audit':'release260_collision_test','impact':'lighting_world_test'}
    adapter='''extends Node
var root: Window:
 get:return get_tree().root
var process_frame: Signal:
 get:return get_tree().process_frame
var physics_frame: Signal:
 get:return get_tree().physics_frame
func _ready() -> void:_initialize()
func quit(code: int=0) -> void:get_tree().quit(code)
func create_timer(seconds: float,always: bool=true,physics: bool=false,ignore_scale: bool=false) -> SceneTreeTimer:return get_tree().create_timer(seconds,always,physics,ignore_scale)
'''
    for name,source in mapping.items():
        script=(ROOT/'tests'/ (source+'.gd')).read_text(encoding='utf-8')
        script=script.replace('extends SceneTree',adapter,1).replace(',self)',',get_tree())').replace('func _process(dt: float) -> bool:','func _process(dt: float) -> void:').replace('return false','return')
        entries['tests/native270/'+name+'.gd']=script.expandtabs(4).encode('utf-8')
    key='scripts/content/bootstrap.gd';entries.pop(key+'.remap',None);entries[key]=(ROOT/key).read_bytes()
def stage():
    if (BASE/'GameAssets/catalog.json').exists():raise RuntimeError('Already staged; preserve this candidate')
    _,exported=city_packs.read_pack(BASE/'LeoRacer.pck')
    if not exported.get('project.binary',b'').startswith(b'ECFG'):raise RuntimeError('Exported project settings are missing or corrupt')
    city_packs.split(BASE,True)
    source=ROOT/'build/content-baseline/GameAssets'
    for name in ['vehicles','tracks','environments','licenses']:
        shutil.copytree(source/name,BASE/'GameAssets'/name,dirs_exist_ok=True)
    catalog=json.loads((BASE/'GameAssets/catalog.json').read_text(encoding='utf-8'))
    catalog.update(vehicle_api=2,core={'min':'2.7.0','max_major':2})
    derivative=BASE/'GameAssets/ultra/bigster-trunk.pck'
    derivative.parent.mkdir(exist_ok=True)
    shutil.copy2(ROOT/'content/ultra/bigster-trunk.pck',derivative)
    catalog['packs'].append({'id':'ultra/bigster-trunk','file':'ultra/bigster-trunk.pck','sha256':sha(derivative),'bytes':derivative.stat().st_size})
    neutral=BASE/'GameAssets/environments/dusk-neutral.pck'
    catalog['packs'].append({'id':'environments/dusk-neutral','file':'environments/dusk-neutral.pck','sha256':sha(neutral),'bytes':neutral.stat().st_size})
    dump(BASE/'GameAssets/catalog.json',catalog)
    # Published track packs retain their source hashes and existing record identity.
    engine,entries=city_packs.read_pack(BASE/'LeoRacer.pck')
    entries['assets/config/official-track-content.json']=(ROOT/'assets/config/official-track-content.json').read_bytes()
    for test in ['ultra_core_test','ultra_visual_test','ultra_preview_test','ultra_physics_test','release260_runtime_test','release260_collision_test','lighting_world_test']:
        entries['tests/'+test+'.gd']=(ROOT/'tests'/ (test+'.gd')).read_bytes()
    inject_checks(entries)
    city_packs.write_pack(BASE/'LeoRacer.pck',engine,entries)
    for pack in catalog['packs']:
        if sha(BASE/'GameAssets'/pack['file'])!=pack['sha256']:raise RuntimeError('Damaged staged pack: '+pack['file'])
    for name in ['InstallerContent.ps1'] :shutil.copy2(ROOT/'installer'/name,BASE/name)
    shutil.copy2(ROOT/'assets/config/default-roster-v1.json',BASE/'default-roster-v1.json')
    for source_name,destination in [('RELEASE_NOTES_270.md','RELEASE_NOTES.md'),('VALIDATION_270.md','TEST_REPORT.md')]:
        shutil.copy2(ROOT/'docs'/source_name,BASE/destination)
    (BASE/'README.txt').write_text('LEO RACER 2.7 ULTRA\n\nRun LeoRacer.exe. Keep the complete folder together.\n21 cars, six drivers, three tracks; 1–10 laps, default 3.\nUse Play Compatibility.cmd when Vulkan is unavailable.\nNo SDK, account or network is required. Vehicle Workshop is included.\nExtract into a new folder. Installer-managed replacements back up modified files.\nCustom content, settings and historical records are preserved.\nSee TEST_REPORT.md for measured results and remaining limitations.\nAttribution: GameAssets/licenses and each vehicle LICENSE.txt.\n',encoding='utf-8')
    for name,args in [('Play Compatibility.cmd','--rendering-method gl_compatibility --rendering-driver opengl3'),('Vehicle Workshop.cmd','-- --vehicle-workshop')]:
        (BASE/name).write_text('@echo off\r\ncd /d "%~dp0"\r\nstart "" "LeoRacer.exe" '+args+'\r\n',encoding='ascii')
    dump(BASE/'release-build.json',{'version':'2.7.0','label':'2.7 Ultra','core_sha256':sha(BASE/'LeoRacer.pck'),'default_vehicles':21,'tracks':3})
    dump(BASE/'required-payload.json',{'files':{p.relative_to(BASE).as_posix():sha(p) for p in files(BASE) if p.name!='required-payload.json' and not p.relative_to(BASE).as_posix().startswith('GameAssets/tracks/')}})
    print('ULTRA_STAGED',flush=True)
def payload(items):
    lines=[]
    def escape(value):return str(value).replace('$','$$').replace('"','$\\"')
    for file in items:
        relative=file.relative_to(BASE)
        digest=sha(file);short=ROOT/'build/nsis270'/digest;short.parent.mkdir(parents=True,exist_ok=True)
        # A previous input can share an inode with a regenerated candidate.
        if short.exists() and sha(short)!=digest:short.unlink()
        if not short.exists():
            try:os.link(file,short)
            except OSError:shutil.copy2(file,short)
        parent=str(relative.parent).replace('/','\\')
        lines+=['SetOutPath "$PLUGINSDIR\\payload'+('\\'+escape(parent) if parent!='.' else '')+'"','File "/oname='+escape(file.name)+'" "'+escape('..\\'+str(short.relative_to(ROOT)))+'"']
    return '\n'.join(lines)+'\n'

def track_selection(tracks):
    text='StrCpy $R3 ",$TrackSelection,"\n'
    for index,row in enumerate(tracks):
        text+='''SectionSetFlags ${TRACK_@INDEX@} 0
${StrStr} $R2 $R3 ",@TRACK@,"
${If} $TrackSelection == "all"
${OrIf} $R2 != ""
SectionSetFlags ${TRACK_@INDEX@} ${SF_SELECTED}
${EndIf}
'''.replace('@INDEX@',str(index)).replace('@TRACK@',row['id'])
    return text
def installer():
    OUT.mkdir(parents=True,exist_ok=True);QA.mkdir(parents=True,exist_ok=True)
    compiler=ROOT/'.tools/nsis/nsis-3.13/Bin/makensis.exe'
    if not compiler.exists():
        subprocess.run([shutil.which('pwsh') or 'powershell','-NoProfile','-ExecutionPolicy','Bypass','-File',str(ROOT/'tools/setup_ultra_nsis.ps1')],check=True)
    script=(ROOT/'installer/FocusedCars250.nsi').read_text(encoding='utf-8').replace('2.5.0','2.7.0').replace('release250-','release270-').replace('20 tested cars','21 tested cars').replace('20 cars','21 cars').replace('20 default cars','21 default cars').replace('selected 20 vehicles','selected 21 vehicles')
    (ROOT/'installer/Release270.nsi').write_text(script,encoding='utf-8')
    tracks=json.loads((ROOT/'content/releases/2.3.2.json').read_text(encoding='utf-8'))['tracks']
    for suffix in ['required','tracks','descriptions','selection']:
        if suffix=='required':text=payload([p for p in files(BASE) if not p.relative_to(BASE).as_posix().startswith('GameAssets/tracks/')])
        elif suffix=='tracks':text='\n'.join('Section "'+row['name']+'" TRACK_'+str(i)+'\nSectionIn 1 2\n'+payload(files(BASE/'GameAssets/tracks'/row['id']))+'SectionEnd' for i,row in enumerate(tracks))
        elif suffix=='descriptions':text='\n'.join('!insertmacro MUI_DESCRIPTION_TEXT ${TRACK_'+str(i)+'} "'+row['name']+'; solo and split-screen."' for i,row in enumerate(tracks))
        else:text=track_selection(tracks)
        (ROOT/('installer/release270-'+suffix+'.nsh')).write_text(text,encoding='utf-8')
    env=os.environ.copy();env['TEMP']=str(ROOT/'build/nsis270-temp');env['TMP']=env['TEMP'];Path(env['TEMP']).mkdir(exist_ok=True)
    with (QA/'installer-build.log').open('w',encoding='utf-8') as log:
        subprocess.run([str(compiler),'/V3','installer/Release270.nsi'],cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=1800)
    print('ULTRA_INSTALLER_BUILT',flush=True)
def package():
    OUT.mkdir(parents=True,exist_ok=True)
    target=OUT/'LeoRacer-2.7.0-win64.zip'
    with zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED,compresslevel=4) as archive:
        for file in files(BASE):archive.write(file,'LeoRacer/'+file.relative_to(BASE).as_posix())
    with zipfile.ZipFile(target) as archive:
        if archive.testzip():raise RuntimeError('Portable archive failed CRC validation')
    evidence=OUT/'LeoRacer-2.7.0-Evidence.zip'
    with zipfile.ZipFile(evidence,'w',zipfile.ZIP_DEFLATED,compresslevel=4) as archive:
        for file in sorted(QA.rglob('*')):
            if file.is_file() and file.suffix in ['.json','.log','.png','.md']:archive.write(file,file.relative_to(QA).as_posix())
    with zipfile.ZipFile(evidence) as archive:
        if not any(name.endswith('/process.log') for name in archive.namelist()):raise RuntimeError('Evidence archive must include raw process logs')
    for name in ['RELEASE_NOTES_270.md','VALIDATION_270.md']:shutil.copy2(ROOT/'docs'/name,OUT/('RELEASE_NOTES.md' if name.startswith('RELEASE') else 'TEST_REPORT.md'))
    artifacts=[target,evidence,OUT/'LeoRacer-Setup.exe',OUT/'RELEASE_NOTES.md',OUT/'TEST_REPORT.md']
    media=OUT/'LeoRacer-2.7.0-Media-Pack.zip'
    if media.exists():artifacts.append(media)
    rows=[{'name':p.name,'bytes':p.stat().st_size,'sha256':sha(p)} for p in artifacts]
    (OUT/'SHA256SUMS.txt').write_text(''.join(r['sha256']+'  '+r['name']+'\n' for r in rows),encoding='ascii')
    rows.append({'name':'SHA256SUMS.txt','bytes':(OUT/'SHA256SUMS.txt').stat().st_size,'sha256':sha(OUT/'SHA256SUMS.txt')})
    dump(OUT/'release-manifest.json',{'version':'2.7.0','commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'cars':21,'tracks':3,'files':rows})
    print('ULTRA_PACKAGED',flush=True)
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('action',nargs='?',choices=['stage','installer','package','all'],default='all');args=parser.parse_args()
    for action in ([stage,installer,package] if args.action=='all' else [globals()[args.action]]):action()
