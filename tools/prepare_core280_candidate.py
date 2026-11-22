"""Create a local native QA copy; preserve the original release and its content."""
import argparse
import json
import os
import re
import shutil
import subprocess
from pathlib import Path
import city_packs
from package_ultra import inject_checks
from stage_ultra_content import ROOT, sha


def prepare(label, source=None):
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.-]*', label) or label in {'.','..'}:
        raise ValueError('Use a simple candidate label, without path separators')
    source = Path(source).resolve() if source else ROOT / 'build/Release-2.8.0-Ultra'
    target = ROOT / 'build/qa280/native-candidates' / label
    if target.exists():
        raise RuntimeError('Preserve existing QA candidate: ' + str(target))
    def link(src, dst):
        try:
            os.link(src, dst)
        except OSError:
            shutil.copy2(src, dst)
        return str(dst)
    shutil.copytree(source, target, copy_function=link,
                    ignore=shutil.ignore_patterns('LeoRacer.pck', 'QA', '*.log', 'race-test.json', 'smoke-test.json'))
    engine, entries = city_packs.read_pack(source / 'LeoRacer.pck')
    changed = {}
    for folder, suffix in [('scripts', '*.gd'), ('shaders', '*.gdshader')]:
        for path in (ROOT / folder).rglob(suffix):
            key = path.relative_to(ROOT).as_posix()
            entries.pop(key + '.remap', None)
            entries[key] = path.read_bytes()
            changed[key] = sha(path)
    inject_checks(entries)
    city_packs.write_pack(target / 'LeoRacer.pck', engine, entries)
    report = {'purpose':'local native QA candidate, not a published release',
              'base_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
              'core_sha256':sha(target/'LeoRacer.pck'), 'source_scripts':changed,
              'original_core_sha256':sha(source/'LeoRacer.pck'),
              'content_catalog_sha256':sha(target/'GameAssets/catalog.json')}
    (target/'qa-candidate.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(target,flush=True)
    return target


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('label')
    parser.add_argument("--source", type=Path)
    args = parser.parse_args()
    prepare(args.label, args.source)
