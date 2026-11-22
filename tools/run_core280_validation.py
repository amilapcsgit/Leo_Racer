"""Serialize core checks and GPU measurements; retain every result in build/qa280."""
import argparse
import json
import os
import time
from stage_ultra_content import ROOT


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--wait-for-profile')
    parser.add_argument('--benchmark', action='store_true')
    parser.add_argument('--label', default='after')
    args = parser.parse_args()
    print('VALIDATION_RUNNER_PID', os.getpid(), flush=True)
    if args.wait_for_profile:
        directory = ROOT / 'build/qa280' / ('profile-' + args.wait_for_profile)
        began = time.monotonic()
        while not all((directory / renderer / 'process.json').exists() for renderer in ['forward', 'compatibility']):
            if time.monotonic()-began > 14400:
                raise RuntimeError('Previous benchmark did not finish within four hours')
            time.sleep(5)
        print('PREVIOUS_PROFILE_COMPLETE', flush=True)
    # Resolve harness modules after the wait, so a queued run uses reviewed tooling.
    from run_ultra_checks import run as check, CORE280_VALIDATION_KINDS, CORE280_NATIVE_VALIDATION_KINDS
    from prepare_core280_candidate import prepare
    from profile_core280 import run as profile
    results = []
    source_kinds = CORE280_VALIDATION_KINDS
    for kind in source_kinds:
        results.append({'mode':'source', 'kind':kind, 'ok':check(kind)})
    target = None
    if all(row['ok'] for row in results):
        target = prepare(args.label)
        for kind in CORE280_NATIVE_VALIDATION_KINDS:
            results.append({'mode':'native', 'kind':kind, 'ok':check(kind, export=target)})
        for compatibility in [False,True]:
            results.append({'mode':'native', 'kind':'environment280', 'compatibility':compatibility,
                            'ok':check('environment280', compat=compatibility, export=target, extra=('--qa-resolution=1920x1080',))})
    output = ROOT / 'build/qa280' / ('validation-' + args.label + '.json')
    output.write_text(json.dumps(results,indent=2), encoding='utf-8')
    if not all(row['ok'] for row in results):
        print('VALIDATION_FAILED', str(output), flush=True)
        return 1
    if args.benchmark:
        for renderer in ['forward', 'compatibility']:
            if not profile(renderer, 'native-' + args.label, export=target):
                return 1
    print('VALIDATION_COMPLETE', str(output), flush=True)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
