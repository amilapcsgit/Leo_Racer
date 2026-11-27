"""Reproducible original 128 BPM / 48 bar menu composition; no source samples.

Sri Lankan percussion/techno is broad art direction only. The reference MP3 is
never opened by this generator. Circular event tails/delays make the loop exact.
"""
from pathlib import Path
import hashlib, json, math, subprocess, wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/audio/menu279'
WORK = ROOT / 'build/audio279'
SOURCE = ROOT / 'source_assets/audio279'
FF = ROOT / '.tools/media/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe'
RATE, BPM, BARS = 48000, 128, 48
BEAT = RATE * 60 // BPM
N = BEAT * 4 * BARS
rng = np.random.default_rng(290)

def hz(note): return 440 * 2 ** ((note - 69) / 12)

def tone(note, seconds, kind):
    t = np.arange(round(seconds * RATE), dtype=np.float64) / RATE
    f = hz(note)
    if kind == 'bass':
        v = np.sin(2*np.pi*f*t) + .22*np.sin(4*np.pi*f*t) + .08*np.sin(6*np.pi*f*t)
        v *= (1-np.exp(-t*170))*np.exp(-t*7)
    elif kind == 'pluck':
        v = (np.sin(2*np.pi*f*t)+.28*np.sin(2*np.pi*f*2.002*t)+.1*np.sin(2*np.pi*f*3.997*t))
        v *= (1-np.exp(-t*300))*np.exp(-t*5.5)
    else:
        v = sum(np.sin(2*np.pi*f*ratio*t+offset)*gain for ratio,offset,gain in [(1,0,.5),(1.003,.4,.25),(.998,.9,.25),(2,0,.08)])
        v *= np.minimum(1,t/.2)*np.minimum(1,(seconds-t)/.5)
    return v.astype(np.float32)

def drum(kind, velocity=1):
    duration = {'kick':.5,'low':.4,'high':.2,'rim':.12,'hat':.09,'open':.28,'clap':.19}[kind]
    t = np.arange(round(duration*RATE))/RATE
    noise = rng.normal(0,1,len(t))
    hp = noise - np.convolve(noise,np.ones(7)/7,'same')
    if kind == 'kick':
        phase = 2*np.pi*(46*t+100*.025*(1-np.exp(-t/.025)))
        v = np.sin(phase)*np.exp(-t*10)+hp*.06*np.exp(-t*150)
    elif kind in ('low','high'):
        f = 118 if kind=='low' else 248
        phase = 2*np.pi*(f*t+f*.15*.025*(1-np.exp(-t/.025)))
        v = sum(g*np.sin(phase*r)*np.exp(-t*d) for r,g,d in [(1,.7,12),(1.51,.24,22),(2.12,.14,35),(3.04,.09,50)])+hp*.1*np.exp(-t*65)
    elif kind=='rim': v=(np.sin(2*np.pi*710*t)+.5*np.sin(2*np.pi*1190*t))*np.exp(-t*65)+hp*.15*np.exp(-t*90)
    elif kind in ('hat','open'): v=hp*np.exp(-t*(70 if kind=='hat' else 17))*.4
    else:
        v=hp*.35*np.exp(-t*24)*(1+.7*np.cos(2*np.pi*85*t))*np.minimum(1,t/.002)
    v *= np.minimum(1,t/.001)
    return (v*velocity).astype(np.float32)

def add(bus, signal, at, gain=1., pan=0.):
    start = round(at*BEAT) % N
    values = signal[:,None]*np.array([math.sqrt((1-pan)/2),math.sqrt((1+pan)/2)],dtype=np.float32)*gain
    end = min(len(values),N-start)
    bus[start:start+end] += values[:end]
    if end<len(values): bus[:len(values)-end] += values[end:]

