"""Functional checks of the final Windows export with development SDK paths removed."""
from pathlib import Path
import json
import verify_distinct as verify
from release26_final import BASE,Q,sha,dump
R=Path(__file__).resolve().parents[1]
verify.QA=Q/'export';verify.QA.mkdir(parents=True,exist_ok=True)

def run():
 results=[]
 for label,args in [('boot-art',['--verify-boot-art']),('content',['--verify-content'])]:
  results.append(verify.run(label,BASE,args=args,timeout=600))
 for compat in [False,True]:
  renderer='compatibility' if compat else 'forward'
  results.append(verify.run('smoke-'+renderer,BASE,args=['--smoke-test'],render=True,compat=compat,timeout=900))
  results.append(verify.run('content-'+renderer,BASE,args=['--release-content-check'],render=True,compat=compat,timeout=600))
  results.append(verify.run('polish-'+renderer,BASE,args=['--release-polish-check'],render=True,compat=compat,timeout=900))
  results.append(verify.run('ui-'+renderer,BASE,args=['--release-ui-check'],render=True,compat=compat,timeout=900))
 assert all(results)
 dump(Q/'export-smoke.json',{'status':'PASS','core_sha256':sha(BASE/'LeoRacer.pck'),'sdk_removed':True,'checks':len(results),'native_ui_renderers':2,'native_content_renderers':2})

if __name__=='__main__':run()
