"""Original compact island synth music and UI/VFX sounds. No sampled content."""
import math, wave, struct, os, random
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT=os.path.join(ROOT,'assets','audio')
SR=22050
random.seed(17)
def save(name,arr):
    peak=max(.001,max(abs(v) for v in arr));scale=.85/max(1,peak)
    with wave.open(os.path.join(OUT,name+'.wav'),'w') as w:
        w.setparams((1,2,SR,0,'NONE','not compressed'));w.writeframes(b''.join(struct.pack('<h',int(max(-1,min(1,v*scale))*32767)) for v in arr))
def freq(m):return 440*2**((m-69)/12)
def tone(arr,start,duration,note,volume=.2,kind='bell'):
    f=freq(note);begin=int(start*SR);count=int(duration*SR)
    for j in range(count):
        i=begin+j
        if i>=len(arr):break
        t=j/SR;env=min(1,t/.006)*math.exp(-t*(5 if kind=='bell' else 3)/duration)
        a=math.sin(math.tau*f*t)
        if kind=='bell':a+=.3*math.sin(math.tau*f*2*t)*math.exp(-t*14)+.1*math.sin(math.tau*f*4*t)
        if kind=='bass':a=.8*a+.16*math.sin(math.tau*f*2*t)
        arr[i]+=a*env*volume
beat=60/124;duration=beat*32
arr=[0.] * int(duration*SR)
melody=[76,79,81,79,76,74,72,74,76,79,84,83,81,79,76,74,77,81,84,81,79,77,76,74,72,76,79,76,74,72,71,72]
for b in range(32):
    tone(arr,b*beat,beat*.85,melody[b],.16)
    if b%2==0:tone(arr,b*beat,beat*.65,melody[b]+12,.055)
    chord=[[48,52,55],[45,48,52],[41,45,48],[43,47,50]][(b//8)%4]
    tone(arr,b*beat,beat*.9,chord[b%3] - (12 if b%4==0 else 0),.16,'bass')
    if b%2==0:
        for note in chord:tone(arr,b*beat+beat*.5,beat*.6,note+12,.045)
    for j in range(int(.12*SR)):
        i=int(b*beat*SR)+j;t=j/SR
        if i<len(arr): arr[i]+=.16*math.sin(math.tau*(58*t+20*t*math.exp(-t*35)))*math.exp(-t*35)
    for off in [0,.5]:
        for j in range(int(.06*SR)):
            i=int((b+off)*beat*SR)+j
            if i<len(arr):arr[i]+=random.uniform(-1,1)*.035*math.exp(-j/SR*80)
save('island_music',arr)
for name,notes,dur in [('click',[84],.12),('countdown',[72],.23),('go',[84,88,91],.55),('finish',[72,76,79,84,88,91],2.0)]:
    arr=[0.] * int(dur*SR)
    for i,n in enumerate(notes):tone(arr,i*.08,dur-i*.08,n,.22)
    save(name,arr)
arr=[]
for i in range(int(.85*SR)):
    t=i/SR;env=math.sin(math.pi*t/.85)**.5
    arr.append((random.uniform(-1,1)*.22+math.sin(math.tau*(160*t+330*t*t))*.2)*env)
save('boost',arr)
print('ORIGINAL_AUDIO_COMPLETE')
