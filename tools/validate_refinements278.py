"""Sequential validation avoids concurrent game/build workloads skewing evidence."""
import subprocess,sys,json
from pathlib import Path
R=Path(__file__).resolve().parents[1]
checks=[('refinements',[]),('refinements',['--compatibility']),('input',[]),('core',[]),('ranking',[]),('race',[]),('unit',[]),('contacts',[]),('audit',[]),('physics',[]),('ui',[]),('ui',['--compatibility']),('polish',[]),('polish',['--compatibility']),('content',[]),('release278',['--compatibility'])]
for kind,args in checks:
 print('VALIDATING',kind,*args,flush=True)
 result=subprocess.run([sys.executable,'tools/run_ultra_checks.py',kind,*args],cwd=R)
 if result.returncode:raise SystemExit(result.returncode)
print('SOURCE_VALIDATION_COMPLETE',len(checks),flush=True)
