"""Update only the default-branch README after the release is public."""
from pathlib import Path
import argparse, base64, json, os, re, subprocess, urllib.request
ROOT=Path(__file__).resolve().parents[1]
REPO='amilapcsgit/Leo_Racer'

def main():
    p=argparse.ArgumentParser();p.add_argument('--publish',action='store_true');a=p.parse_args()
    text=(ROOT/'README.md').read_text(encoding='utf-8')
    def pin(match):
        image,label,url=match.groups()
        if url.startswith(('http:','https:','#','mailto:')):return match.group(0)
        base='https://raw.githubusercontent.com/'+REPO+'/v2.3.2/' if image else 'https://github.com/'+REPO+'/blob/v2.3.2/'
        return image+'['+label+']('+base+url+')'
    text=re.sub(r'(!?)\[([^\]]+)\]\(([^)]+)\)',pin,text)
    target=ROOT/'build/release232/default-readme-target.md';target.write_text(text,encoding='utf-8')
    if not a.publish:print('DEFAULT_README_PREPARED',target);return
    state=json.loads((ROOT/'build/release232/github-state.json').read_text(encoding='utf-8'))
    os.environ['GIT_TERMINAL_PROMPT']='0';os.environ['GCM_INTERACTIVE']='never'
    result=subprocess.run(['git','credential','fill'],cwd=ROOT,input='protocol=https\nhost=github.com\n\n',capture_output=True,text=True,timeout=30)
    credential=dict(line.split('=',1) for line in result.stdout.splitlines() if '=' in line)
    assert credential.get('password'),'GitHub credential unavailable'
    headers={'Authorization':'Bearer '+credential['password'],'Accept':'application/vnd.github+json','User-Agent':'LeoRacer-release'}
    def api(path,method='GET',data=None):
        req=urllib.request.Request('https://api.github.com/repos/'+REPO+path,headers=headers,method=method,data=None if data is None else json.dumps(data).encode())
        if data is not None:req.add_header('Content-Type','application/json')
        with urllib.request.urlopen(req,timeout=90) as r:return json.load(r)
    release=api('/releases/latest');assert release['tag_name']=='v2.3.2' and any(r['name']=='LeoRacer-Setup.exe' for r in release['assets'])
    branch=state['default_branch'];old=api('/contents/README.md?ref='+branch)
    if base64.b64decode(old['content']).decode()==text:print('DEFAULT_README_ALREADY_CURRENT');return
    assert old['sha']==state['readme_sha'],'README changed concurrently; preserve and review it before updating'
    result=api('/contents/README.md','PUT',{'message':'Update latest Windows download button and v2.3.2 features','branch':branch,'sha':old['sha'],'content':base64.b64encode(text.encode()).decode()})
    check=api('/contents/README.md?ref='+branch);assert base64.b64decode(check['content']).decode()==text
    print('DEFAULT_README_UPDATED',result['commit']['html_url'])

if __name__=='__main__':main()
