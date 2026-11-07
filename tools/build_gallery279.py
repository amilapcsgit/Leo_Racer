"""Inventory current and older full-screen artwork; keep all source files."""
from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[1]
def main():
    candidates=[]
    for p in sorted((ROOT/'assets/ui/boot').rglob('*.png')):
        candidates.append((p,p.stem.replace('_',' ').title() if 'gallery279' in p.parts else ('Astra Lotus Coast' if 'astra_coast' in p.parts else 'Colombo City' if 'colombo_city' in p.parts else 'Kandy Lake' if 'kandy_lake' in p.parts else 'Leo Racer · Original loading artwork')))
    candidates.append((ROOT/'assets/art/menu.png','Lotus Coast · Original menu artwork'))
    for p in sorted((ROOT/'assets/ui/art').glob('*.png')):
        if p.name.startswith('garage') or p.name=='lighting-skyline.png':continue
        candidates.append((p,'Colombo Motor Club · '+p.stem.replace('-v26','').replace('-',' ').replace('_',' ').title()))
    names={'galle':'Galle Fort','hikkaduwa':'Hikkaduwa Coast','nine_arch':'Nine Arch Bridge · Ella','sigiriya':'Sigiriya','dalada':'Sri Dalada Maligawa · Kandy'}
    rows=[];hashes={};duplicates=[]
    for path,caption in candidates:
        if not path.exists():continue
        digest=hashlib.sha256(path.read_bytes()).hexdigest();relative='res://'+path.relative_to(ROOT).as_posix()
        if digest in hashes:duplicates.append({'path':relative,'identical_to':hashes[digest]});continue
        hashes[digest]=relative
        rows.append({'path':relative,'caption':names.get(path.stem,caption),'sha256':digest,'generation':'2.7.9' if path.stem in names else 'preserved'})
    result={'version':1,'selection':'shared nonrepeating shuffle bag; stable per operation','excluded_by_user':'Garage/workshop backdrops, billboard source art, portraits and icons remain preserved but are not loading heroes.','artworks':rows,'identical_copies':duplicates}
    (ROOT/'assets/config/loading-gallery-v279.json').write_text(json.dumps(result,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    print('GALLERY',len(rows),'unique artworks;',len(duplicates),'identical copies retained')
if __name__=='__main__':main()