def main():
    OUT.mkdir(parents=True,exist_ok=True);WORK.mkdir(parents=True,exist_ok=True);SOURCE.mkdir(parents=True,exist_ok=True)
    (SOURCE/'.gdignore').touch()
    rhythm=np.zeros((N,2),np.float32);percussion=np.zeros_like(rhythm)
    bass=np.zeros_like(rhythm);harmony=np.zeros_like(rhythm);lead=np.zeros_like(rhythm)
    # D minor / Bb / F / C; original phrase, with three arrangements.
    chords=[(50,57,65),(46,53,62),(53,60,69),(48,55,64)]
    phrase=[74,77,81,77,72,74,69,72,74,81,79,77,72,69,72,77]
    for bar in range(BARS):
        chord=chords[(bar//4)%4];base=bar*4
        section=bar//16
        for beat in range(4):
            add(rhythm,drum('kick'),base+beat,.48)
            if beat in [1,3]:add(rhythm,drum('clap'),base+beat,.17,.12)
            add(rhythm,drum('hat',.85 if beat%2==0 else .7),base+beat+.5,.2,-.3)
            add(bass,tone(chord[0]-12,.35,'bass'),base+beat+.5,.16)
        # Interlocking hand-drum inspired voices; no claimed traditional melody.
        for step,kind,vel,pan in [(0,'low',1,-.18),(3,'high',.8,.3),(6,'rim',.5,-.4),(8,'low',.85,-.18),(10,'high',.7,.3),(13,'high',.95,.3),(15,'rim',.45,-.4)]:
            add(percussion,drum(kind,vel),base+step/4,.22 if kind!='rim' else .12,pan)
        if bar%4==3:
            for step in [14,14.5,15,15.5]:add(percussion,drum('high',.45+(step-14)*.2),base+step/4,.13,.25)
        if section!=1 or bar%4>=2:
            for step in [2,6,10,14]:add(rhythm,drum('open',.7),base+step/4,.08,.35)
        if bar%4==0:
            for i,note in enumerate(chord):add(harmony,tone(note+12,7.5,'pad'),base,.065,(i-1)*.4)
        if bar>=4 and not 24<=bar<28:
            for hit,step in enumerate([1,2.5,3.25]):
                note=phrase[(bar*3+hit)%len(phrase)]
                if section==2 and bar%4==3:note+=12
                add(lead,tone(note,1.25,'pluck'),base+step,.065 if section!=1 else .04,(-.25,.25,0)[hit])
    # Gentle beat-synchronous pumping, circular stereo echoes and room tails.
    phase=(np.arange(N)%BEAT)/BEAT
    pump=(.68+.32*(1-np.exp(-phase*9))).astype(np.float32)[:,None]
    for bus in [bass,harmony,lead]:bus*=pump
    for bus,amount in [(percussion,.10),(harmony,.16),(lead,.25)]:
        dry=bus.copy()
        for beats,gain in [(.75,amount),(1.5,amount*.55),(2.25,amount*.3)]:
            bus+=np.roll(dry[:,::-1],round(BEAT*beats),axis=0)*gain
    mix=rhythm+percussion+bass+harmony+lead
    mix=np.tanh(mix*.9)
    mix-=mix.mean(axis=0)
    raw=WORK/'menu-mix.wav'
    with wave.open(str(raw),'wb') as file:
        file.setparams((2,2,RATE,N,'NONE','not compressed'))
        file.writeframes((np.clip(mix,-1,1)*32767).astype('<i2').tobytes())
    # Fixed gain preserves the exact circular seam; verify loudness independently.
    analysis=subprocess.run([str(FF),'-hide_banner','-i',str(raw),'-af','loudnorm=I=-18:TP=-2:LRA=9:print_format=json','-f','null','-'],capture_output=True,text=True,check=True)
    levels=json.JSONDecoder().raw_decode(analysis.stderr[analysis.stderr.rfind('{'):])[0]
    gain=-18-float(levels['input_i']);gain=min(gain,-2-float(levels['input_tp']))
    master=SOURCE/'Ceylon_Afterglow_128.wav';ogg=OUT/'ceylon_afterglow.ogg'
    subprocess.run([str(FF),'-hide_banner','-loglevel','error','-y','-i',str(raw),'-af',f'volume={gain}dB','-c:a','pcm_s24le',str(master)],check=True)
    subprocess.run([str(FF),'-hide_banner','-loglevel','error','-y','-i',str(master),'-c:a','libvorbis','-q:a','6',str(ogg)],check=True)
    def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
    manifest={'title':'Ceylon Afterglow','version':'2.7.9','bpm':BPM,'bars':BARS,'seconds':N/RATE,'sample_rate':RATE,'channels':2,'seed':290,'method':'Original deterministic synthesis and arrangement; no sampled recording','reference':'User supplied GAJAGA WANNAMA techno version.mp3: broad percussion/techno direction only; not redistributed','gain_db':gain,'pre_master_loudness':levels,'loop_boundary_delta':float(np.max(np.abs(mix[0]-mix[-1]))),'files':{p.name:sha(p) for p in [master,ogg]},'generator':'tools/compose_menu279.py'}
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    (ROOT/'licenses/MENU_MUSIC_279.md').write_text('# Ceylon Afterglow\n\nOriginal Leo Racer 2.7.9 menu composition, generated reproducibly by tools/compose_menu279.py. 128 BPM, 48 bars, 90 seconds, stereo 48 kHz. All sounds and musical phrases are newly synthesized; no samples, melody or vocals from the supplied reference recording are included. Governed by the original-work terms in the project LICENSE. The user-supplied reference MP3 is not distributed.\n',encoding='utf-8')
    print(json.dumps(manifest,indent=2))

if __name__=='__main__':main()
