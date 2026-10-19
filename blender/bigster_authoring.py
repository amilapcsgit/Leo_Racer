"""Create editable Blender copies of the self-contained runtime derivatives.
Run after tools/prepare_bigster_assets.py and prepare_bigster_driver.py.
"""
from pathlib import Path
import bpy
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/bigster-authoring';OUT.mkdir(parents=True,exist_ok=True)
for name in ['duster','bigster','colombo_tuk','driver_human_seated','driver_human_cabin']:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(ROOT/f'assets/models/bigster/{name}.glb'))
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/f'{name}.blend'))
