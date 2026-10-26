"""Run the exported-content acceptance suite with isolated profiles."""
import json, subprocess, sys
from qa_kandy231 import ROOT,run
from verify_release_231 import game
ARGS=['--track=kandy_lake','--tracks=build/kandy231/tracks']
def main():
 for name in ['surface','landmark','material','malformed','streaming','race']:
  assert run('res://tests/kandy_'+name+'_test.gd','final-'+name,ARGS),name
 assert run('res://tests/kandy_race_test.gd','final-race-single',ARGS+['--single-player'])
 assert run('res://tests/kandy231_presentation_test.gd','presentation-final',ARGS,headless=False)
 subprocess.run([sys.executable,str(ROOT/'tools/check_kandy231_text.py')],check=True)
 for mode,marker in [('verify-boot-art','BOOT_ART_VALIDATION'),('verify-content','CONTENT_VALIDATION_OK'),('ui-smoke-test','UI_PACKAGE_SMOKE')]:
  output=game(['--'+mode],'final-'+mode);assert marker in output and '"status":"FAIL"' not in output
 print('KANDY231_ACCEPTANCE_PASS',flush=True)
if __name__=='__main__':main()
