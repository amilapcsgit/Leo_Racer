"""Typeset exact multilingual sign copy over original generated artwork."""
from pathlib import Path
import json,hashlib
from PIL import Image,ImageDraw,ImageFont,features
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/art/kandy/signs';OUT.mkdir(parents=True,exist_ok=True)
fonts=ROOT/'assets/art/kandy/fonts'
LATIN=ROOT/'assets/fonts/BarlowCondensed-BoldItalic.ttf'
def font(size,path=LATIN):return ImageFont.truetype(str(path),size)
def text(image,words,y,size,color='#fff4d5',path=LATIN):
    draw=ImageDraw.Draw(image);f=font(size,path)
    while draw.textbbox((0,0),words,font=f)[2]>image.width*.91:size-=2;f=font(size,path)
    draw.text((image.width/2,y),words,font=f,fill=color,anchor='mt',stroke_width=1,stroke_fill='#16342b')
def plate(name,title,subtitle='',size=(1536,512)):
    im=Image.new('RGB',size,'#163d35');d=ImageDraw.Draw(im)
    d.rectangle((12,12,size[0]-13,size[1]-13),outline='#d3c18a',width=9)
    text(im,title,size[1]*.18,int(size[1]*.40))
    if subtitle:text(im,subtitle,size[1]*.68,int(size[1]*.14))
    im.save(OUT/(name+'.png'))
assert (OUT/'tea-artwork.png').is_file(),'Create tea-artwork.png with the imagegen workflow first'
tea=Image.open(OUT/'tea-artwork.png').convert('RGB').resize((2048,683))
text(tea,'CEYLON TEA',50,160);text(tea,'KANDY  /  HILL COUNTRY',232,64);tea.save(OUT/'tea-shop.png')
assert (OUT/'tourism-artwork.png').is_file(),'Create tourism-artwork.png with the imagegen workflow first'
tour=Image.open(OUT/'tourism-artwork.png').convert('RGB').resize((2048,1024))
text(tour,'KANDY',48,184);text(tour,'THE HEART OF HILL COUNTRY',244,54);tour.save(OUT/'tourism.png')
welcome=Image.new('RGB',(1536,768),'#153b32');draw=ImageDraw.Draw(welcome);draw.rectangle((15,15,1520,752),outline='#dbcb96',width=10)
text(welcome,'KANDY LAKE',55,180)
text(welcome,'මහනුවර',310,146,path=fonts/'NotoSansSinhala.ttf')
text(welcome,'கண்டி',526,144,path=fonts/'NotoSansTamil.ttf')
welcome.save(OUT/'welcome.png')
plate('start','LEO RACER','KANDY LAKE',(2048,512))
im=Image.open(OUT/'start.png');d=ImageDraw.Draw(im)
for x0 in (28,1836):
    for x in range(4):
        for y in range(10):d.rectangle((x0+x*45,30+y*45,x0+(x+1)*45,30+(y+1)*45),fill='white' if (x+y)%2 else '#15201c')
im.save(OUT/'start.png')
for i,title in enumerate(['KANDY TOWN','LAKE PROMENADE','HILL COUNTRY','DALADA VISTA']):plate('sector-%d'%i,title,'KANDY LAKE CIRCUIT')
for name,title in [('cafe','KANDY CAFE'),('bakery','HILL COUNTRY BAKERY'),('market','KANDY MARKET')]:plate(name,title,'LOCALLY MADE  /  KANDY')
report={'generator':'Built-in imagegen + deterministic Pillow text shaping','raqm':features.check_feature('raqm'),'date':'2026-10-26','copy':{'welcome':['KANDY LAKE','මහනුවර','கண்டி'],'start':['LEO RACER','KANDY LAKE']},'prompts':[
 'Original print-ready horizontal Ceylon tea shop advertisement: tea leaves and bud, copper kettle, porcelain tea cup, hill-country plantation, dark forest-green background and restrained aged gold border; natural daylight; empty upper center for typography; no text/logos or support hardware.',
 'Original Kandy Lake tourism photograph: island, white cloud wall, tropical trees, Temple of the Tooth, hazy green hills, late morning cumulus clouds; natural colors; open upper sky for typography; no text, cars or mockup.'
],'files':{p.name:hashlib.file_digest(p.open('rb'),'sha256').hexdigest() for p in OUT.glob('*.png')}}
(OUT/'provenance.json').write_text(json.dumps(report,indent=2,ensure_ascii=False),encoding='utf-8')
print('KANDY_SIGNS_READY',len(report['files']),'raqm=',report['raqm'])
