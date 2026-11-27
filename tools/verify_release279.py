"""Independently stream published assets and verify their local release hashes."""
from pathlib import Path
import argparse, hashlib, json, time, urllib.request

ROOT = Path(__file__).resolve().parents[1]
REPO = 'amilapcsgit/Leo_Racer'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--manifest', type=Path, default=ROOT / 'dist/release-2.7.9/release-manifest.json')
    args = parser.parse_args()
    manifest = json.loads(args.manifest.read_text(encoding='utf-8'))
    tag = 'v' + manifest['version']
    headers = {'User-Agent': 'LeoRacer-release-verifier', 'Accept': 'application/vnd.github+json'}
    def api(path):
        with urllib.request.urlopen(urllib.request.Request('https://api.github.com/repos/' + REPO + path, headers=headers), timeout=90) as response:
            return json.load(response)
    release = api('/releases/latest')
    assert release['tag_name'] == tag and not release['draft'] and not release['prerelease']
    ref = api('/git/ref/tags/' + tag)['object']
    commit = api('/git/tags/' + ref['sha'])['object']['sha'] if ref['type'] == 'tag' else ref['sha']
    assert commit == manifest['commit'], 'Published tag differs from tested source commit'
    assets = {row['name']: row for row in release['assets']}
    checks = []
    for expected in manifest['files']:
        asset = assets[expected['name']]
        assert asset['size'] == expected['bytes'] and asset.get('digest') == 'sha256:' + expected['sha256']
        digest = hashlib.sha256()
        count = 0
        began = time.monotonic()
        request = urllib.request.Request(asset['browser_download_url'], headers={'User-Agent': 'LeoRacer-release-verifier'})
        with urllib.request.urlopen(request, timeout=600) as response:
            assert response.status == 200
            while chunk := response.read(4 * 1024 * 1024):
                digest.update(chunk)
                count += len(chunk)
        assert count == expected['bytes'] and digest.hexdigest() == expected['sha256'], 'Public download mismatch: ' + expected['name']
        row = {'name': expected['name'], 'bytes': count, 'sha256': digest.hexdigest(), 'seconds': round(time.monotonic() - began, 2), 'download_verified': True}
        checks.append(row)
        print('PUBLIC_DOWNLOAD_VERIFIED', expected['name'], count, flush=True)
    out = ROOT / 'build/qa279/public-release.json'
    out.write_text(json.dumps({'status': 'PASS', 'tag': tag, 'commit': commit, 'url': release['html_url'], 'latest': True, 'assets': checks}, indent=2), encoding='utf-8')
    print('PUBLIC_RELEASE_VERIFIED', release['html_url'])


if __name__ == '__main__':
    main()
