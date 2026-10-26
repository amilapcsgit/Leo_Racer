"""Verify the actual portable ZIP using only its extracted Windows runtime."""
from pathlib import Path
import argparse,json,os,subprocess,zipfile
from release_231 import ROOT,OUT,dump
def main():
 parser=argparse.ArgumentParser();parser.add_argument('--suffix',default='');args=parser.parse_args();assert not args.suffix or args.suffix.isalnum()
 destination=ROOT.parent.parent/'t'/('231-portable'+('-'+args.suffix if args.suffix else ''));assert not destination.exists()
 with zipfile.ZipFile(OUT/'LeoRacer-2.3.1-win64.zip') as archive:
  assert archive.testzip() is None;archive.extractall(destination)
 folder=destination/'LeoRacer';profile=destination/'isolated-userdata';profile.mkdir()
 env=os.environ.copy();env['APPDATA']=env['LOCALAPPDATA']=str(profile);env['DOTNET_ROOT']='';env['PATH']=os.pathsep.join(p for p in env.get('PATH','').split(os.pathsep) if 'dotnet' not in p.lower())
 checks={}
 for mode,marker in [('verify-boot-art','BOOT_ART_VALIDATION'),('verify-content','CONTENT_VALIDATION_OK'),('ui-smoke-test','UI_PACKAGE_SMOKE')]:
  result=subprocess.run([str(folder/'LeoRacer.console.exe'),'--headless','--','--'+mode,'--qa-output='+str(destination/'qa')],cwd=folder,env=env,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=240)
  log=result.stdout+result.stderr;(ROOT/'build/kandy231'/('portable-'+mode+'.log')).write_text(log,encoding='utf-8')
  assert result.returncode==0 and marker in log and 'SCRIPT ERROR' not in log and '"status":"FAIL"' not in log,(mode,log[-1500:]);checks[mode]='PASS'
 dump(ROOT/'build/kandy231/portable.json',{'status':'PASS','checks':checks,'self_contained_dotnet':True,'source_archive':'LeoRacer-2.3.1-win64.zip'})
 print('PORTABLE_231_PASS')
if __name__=='__main__':main()
