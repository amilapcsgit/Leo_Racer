"""Focused regression check for corrupted player-facing punctuation."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[1]
markers=['\u00e2\u20ac','\u00c2\u00b7','\ufffd']
errors=[]
for path in (ROOT/'scripts').rglob('*.gd'):
    text=path.read_text(encoding='utf-8')
    for marker in markers:
        if marker in text:errors.append(str(path.relative_to(ROOT))+': '+repr(marker))
main=(ROOT/'scripts/main.gd').read_text(encoding='utf-8')
for words in ['Loading garage catalog…','Preparing interface…','Preparing racers…',' · 3 laps']:
    if words not in main:errors.append('Missing correct copy: '+words)
report={'status':'PASS' if not errors else 'FAIL','utf8':True,'errors':errors}
destination=ROOT/'build/kandy231/text.json';destination.parent.mkdir(parents=True,exist_ok=True);destination.write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report));raise SystemExit(bool(errors))
