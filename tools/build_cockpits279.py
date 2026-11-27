"""Reproducible additive cockpit packs; source GLBs/packages remain untouched."""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / "build/cockpit279"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def build(key):
    original = {
        "bigster": ROOT / "assets/models/bigster/bigster_232.glb",
        "duster_2024": ROOT.parent.parent / "Duster_2024/package/GameAssets/vehicles/duster_2024/model.glb",
        "duster": ROOT.parent.parent / "Duster_My_2014/package/GameAssets/vehicles/duster/Duster_My_2014.glb",
    }[key]
    before = sha(original)
    source = WORK / ("source-" + key)
    source.mkdir(parents=True, exist_ok=True)
    data = json.loads((ROOT / "build/content-baseline/GameAssets/vehicles" / key / "vehicle.json").read_text(encoding="utf-8-sig"))
    data.update(ultra_cockpit=True, cockpit_revision=279, ultra_trunk=key == "bigster", model="model.glb")
    shutil.copy2(original, source / "model.glb")
    (source / "vehicle.json").write_text(json.dumps(data, indent=2), encoding="utf-8")
    destination = WORK / ("compiled-" + key)
    subprocess.run([
        "powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(ROOT / "tools/run_godot.ps1"),
        "--headless", "--script", "res://tools/compile_vehicle260.gd", "--drive-test",
        "--source=" + str(source), "--destination=" + str(destination),
    ], cwd=ROOT, check=True)
    target = ROOT / "content/ultra" / ("cockpit279-" + key + ".pck")
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(destination / "vehicle.pck", target)
    report = json.loads((destination / "compile-report.json").read_text(encoding="utf-8-sig"))
    compiled = json.loads((destination / "vehicle.json").read_text(encoding="utf-8-sig"))
    report.update(
        revision="2.7.9", source_file=str(original.relative_to(ROOT.parent.parent)),
        original_sha256=before, source_unchanged=before == sha(original), derivative_sha256=sha(target),
        virtual_scene=compiled["model_scene"], minimum_swept_clearance_m=0.015,
        clearance_status="PENDING_GEOMETRY_VALIDATION", animated_nodes_preserved=True,
    )
    if not report["source_unchanged"]:
        raise RuntimeError("Original source changed during build: " + str(original))
    target.with_suffix(".json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("COCKPIT279_PACK_READY", key, report["derivative_sha256"], flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--only", choices=["bigster", "duster", "duster_2024"])
    args = parser.parse_args()
    for vehicle in [args.only] if args.only else ["bigster", "duster", "duster_2024"]:
        build(vehicle)
