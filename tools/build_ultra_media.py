"""Collect showcase artwork without changing originals or bundling model sources."""
from pathlib import Path
import hashlib, html, json, shutil, zipfile
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
PACK=ROOT.parent.parent/'Leo_Racer_Media_Pack_2.7'
ZIP=ROOT/'dist/release-2.7.0/LeoRacer-2.7.0-Media-Pack.zip'

def build():
    PACK.mkdir(exist_ok=True)
    sources=[]
    for folder in ['assets/ui/art','assets/ui/boot','assets/ui/icons','assets/art','assets/signs','assets/flags','docs/media']:
        sources += [p for p in (ROOT/folder).rglob('*') if p.is_file() and p.suffix.lower() in ['.png','.jpg','.jpeg','.svg','.json']]
    sources += list((ROOT/'docs/screenshots/2.7.0').glob('*.png'))
    sources += list((ROOT/'docs/screenshots').rglob('*promotional*.png'))
    rows=[]
    for source in sorted(set(sources)):
        rel=source.relative_to(ROOT)
        category='screenshots' if rel.parts[:2]==('docs','screenshots') and 'promotional' not in source.name else 'artwork'
        if 'cars' in rel.parts and 'ultra' in rel.parts:category='transparent-cars'
        elif source.suffix=='.svg':category='vectors'
        target=PACK/category/rel;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
        row={'file':target.relative_to(PACK).as_posix(),'source':rel.as_posix(),'sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'kind':category}
        if source.suffix.lower() in ['.png','.jpg','.jpeg']:
            with Image.open(source) as image:
                row['width'],row['height']=image.size
                web=PACK/'web'/target.relative_to(PACK).with_suffix('.webp');web.parent.mkdir(parents=True,exist_ok=True)
                image.thumbnail((1920,1080),Image.Resampling.LANCZOS)
                image.save(web,'WEBP',quality=88,method=4)
                row['web']=web.relative_to(PACK).as_posix()
        rows.append(row)
    outlines=ROOT/'build/qa270/source-finish-forward'
    for source in outlines.glob('*.svg'):
        target=PACK/'vectors/track-outlines'/source.name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
        rows.append({'file':target.relative_to(PACK).as_posix(),'source':'LeoTrackHologram.route_svg: '+source.stem,'kind':'vectors','sha256':hashlib.sha256(source.read_bytes()).hexdigest()})
    (PACK/'asset-index.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
    (PACK/'README.md').write_text('''# Leo Racer 2.7 Ultra — media pack

Start with index.html for the visual catalog. Original-resolution PNG/SVG assets are retained; web/ contains resized WebP copies with transparency preserved. transparent-cars/ contains both renderer variants of all 21 cars. Prefer Forward+ variants for consistent website presentation. Artwork includes current and earlier generated art; filenames and provenance JSON retain their history. No models or development tools are included.

Actual game captures are in screenshots/. Generated promotional images and loading backgrounds are artwork, not screenshots. Winner names in records captures are isolated demonstration fixtures.

Official Windows installer: https://github.com/amilapcsgit/Leo_Racer/releases/latest/download/LeoRacer-Setup.exe
Release page and checksums: https://github.com/amilapcsgit/Leo_Racer/releases/latest
Use a normal HTTPS link directly to GitHub; do not rehost or wrap the executable. The latest URL follows future stable releases. Do not describe the installer as signed, Microsoft-verified or malware-certified.

Brand colors: navy #101923, cyan #43e7ef, gold #ffc857, cream #f3e5ca. Existing typography uses Barlow Condensed. Keep text readable and use real screenshots for feature claims.

## Credits and usage
This pack is for showcasing Leo Racer. It is not a blanket public-domain license for third-party characters, vehicle designs, logos, fonts, textures or models depicted in rendered images. Retain the game credits and underlying asset notices; do not imply manufacturer endorsement. See the repository LICENSE/NOTICE files and each distributed vehicle LICENSE.txt. Route reference: © OpenStreetMap contributors / ODbL. AI artwork provenance and prompts accompany the source artwork where available. SVG icons and website button are existing project graphics. Original files and synced sources were not changed to create this pack.
''',encoding='utf-8')
    cards=[]
    for row in rows:
        if row['file'].endswith('.json'):continue
        href=html.escape(row['file'],quote=True);src=html.escape(row.get('web',row['file']),quote=True)
        cards.append(f'<a class="card" href="{href}"><img loading="lazy" src="{src}" alt="{html.escape(row["source"],quote=True)}"><span>{html.escape(row["source"])}</span></a>')
    (PACK/'index.html').write_text('<!doctype html><meta charset="utf-8"><title>Leo Racer 2.7 Ultra Media Pack</title><style>body{background:#101923;color:#f3e5ca;font:16px Arial;padding:28px}main{display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:18px}.card{color:#43e7ef;padding:12px;border:1px solid #456;border-radius:12px;overflow:hidden}img{width:100%;height:190px;object-fit:contain;background:repeating-conic-gradient(#202c38 0% 25%,#2b3948 0% 50%) 50%/24px 24px}span{display:block;overflow-wrap:anywhere;margin-top:10px}</style><h1>Leo Racer · 2.7 Ultra</h1><p>Original assets, transparent car renders, real game captures and website copies. Read README.md for attribution and download guidance.</p><main>'+''.join(cards)+'</main>',encoding='utf-8')
    ZIP.parent.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(ZIP,'w',zipfile.ZIP_DEFLATED,compresslevel=4) as archive:
        for path in sorted(PACK.rglob('*')):
            if path.is_file():archive.write(path,PACK.name+'/'+path.relative_to(PACK).as_posix())
    shutil.copy2(ZIP,PACK.parent/ZIP.name)
    print('ULTRA_MEDIA_PACK',len(rows),'original assets',ZIP.stat().st_size,'bytes',flush=True)

if __name__=='__main__':build()
