"""Independent decoded audio QA, including seam and mono/stereo checks."""
from pathlib import Path
import hashlib,json,subprocess
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
FF=ROOT/'.tools/media/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe'
OUT=ROOT/'build/qa279';OUT.mkdir(parents=True,exist_ok=True)
rows=[];failures=[]
for path in [ROOT/'source_assets/audio279/Ceylon_Afterglow_128.wav',ROOT/'assets/audio/menu279/ceylon_afterglow.ogg']:
    decoded=subprocess.run([str(FF),'-v','error','-i',str(path),'-f','f32le','-ac','2','-ar','48000','-'],capture_output=True,check=True).stdout
    samples=np.frombuffer(decoded,dtype='<f4').reshape(-1,2)
    probe=subprocess.run([str(FF),'-hide_banner','-i',str(path),'-af','loudnorm=I=-18:TP=-2:LRA=9:print_format=json','-f','null','-'],capture_output=True,text=True,check=True)
    levels=json.JSONDecoder().raw_decode(probe.stderr[probe.stderr.rfind('{'):])[0]
    peak=float(np.max(np.abs(samples)));rms=float(np.sqrt(np.mean(samples*samples)))
    seam=float(np.max(np.abs(samples[0]-samples[-1])))
    ordinary=float(np.quantile(np.abs(np.diff(samples[::2],axis=0)),.999))
    mono=np.mean(samples,axis=1);mono_rms=float(np.sqrt(np.mean(mono*mono)))
    row={'file':str(path.relative_to(ROOT)),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'seconds':len(samples)/48000,'channels':2,'sample_rate':48000,'finite':bool(np.isfinite(samples).all()),'peak_dbfs':20*float(np.log10(max(peak,1e-12))),'lufs':float(levels['input_i']),'true_peak_dbtp':float(levels['input_tp']),'rms':rms,'mono_rms':mono_rms,'seam_delta':seam,'ordinary_99_9pct_delta':ordinary,'stereo_difference_rms':float(np.sqrt(np.mean((samples[:,0]-samples[:,1])**2)))}
    if not row['finite'] or abs(row['seconds']-90)>.05 or abs(row['lufs']+18)>.5 or row['true_peak_dbtp']>-2 or mono_rms<rms*.5 or seam>max(.02,ordinary):failures.append(path.name)
    rows.append(row)
result={'status':'PASS' if not failures else 'FAIL','errors':failures,'files':rows,'listening_review':'Not certified by numerical checks; WAV master and preview supplied for listening.'}
(OUT/'audio279.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print(json.dumps(result,indent=2))
raise SystemExit(bool(failures))
