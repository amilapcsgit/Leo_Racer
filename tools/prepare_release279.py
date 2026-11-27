"""One-time integration of the 2.7.9 candidate; previous builds are untouched."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def edit(name,changes):
    path=ROOT/name;text=path.read_text(encoding='utf-8')
    for old,new in changes:
        if new in text:continue
        if old in text:text=text.replace(old,new)
        elif new not in text:raise RuntimeError(f'{name}: expected integration anchor missing: {old[:80]}')
    path.write_text(text,encoding='utf-8')
def main():
    edit('project.godot',[('config/version="2.7.8"','config/version="2.7.9"')])
    edit('export_presets.cfg',[('version="2.7.8"','version="2.7.9"'),('assets/audio/racing278/*.json,','assets/audio/racing278/*.json,assets/audio/menu279/*.json,'),('exclude_filter="','exclude_filter="assets/audio/menu279/Ceylon_Afterglow_128.wav,')])
    edit('scripts/content/bootstrap.gd',[('Leo Racer — 2.7.8','Leo Racer — 2.7.9'),('["loading","refinements","perf278"','["ui279","render279","gallery279","loading","refinements","perf278"')])
    edit('scripts/catalog/vehicle_presentation.gd',[(
        'var cockpit_path:="res://cockpit278/"+String(source.id)+"/model.scn"',
        'var cockpit_path:="res://cockpit279/"+String(source.id)+"/model.scn"\n\tif not ResourceLoader.exists(cockpit_path):cockpit_path="res://cockpit278/"+String(source.id)+"/model.scn"')])
    edit('scripts/content/asset_resolver.gd',[(
        'for id in ["bigster","duster_2024"]:\n\t\t\tvar cockpit_pack: String="res://content/ultra/cockpit278-"+id+".pck"',
        'for id in ["bigster","duster","duster_2024"]:\n\t\t\tvar cockpit_pack: String="res://content/ultra/cockpit279-"+id+".pck"\n\t\t\tif not FileAccess.file_exists(cockpit_pack):cockpit_pack="res://content/ultra/cockpit278-"+id+".pck"')])
    edit('tools/ultra_windows.ps1',[('qa278','qa279'),('profile-278','profile-279'),('export278-temp','export279-temp'),('Release-2.7.8-Ultra','Release-2.7.9-Ultra')])
    edit('tools/run_ultra_checks.py',[("'build/qa278'","'build/qa279'"),("TESTS={","TESTS={\n    'ui279':('tests/ui279_test.gd',None),\n    'render279':('tests/render_polish279_test.gd',None),\n    'gallery279':('tests/gallery279_test.gd',None),"),("render=kind in [","render=kind in ['ui279',")])
    edit('tools/package_ultra.py',[("mapping={'loading':","mapping={'ui279':'ui279_test','render279':'render_polish279_test','gallery279':'gallery279_test','loading':"),("for key in ['bigster','duster_2024']:","for key in ['bigster','duster','duster_2024']:"),('cockpit278-','cockpit279-'),("'LEO RACER 2.7.8\\n","'LEO RACER '+VERSION+'\\n"),("'label':'2.7.8'","'label':VERSION"),('build/nsis270','build/nsis279'),("shutil.copy2(ROOT/'assets/audio/racing278/manifest.json',BASE/'GameAssets/licenses/racing-audio-manifest.json')","shutil.copy2(ROOT/'assets/audio/racing278/manifest.json',BASE/'GameAssets/licenses/racing-audio-manifest.json')\n    shutil.copy2(ROOT/'assets/audio/menu279/manifest.json',BASE/'GameAssets/licenses/menu-audio-manifest.json')\n    shutil.copy2(ROOT/'assets/config/loading-gallery-v279.json',BASE/'GameAssets/licenses/loading-gallery-v279.json')")])
    edit('tools/city_packs.py',[("BOOT_ART={'assets/art/menu.png','assets/ui/art/home.png','assets/art/neon_lion.svg'}","BOOT_ART={'assets/art/menu.png','assets/ui/art/home.png','assets/art/neon_lion.svg'}\n_gallery=ROOT/'assets/config/loading-gallery-v279.json'\nif _gallery.exists():BOOT_ART.update(row['path'].removeprefix('res://') for row in json.loads(_gallery.read_text(encoding='utf-8'))['artworks'])")])
    edit('README.md',[('Leo Racer · 2.7.8','Leo Racer · 2.7.9')])
    print('INTEGRATED_279')
if __name__=='__main__':main()
