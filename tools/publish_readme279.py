"""Pin the release README to v2.7.9 and update only an unchanged default README."""
from pathlib import Path
import argparse, base64, json, os, re, subprocess, urllib.request

ROOT = Path(__file__).resolve().parents[1]
REPO = 'amilapcsgit/Leo_Racer'
TAG = 'v2.7.9'
OUT = ROOT / 'build/release279'


def pinned_readme():
    text = (ROOT / 'README.md').read_text(encoding='utf-8')
    def url(value, image=False):
        if value.startswith(('https:', 'http:', '#', 'mailto:', 'data:')):
            return value
        base = 'https://raw.githubusercontent.com/' if image else 'https://github.com/'
        return base + REPO + ('/' if image else '/blob/') + TAG + '/' + value
    text = re.sub(r'(!?)\[([^\]]+)\]\(([^)]+)\)',
                  lambda m: m[1] + '[' + m[2] + '](' + url(m[3], bool(m[1])) + ')', text)
    # The crest and download badge use HTML in the repository README.
    text = re.sub(r'(\bsrc=")([^"]+)(")', lambda m: m[1] + url(m[2], True) + m[3], text)
    return text


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--snapshot', action='store_true')
    parser.add_argument('--publish', action='store_true')
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    text = pinned_readme()
    (OUT / 'default-readme-target.md').write_text(text, encoding='utf-8')
    if not (args.snapshot or args.publish):
        print('DEFAULT_README_PREPARED', OUT / 'default-readme-target.md')
        return
    os.environ.update(GIT_TERMINAL_PROMPT='0', GCM_INTERACTIVE='never')
    result = subprocess.run(['git', 'credential', 'fill'], cwd=ROOT,
                            input='protocol=https\nhost=github.com\n\n',
                            capture_output=True, text=True, timeout=30, check=True)
    credentials = dict(line.split('=', 1) for line in result.stdout.splitlines() if '=' in line)
    assert credentials.get('password'), 'GitHub credential unavailable'
    headers = {'Authorization': 'Bearer ' + credentials['password'],
               'Accept': 'application/vnd.github+json', 'User-Agent': 'LeoRacer-release'}
    def api(path, method='GET', data=None):
        request = urllib.request.Request('https://api.github.com/repos/' + REPO + path,
                  headers=headers, method=method, data=None if data is None else json.dumps(data).encode())
        if data is not None:
            request.add_header('Content-Type', 'application/json')
        with urllib.request.urlopen(request, timeout=90) as response:
            return json.load(response)
    repo = api('')
    branch = repo['default_branch']
    old = api('/contents/README.md?ref=' + branch)
    state_path = OUT / 'default-readme-state.json'
    if args.snapshot:
        assert not state_path.exists(), 'Preserve the original concurrency snapshot'
        state_path.write_text(json.dumps({'default_branch': branch, 'readme_sha': old['sha']}, indent=2))
        print('DEFAULT_README_SNAPSHOT', branch, old['sha'])
    if args.publish:
        release = api('/releases/latest')
        assert release['tag_name'] == TAG and not release['draft']
        assert any(row['name'] == 'LeoRacer-Setup.exe' for row in release['assets'])
        if base64.b64decode(old['content']).decode('utf-8') == text:
            print('DEFAULT_README_ALREADY_CURRENT')
            return
        state = json.loads(state_path.read_text())
        assert state == {'default_branch': branch, 'readme_sha': old['sha']}, 'Default README changed concurrently; review first'
        result = api('/contents/README.md', 'PUT', {
            'message': 'Present Leo Racer v2.7.9 with tested features and tag-pinned screenshots',
            'branch': branch, 'sha': old['sha'], 'content': base64.b64encode(text.encode()).decode()})
        check = api('/contents/README.md?ref=' + branch)
        assert base64.b64decode(check['content']).decode('utf-8') == text
        print('DEFAULT_README_UPDATED', result['commit']['html_url'])


if __name__ == '__main__':
    main()
