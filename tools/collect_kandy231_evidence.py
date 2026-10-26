"""Collect checked results and unretouched game captures for release review."""
from pathlib import Path
import datetime,hashlib,json,shutil
from PIL import Image,ImageDraw,ImageFont
from qa_kandy231 import ROOT
WORK=ROOT/'build/kandy231';DOC=ROOT/'docs/qa-kandy231';OUT=WORK/'evidence'
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def sheet(rows,names,target,width=480):
 height=round(width*9/16);margin=30
 canvas=Image.new('RGB',(len(names)*width,55+len(rows)*(height+margin)),'#101d24');draw=ImageDraw.Draw(canvas)
 font=ImageFont.truetype(str(ROOT/'assets/fonts/body.ttf'),20)
 for col,name in enumerate(names):draw.text((col*width+12,12),name,font=font,fill='white')
 for row,images in enumerate(rows):
  for col,(path,label) in enumerate(images):
   im=Image.open(path).convert('RGB');im.thumbnail((width,height))
   x=col*width;y=55+row*(height+margin);canvas.paste(im,(x+(width-im.width)//2,y))
   draw.text((x+10,y+height+3),label,font=font,fill='#cfddd8')
 canvas.save(target,quality=88)
def main():
 DOC.mkdir(parents=True,exist_ok=True);OUT.mkdir(parents=True,exist_ok=True);(DOC/'.gdignore').write_text('',encoding='utf-8')
 sources={'surface':'build/kandy/surface-clearance.json','landmarks':'build/kandy/landmark-validation.json','materials':'build/kandy/material-retention.json','malformed':'build/kandy/malformed-test.json','streaming':'build/kandy/streaming.json','three_lap_split':'build/kandy/full-race.json','three_lap_single':'build/kandy/full-race-single.json','text':'build/kandy231/text.json','presentation':'build/kandy231/presentation.json','installer':'build/kandy231/installer.json','packaged_races':'build/kandy231/release/qa/races.json','vehicles':'build/kandy231/release/qa/all-48.json'}
 results={key:read(ROOT/path) for key,path in sources.items()}
 assert all(value['status']=='PASS' for value in results.values())
 profiles={p.stem:read(p) for p in sorted(WORK.glob('profile-*.json'))}
 assert len(profiles)==8 and all(row['six_racers']==6 for row in profiles.values())
 for key,row in profiles.items():
  if key.startswith('profile-updated'):
   assert row['target_met'],key+' below measured 60fps target'
   assert row['track_scenery_sha256']==read(WORK/'tracks/kandy_lake/manifest.json')['packs'][0]['sha256'],key+' is for a different content build'
 for key in ['KandyPrecinct_mahaweli','KandyPrecinct_tooth_temple','KandyStartArch']:
  text=(WORK/('native-'+key+'.log')).read_text(encoding='utf-8');assert 'textures=1' in text and 'NATIVE_LIGHTMAP_ALL_DONE' in text and 'name clashes' not in text
 for model in read(WORK/'models.json')['models']:
  path=Path.home()/'Downloads'/model['source'];assert hashlib.sha256(path.read_bytes()).hexdigest()==model['source_sha256']
 report={'status':'PASS','generated_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'checks':results,'profiles':profiles,'profile_method':'Serial six-racer 1080p runs, 6s warmup then 30s sample; baseline uses unchanged v2.3.0 track on the same current core for controlled scenery comparison. Single player and separated two-player split-screen; 120fps cap.','original_download_hashes_unchanged':True,'native_bake_name_conflicts':False,'known_limits':['Native authoring editor retains upstream shutdown list/tree warnings.','Installer preservation checks use isolated settings/record file markers, not a live player database.','Hardware-specific measurements; Compatibility can have streaming frame spikes and emits GPU cleanup messages on both baseline and updated runs.']}
 if (WORK/'portable.json').exists():report['checks']['extracted_portable']=read(WORK/'portable.json')
 (DOC/'acceptance.json').write_text(json.dumps(report,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
 table=['# Kandy performance comparison','',report['profile_method'],'','GPU: NVIDIA RTX A1000 6GB Laptop GPU. MB are decimal; static memory is Godot\'s monitor, not total process working set. Values below are baseline → updated.','','| Renderer / mode | FPS | p95 ms | longest frame ms | draw calls | static MB | video MB |','| --- | ---: | ---: | ---: | ---: | ---: | ---: |']
 for renderer in ['forward_plus','gl_compatibility']:
  for mode in ['single','split']:
   old=profiles['profile-baseline-'+renderer+'-'+mode];new=profiles['profile-updated-'+renderer+'-'+mode]
   pairs=['%.1f → %.1f'%(old[key],new[key]) for key in ['fps','p95_ms','max_frame_ms','draw_calls','peak_static_mb','peak_video_mb']]
   table.append('| '+renderer+' / '+mode+' | '+' | '.join(pairs)+' |')
 table+=['','Compatibility retains occasional frame spikes. Forward+ is recommended. Streaming/track-change stability is checked separately in acceptance.json.','']
 (DOC/'performance.md').write_text('\n'.join(table),encoding='utf-8')
 for half in range(2):
  rows=[]
  for i in range(half*6,half*6+6):rows.append([(ROOT/('build/kandy/captures/'+phase+'/view-%02d.png'%i),'Lap view %02d'%i) for phase in ['before','forward','compatibility']])
  sheet(rows,['v2.3.0','v2.3.1 Forward+','v2.3.1 Compatibility'],DOC/('lap-%d.jpg'%(half+1)))
 images=[(WORK/'closeups'/(name+'.png'),name) for name in ['stupa','temple','buddha','jungle-temple','ceypetco']]
 images.append((WORK/'loading/race.png','Race loading — exact punctuation'))
 sheet([images[i:i+2] for i in range(0,6,2)],['Landmarks and loading','Runtime captures'],DOC/'landmarks.jpg',640)
 details=[(WORK/'details'/(name+'.png'),name) for name in ['welcome','tourism','tea-shop','flag-hoist']]
 sheet([details[:2],details[2:]],['Physical multilingual signs','Artwork and flag hoist'],DOC/'signs.jpg',640)
 for phase in ['before','forward','compatibility']:shutil.copytree(ROOT/'build/kandy/captures'/phase,OUT/'lap'/phase,dirs_exist_ok=True)
 for name in ['closeups','details','loading']:shutil.copytree(WORK/name,OUT/name,dirs_exist_ok=True)
 for p in DOC.iterdir():
  if p.is_file() and p.suffix in ['.json','.jpg','.md']:shutil.copy2(p,OUT/p.name)
 shutil.copy2(ROOT/'docs/KANDY_231.md',OUT/'AUTHORING-AND-VALIDATION.md')
 print('KANDY231_EVIDENCE_READY',flush=True)
if __name__=='__main__':main()
