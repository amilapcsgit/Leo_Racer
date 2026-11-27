"""Exercise the real C# worker against an unchanged 2.6 schema and old-writer SQL."""
from pathlib import Path
import json, os, sqlite3, subprocess, time
ROOT=Path(__file__).resolve().parents[1]
QA=ROOT/'build/qa270';QA.mkdir(parents=True,exist_ok=True)
fixture=QA/('legacy-'+str(time.time_ns())+'.sqlite3')
db=sqlite3.connect(fixture)
db.executescript('''
CREATE TABLE sessions(id TEXT PRIMARY KEY,track_id TEXT NOT NULL,mode INTEGER NOT NULL,ruleset TEXT NOT NULL,ended_utc TEXT NOT NULL);
CREATE TABLE results(session_id TEXT NOT NULL REFERENCES sessions(id),profile_id TEXT NOT NULL,player_name TEXT NOT NULL,driver_id TEXT NOT NULL,vehicle_id TEXT NOT NULL,class_id TEXT NOT NULL,place INTEGER NOT NULL,race_ms INTEGER NOT NULL,lap_ms INTEGER NOT NULL,PRIMARY KEY(session_id,profile_id));
CREATE TABLE session_courses(session_id TEXT PRIMARY KEY REFERENCES sessions(id),revision INTEGER NOT NULL);
INSERT INTO sessions VALUES('legacy','astra_coast',1,'distinct_v5_static','2026-10-01T10:00:00Z');
INSERT INTO results VALUES('legacy','old','LEGACY CHAMPION','human','bigster','arcade_v2',1,123456,40000);
INSERT INTO session_courses VALUES('legacy',1);
PRAGMA user_version=1;
''')
original=db.execute("SELECT * FROM sessions WHERE id='legacy'").fetchone(),db.execute("SELECT * FROM results WHERE session_id='legacy'").fetchone()
db.commit();db.close()
engine=ROOT/'.tools/godot/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe'
if not engine.exists():engine=ROOT.parent.parent/'tools/godot-net/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe'
sdk=ROOT/'.tools/dotnet'
if not sdk.exists():sdk=ROOT.parent.parent/'tools/dotnet'
env=os.environ.copy();env['DOTNET_ROOT']=str(sdk);env['PATH']=str(sdk)+os.pathsep+env['PATH'];env['APPDATA']=str(QA/'legacy-profile');env['LOCALAPPDATA']=env['APPDATA'];Path(env['APPDATA']).mkdir(exist_ok=True)
for phase in ['initial','old-write']:
    if phase=='old-write':
        db=sqlite3.connect(fixture)
        if db.execute('PRAGMA user_version').fetchone()[0]!=1:raise RuntimeError('2.6 would reject this schema version')
        db.execute("INSERT INTO sessions VALUES('returning','astra_coast',1,'distinct_v5_static','2026-10-02T10:00:00Z')")
        db.execute("INSERT INTO results VALUES('returning','returning','RETURNING 2.6 RACER','human','bigster','arcade_v2',1,200000,60000)")
        db.execute("INSERT INTO session_courses VALUES('returning',1)");db.commit();db.close()
    args=[str(engine),'--headless','--path',str(ROOT),'--script','res://tests/ultra_legacy_test.gd','--','--drive-test','--legacy-fixture='+str(fixture)]
    if phase=='old-write':args.append('--after-old-write')
    result=subprocess.run(args,cwd=ROOT,env=env,text=True,capture_output=True,timeout=120)
    (QA/('legacy-'+phase+'.log')).write_text(result.stdout+result.stderr,encoding='utf-8')
    if result.returncode or 'SCRIPT ERROR' in result.stdout+result.stderr:raise RuntimeError('Legacy worker test failed: '+phase)
db=sqlite3.connect(fixture)
current=db.execute("SELECT * FROM sessions WHERE id='legacy'").fetchone(),db.execute("SELECT * FROM results WHERE session_id='legacy'").fetchone()
if original!=current:raise RuntimeError('Historical values changed')
if db.execute("SELECT lap_count FROM session_laps WHERE session_id='returning'").fetchone()!=(3,):raise RuntimeError('Old-writer session was not migrated')
db.close()
(QA/'legacy.json').write_text(json.dumps({'status':'PASS','original_values_unchanged':True,'schema_version':1,'two_way_26_compatibility':True,'old_writer_backfill':True},indent=2))
print('ULTRA_LEGACY_COMPATIBILITY_PASS',flush=True)
