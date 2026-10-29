"""Publish a verified local artifact manifest; authentication uses Git's credential helper."""
from pathlib import Path
import argparse, hashlib, http.client, json, os, subprocess, urllib.parse, urllib.request, urllib.error
ROOT=Path(__file__).resolve().parents[1]
REPO='amilapcsgit/Leo_Racer'

def main():
    p=argparse.ArgumentParser();p.add_argument('--manifest',type=Path,required=True);p.add_argument('--notes',type=Path,required=True);p.add_argument('--publish',action='store_true');p.add_argument('--title');a=p.parse_args()
    manifest=json.loads(a.manifest.read_text(encoding='utf-8'));version=manifest['version'];tag='v'+version;commit=manifest['commit'];files=[]
    for row in manifest['files']:
        assert Path(row['name']).name==row['name']
        file=a.manifest.parent/row['name'];assert file.stat().st_size==row['bytes']
        with file.open('rb') as stream:assert hashlib.file_digest(stream,'sha256').hexdigest()==row['sha256']
        files.append((file,row))
    assert files and len(commit)==40
    if not a.publish:print('RELEASE_MANIFEST_VERIFIED',tag,len(files));return
    remote=subprocess.check_output(['git','remote','get-url','origin'],cwd=ROOT,text=True).strip();assert REPO in remote
    os.environ['GIT_TERMINAL_PROMPT']='0';os.environ['GCM_INTERACTIVE']='never'
    result=subprocess.run(['git','credential','fill'],cwd=ROOT,input='protocol=https\nhost=github.com\n\n',capture_output=True,text=True,timeout=30)
    credentials=dict(line.split('=',1) for line in result.stdout.splitlines() if '=' in line)
    token=credentials.get('password');assert token,'GitHub credential unavailable'
    headers={'Authorization':'Bearer '+token,'Accept':'application/vnd.github+json','User-Agent':'LeoRacer-release','X-GitHub-Api-Version':'2022-11-28'}
    def api(path,method='GET',data=None,missing=False):
        request=urllib.request.Request('https://api.github.com/repos/'+REPO+path,method=method,headers=headers,data=None if data is None else json.dumps(data).encode())
        if data is not None:request.add_header('Content-Type','application/json')
        try:
            with urllib.request.urlopen(request,timeout=90) as response:return json.load(response) if response.status!=204 else None
        except urllib.error.HTTPError as error:
            if missing and error.code==404:return None
            raise RuntimeError('GitHub API '+method+' '+path+' returned '+str(error.code)) from None
    assert api('/commits/'+commit)['sha']==commit
    ref=api('/git/ref/tags/'+tag,missing=True)
    if ref:
        obj=ref['object'];actual=api('/git/tags/'+obj['sha'])['object']['sha'] if obj['type']=='tag' else obj['sha'];assert actual==commit,'Existing tag points elsewhere'
    else:api('/git/refs','POST',{'ref':'refs/tags/'+tag,'sha':commit})
    release=api('/releases/tags/'+tag,missing=True)
    if not release:
        # GitHub's by-tag endpoint omits unpublished drafts. Resume through the
        # authenticated collection instead of creating a second draft on retry.
        drafts=[row for row in api('/releases?per_page=100') if row.get('draft') and row.get('tag_name')==tag]
        if len(drafts)>1:raise RuntimeError('Multiple drafts for '+tag+'; resolve them before publishing')
        if drafts:release=drafts[0]
    if not release:release=api('/releases','POST',{'tag_name':tag,'target_commitish':commit,'name':a.title or 'Leo Racer '+version+' — Modular Content','body':a.notes.read_text(encoding='utf-8'),'draft':True,'prerelease':False})
    existing={row['name']:row for row in release['assets']}
    if not release['draft']:
        assert all(row['name'] in existing and existing[row['name']]['size']==row['bytes'] for _,row in files),'Public release differs; refusing replacement'
        print('RELEASE_ALREADY_PUBLIC',release['html_url']);return
    for file,row in files:
        old=existing.get(file.name)
        if old and old.get('digest')=='sha256:'+row['sha256'] and old['size']==row['bytes']:print('UPLOAD_ALREADY_VERIFIED',file.name);continue
        if old:api('/releases/assets/'+str(old['id']),'DELETE')
        url=urllib.parse.urlsplit(release['upload_url'].split('{')[0]);path=url.path+'?'+urllib.parse.urlencode({'name':file.name})
        connection=http.client.HTTPSConnection(url.hostname,timeout=600);connection.putrequest('POST',path)
        for name,value in headers.items():connection.putheader(name,value)
        connection.putheader('Content-Type','application/octet-stream');connection.putheader('Content-Length',str(row['bytes']));connection.endheaders()
        with file.open('rb') as stream:
            sent=0;last_progress=0
            while chunk:=stream.read(4*1024*1024):
                connection.send(chunk);sent+=len(chunk)
                if sent-last_progress>=64*1024*1024:
                    print('UPLOAD_PROGRESS',file.name,str(sent)+'/'+str(row['bytes']),flush=True);last_progress=sent
        response=connection.getresponse();body=response.read();connection.close()
        if response.status!=201:raise RuntimeError('Asset upload failed: '+file.name+' HTTP '+str(response.status))
        uploaded=json.loads(body);assert uploaded['size']==row['bytes'] and uploaded.get('digest')=='sha256:'+row['sha256'],'Server asset hash mismatch'
        print('UPLOAD_VERIFIED',file.name,flush=True)
    uploaded=api('/releases/'+str(release['id']));assets={row['name']:row for row in uploaded['assets']}
    assert all(assets[row['name']].get('digest')=='sha256:'+row['sha256'] for _,row in files)
    release=api('/releases/'+str(release['id']),'PATCH',{'draft':False,'prerelease':False,'make_latest':'true','body':a.notes.read_text(encoding='utf-8')})
    assert not release['draft'] and api('/releases/latest')['tag_name']==tag
    print('RELEASE_PUBLISHED',release['html_url'])
if __name__=='__main__':main()
