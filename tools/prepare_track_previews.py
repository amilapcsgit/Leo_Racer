"""Small shipped track previews from the exact baked routes."""
from pathlib import Path
import json
from PIL import Image, ImageDraw
ROOT=Path(__file__).resolve().parents[1]
for folder in (ROOT/'assets/tracks').iterdir():
    manifest=folder/'manifest.json'
    if not manifest.exists():continue
    data=json.loads(manifest.read_text(encoding='utf-8'))
    route=json.loads((folder/data['route']).read_text(encoding='utf-8'))
    points=route['points'];xs=[p[0] for p in points];zs=[p[2] for p in points]
    scale=min(680/(max(xs)-min(xs)),340/(max(zs)-min(zs)))
    coords=[(384+(x-(max(xs)+min(xs))/2)*scale,210+(z-(max(zs)+min(zs))/2)*scale) for x,y,z in points]
    image=Image.new('RGB',(768,432),'#091a28');draw=ImageDraw.Draw(image)
    draw.line(coords+[coords[0]],fill='#1d5564',width=16,joint='curve')
    draw.line(coords+[coords[0]],fill='#64e2d3',width=5,joint='curve')
    x,y=coords[0];draw.ellipse((x-8,y-8,x+8,y+8),fill='#ffb85c')
    image.save(folder/'preview.png',optimize=True)
    data['preview']='preview.png';manifest.write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8',newline='\n')
    print('TRACK_PREVIEW',folder.name)
