"""Offline import, flattened precinct preparation, native GI bake, and GPU-backed export."""
from pathlib import Path
import os,subprocess,re,json,sys
from qa_kandy231 import ROOT,run

def main():
    project=ROOT/'build/TrackSDK';work=ROOT/'build/kandy231'
    engine=ROOT.parent.parent/'tools/godot/Godot_v4.7.2-stable_win64.exe'
    env=os.environ.copy()
    for key,folder in [('APPDATA','profiles/bake'),('LOCALAPPDATA','profiles/bake'),('TEMP','temp'),('TMP','temp')]:
        p=work/folder;p.mkdir(parents=True,exist_ok=True);env[key]=str(p)
    config=project/'project.godot';original=config.read_bytes()
    try:
        text=original.decode('utf-8');text=re.sub(r'enabled=PackedStringArray\([^\n]*\)','enabled=PackedStringArray("res://addons/auto_lightmap/plugin.cfg")',text);config.write_text(text,encoding='utf-8')
        for name,arguments in [('sdk-final-import',['--headless','--editor','--import','--quit'])]:
            process=subprocess.run([str(engine),'--path',str(project),*arguments],env=env,cwd=ROOT,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=240)
            (work/(name+'.log')).write_text(process.stdout+process.stderr,encoding='utf-8');assert process.returncode==0,name
        # Godot's 3D usage detector otherwise changes the EXR to lossy BC6H,
        # altering radiance and the longitude boundary independently per block.
        settings=project/'art/environment/daylight.exr.import'
        text=settings.read_text(encoding='utf-8')
        for key,value in [('compress/mode','0'),('compress/hdr_compression','0'),('detect_3d/compress_to','0'),('mipmaps/generate','true')]:
            text=re.sub(r'^'+re.escape(key)+r'=.*$',key+'='+value,text,flags=re.M)
        settings.write_text(text,encoding='utf-8')
        process=subprocess.run([str(engine),'--path',str(project),'--headless','--editor','--import','--quit'],env=env,cwd=ROOT,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=240)
        (work/'sdk-lossless-hdr-import.log').write_text(process.stdout+process.stderr,encoding='utf-8');assert process.returncode==0
        assert run('res://inspect_landmarks.gd','imported-model-bounds',project=project,mono=False)
        if '--export-only' not in sys.argv:assert run('res://bake_elevated.gd','prepare-native-precincts',['--action=lightmaps'],project=project,mono=False)
        for key in ([] if '--export-only' in sys.argv else ['KandyPrecinct_mahaweli','KandyPrecinct_tooth_temple','KandyStartArch']):
            startup=subprocess.STARTUPINFO();startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW;startup.wShowWindow=0
            process=subprocess.run([str(engine),'--editor','--path',str(project),'--','--bake-kandy-precincts','--precinct='+key],env=env,cwd=ROOT,capture_output=True,text=True,encoding='utf-8',errors='replace',startupinfo=startup,timeout=240)
            log=process.stdout+process.stderr;(work/('native-'+key+'.log')).write_text(log,encoding='utf-8')
            assert 'textures=1' in log and 'NATIVE_LIGHTMAP_ALL_DONE' in log,key
            assert 'name clashes' not in log and 'incoming node' not in log,key+' names conflict'
            print('PRECINCT_BAKED',key,flush=True)
        # Native LightmapGI defaults its layered EXR atlases to BC6H as well.
        # Reimport all bake outputs losslessly before the separate export process.
        for settings in (project/'baked').glob('*.exr.import'):
            text=settings.read_text(encoding='utf-8')
            for key,value in [('compress/mode','0'),('compress/hdr_compression','0')]:text=re.sub(r'^'+re.escape(key)+r'=.*$',key+'='+value,text,flags=re.M)
            settings.write_text(text,encoding='utf-8')
        process=subprocess.run([str(engine),'--path',str(project),'--headless','--editor','--import','--quit'],env=env,cwd=ROOT,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=240)
        (work/'sdk-lossless-lightmap-import.log').write_text(process.stdout+process.stderr,encoding='utf-8');assert process.returncode==0
        assert run('res://bake_elevated.gd','track-export',['--output=res://../kandy231/tracks','--use-lightmaps'],headless=False,project=project,mono=False)
    finally:config.write_bytes(original)
    # Verify the content-addressed resource graph, independent of the authoring cache.
    from city_packs import read_pack
    import hashlib
    _,entries=read_pack(work/'tracks/kandy_lake/scenery.pck')
    assert all(hashlib.sha256(data).hexdigest()==Path(name).stem for name,data in entries.items() if name.endswith('.res'))
    from finalize_kandy231_content import finalize
    finalize()
    print('KANDY231_TRACK_BUILT',len(entries),'resources',flush=True)

if __name__=='__main__':main()
