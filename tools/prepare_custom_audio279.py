"""Prepare user-supplied 2.7.9 music without altering source recordings.

Requires NumPy and the repository's bundled FFmpeg; no network or audio service.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import subprocess
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
FFMPEG = ROOT / '.tools/media/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe'
OUTPUT = ROOT / 'assets/audio/custom279'
QA = ROOT / 'build/qa279/custom-audio'
RATE = 48000
CHANNELS = 2
TARGET_LUFS = -18.0
MASTER_TRUE_PEAK = -2.3  # Reserve a little headroom for Vorbis reconstruction.
SEAM_LIMIT = 0.025
SOURCES = [
    ('intro_main', 'Leo Racer Intro menu garage continus loading audio.mp3', 'Leo Racer Intro'),
    ('intro_alt', 'additional intro to shuffle Colombo Grand Prix.mp3', 'Colombo Grand Prix Intro'),
    ('kandy_race', 'Kandy sound track.mp3', 'Kandy Soundtrack'),
    ('coast_race', 'astra lotus Colombo Grand-prix.mp3', 'Astra Lotus Colombo Grand Prix'),
]


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(arguments: list[str], payload: bytes | None = None) -> subprocess.CompletedProcess:
    process = subprocess.run([str(FFMPEG), '-nostdin', '-hide_banner', *arguments],
                             input=payload, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if process.returncode:
        raise RuntimeError(process.stderr.decode('utf-8', errors='replace')[-6000:])
    return process


def decode(path: Path) -> np.ndarray:
    process = run(['-v', 'error', '-i', str(path), '-map', '0:a:0', '-vn',
                   '-ac', str(CHANNELS), '-ar', str(RATE), '-f', 'f32le', 'pipe:1'])
    samples = np.frombuffer(process.stdout, dtype='<f4').reshape((-1, CHANNELS)).copy()
    if len(samples) < RATE or not np.isfinite(samples).all():
        raise ValueError(f'Invalid or incomplete audio: {path.name}')
    return samples


def level_db(samples: np.ndarray) -> float:
    return round(20.0 * math.log10(max(1e-12, float(np.sqrt(np.mean(samples.astype(np.float64) ** 2))))), 4)


def seam(samples: np.ndarray) -> dict:
    window = min(int(RATE * .05), len(samples) // 2)
    return {
        'boundary_max_sample_delta': round(float(np.max(np.abs(samples[0] - samples[-1]))), 8),
        'head_50ms_rms_dbfs': level_db(samples[:window]),
        'tail_50ms_rms_dbfs': level_db(samples[-window:]),
    }


def prepare_loop(samples: np.ndarray) -> tuple[np.ndarray, dict]:
    # Preserve authored rests and bar duration. FFmpeg already respects MP3
    # gapless delay/padding metadata; silence alone is not proof of padding.
    if not np.any(np.abs(samples) > 1e-5):
        raise ValueError('Source contains only silence')
    result = samples.copy()
    before = seam(result)
    overlap = 0
    if before['boundary_max_sample_delta'] > .015:
        # A short circular overlap joins the end to the beginning. The finished
        # boundary is two originally adjacent samples, not a hard cut to zero.
        overlap = min(int(.08 * RATE), len(result) // 10)
        weight = (.5 - .5 * np.cos(np.linspace(0., math.pi, overlap))).astype(np.float32)[:, None]
        join = result[-overlap:] * (1. - weight) + result[:overlap] * weight
        result = np.concatenate((result[overlap:-overlap], join), axis=0)
    return result, {
        'digital_silence_trim_start_samples': 0,
        'digital_silence_trim_end_samples': 0,
        'duration_policy': 'Authored rests and full decoded duration retained, except the reported conditional seam overlap.',
        'circular_crossfade_ms': round(overlap / RATE * 1000., 3),
        'before_loop_preparation': before,
        'prepared_loop': seam(result),
    }


def write_float_wave(path: Path, samples: np.ndarray) -> None:
    run(['-v', 'error', '-y', '-f', 'f32le', '-ar', str(RATE), '-ac', str(CHANNELS),
         '-i', 'pipe:0', '-map_metadata', '-1', '-c:a', 'pcm_f32le', str(path)],
        samples.astype('<f4', copy=False).tobytes())


def loudness(path: Path) -> dict:
    process = run(['-i', str(path), '-map', '0:a:0', '-vn', '-af',
                   f'loudnorm=I={TARGET_LUFS}:TP={MASTER_TRUE_PEAK}:LRA=50:print_format=json',
                   '-f', 'null', '-'])
    text = process.stderr.decode('utf-8', errors='replace')
    matches = re.findall(r'\{\s*"input_i".*?\}', text, flags=re.S)
    if not matches:
        raise ValueError(f'No loudness report for {path.name}')
    return json.loads(matches[-1])


def stream_info(path: Path) -> dict:
    process = run(['-i', str(path), '-map', '0:a:0', '-vn', '-t', '0', '-f', 'null', '-'])
    text = process.stderr.decode('utf-8', errors='replace')
    match = re.search(r'Audio:\s+([^,]+),\s+(\d+)\s+Hz,\s+(mono|stereo)', text)
    if not match:
        raise ValueError(f'Cannot verify encoded stream format: {path.name}')
    return {'codec': match.group(1), 'sample_rate': int(match.group(2)),
            'channels': 2 if match.group(3) == 'stereo' else 1}


def encode(source_wave: Path, target: Path, title: str, measured: dict, extra_gain: float = 0.) -> str:
    normalizer = (
        f'loudnorm=I={TARGET_LUFS}:TP={MASTER_TRUE_PEAK}:LRA=50:'
        f'measured_I={measured["input_i"]}:measured_TP={measured["input_tp"]}:'
        f'measured_LRA={measured["input_lra"]}:measured_thresh={measured["input_thresh"]}:'
        f'offset={measured["target_offset"]}:linear=true'
    )
    filters = normalizer + (f',volume={extra_gain:.5f}dB' if extra_gain else '')
    run(['-v', 'error', '-y', '-i', str(source_wave), '-map', '0:a:0', '-vn',
         '-map_metadata', '-1', '-af', filters, '-ac', str(CHANNELS), '-ar', str(RATE),
         '-c:a', 'libvorbis', '-q:a', '6', '-flags:a', '+bitexact', '-fflags', '+bitexact',
         '-metadata', f'title={title}', '-metadata', 'comment=User-supplied custom soundtrack; source retained',
         str(target)])
    return filters


def process_track(track_id: str, source: Path, title: str, supplied: bool) -> dict:
    source_hash = digest(source)
    decoded = decode(source)
    prepared, loop_report = prepare_loop(decoded)
    wave = QA / f'{track_id}.prepared.wav'
    write_float_wave(wave, prepared)
    source_levels = loudness(source)
    measured = loudness(wave)
    target = OUTPUT / f'{track_id}.ogg'
    filters = encode(wave, target, title, measured)
    encoded_levels = loudness(target)
    # Check the decoded lossy result, rather than relying on pre-encode peaks.
    peak = float(encoded_levels['input_tp'])
    if peak > -2.0:
        filters = encode(wave, target, title, measured, -2.1 - peak)
        encoded_levels = loudness(target)
    final = decode(target)
    encoded_stream = stream_info(target)
    boundary = seam(final)
    report = {
        'id': track_id,
        'title': title,
        'file': target.relative_to(ROOT).as_posix(),
        'source_filename': source.name,
        'source_sha256': source_hash,
        'sha256': digest(target),
        'credit': 'User-supplied custom soundtrack' if supplied else 'Existing Leo Racer project soundtrack',
        'license_statement': 'No CC0 dedication or new third-party license grant is asserted.' if supplied else 'Existing project provenance retained; no new license asserted.',
        'sample_rate': RATE,
        'channels': CHANNELS,
        'source_decoded_seconds': round(len(decoded) / RATE, 6),
        'seconds': round(len(final) / RATE, 6),
        'sample_count': len(final),
        'processing': filters,
        'loop_preparation': loop_report,
        'source_loudness': source_levels,
        'encoded_loudness': encoded_levels,
        'encoded_stream': encoded_stream,
        'encoded_seam': boundary,
        'validation': {
            'complete_decode': bool(np.isfinite(final).all()),
            'actual_vorbis_48000_stereo': encoded_stream == {'codec': 'vorbis', 'sample_rate': RATE, 'channels': CHANNELS},
            'true_peak_at_most_minus_2_dbtp': float(encoded_levels['input_tp']) <= -2.0,
            'integrated_loudness_within_half_lu': abs(float(encoded_levels['input_i']) - TARGET_LUFS) <= .5,
            'click_free_boundary': boundary['boundary_max_sample_delta'] <= SEAM_LIMIT,
            'source_unchanged': digest(source) == source_hash,
        },
    }
    if not all(report['validation'].values()):
        (QA / f'{track_id}.failed.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
        raise ValueError(f'Audio validation failed: {track_id}: {report["validation"]}')
    print(f'CUSTOM_AUDIO {track_id} {report["seconds"]:.2f}s '
          f'{encoded_levels["input_i"]} LUFS {encoded_levels["input_tp"]} dBTP '
          f'seam={boundary["boundary_max_sample_delta"]:.6f}', flush=True)
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--downloads', type=Path, default=Path.home() / 'Downloads')
    args = parser.parse_args()
    jobs = [(key, args.downloads / name, title, True) for key, name, title in SOURCES]
    jobs.append(('island_original', ROOT / 'assets/audio/island_music.wav', 'Island Music / Original Leo Racer', False))
    missing = [str(source) for _, source, _, _ in jobs if not source.is_file()]
    if missing:
        raise FileNotFoundError('Missing original audio: ' + '; '.join(missing))
    OUTPUT.mkdir(parents=True, exist_ok=True)
    QA.mkdir(parents=True, exist_ok=True)
    rows = [process_track(*job) for job in jobs]
    retained = ROOT / 'assets/audio/menu279/ceylon_afterglow.ogg'
    manifest = {
        'version': '2.7.9',
        'method': 'Offline resampling, conditional short circular seam blend, two-pass loudness normalization, and Ogg Vorbis encoding. No source MP3 or WAV is modified.',
        'target_lufs': TARGET_LUFS,
        'maximum_true_peak_dbtp': -2.0,
        'sample_rate': RATE,
        'channels': CHANNELS,
        'files': rows,
        'retained_original_theme': {'file': retained.relative_to(ROOT).as_posix(), 'sha256': digest(retained)},
    }
    serialized = json.dumps(manifest, indent=2, ensure_ascii=False) + '\n'
    (OUTPUT / 'manifest.json').write_text(serialized, encoding='utf-8')
    (ROOT / 'licenses/customaudio279.json').write_text(serialized, encoding='utf-8')
    (QA / 'report.json').write_text(serialized, encoding='utf-8')
    lines = ['# Leo Racer 2.7.9 custom soundtrack', '',
             'The four MP3 recordings below were supplied by the user. They are credited as **User-supplied custom soundtrack**. This conversion does not dedicate these recordings to CC0 or assert a new third-party license grant.', '',
             '| Game ID | Original recording |', '|---|---|']
    lines.extend(f'| `{key}` | {name} |' for key, name, _ in SOURCES)
    lines += ['', '`island_original.ogg` is a conversion of the existing project `assets/audio/island_music.wav`; its original project provenance remains unchanged. The existing original Ceylon Afterglow theme remains at `assets/audio/menu279/ceylon_afterglow.ogg`.', '',
              'All five converted files use 48 kHz stereo Ogg Vorbis. Two-pass normalization targets −18 LUFS; decoded Vorbis outputs are checked for true peaks at or below −2 dBTP. A conditional 80 ms circular overlap removes a discontinuous loop boundary; musical arrangement, pitch, tempo, and source character are retained.', '',
              'Original MP3s remain in Downloads and the project WAV remains untouched. `customaudio279.json` records their original SHA-256 hashes, output hashes, preparation steps, full loudness measurements, and decoded loop-boundary checks.', '',
              'Rebuild with the bundled Python/NumPy runtime: `python tools/prepare_custom_audio279.py --downloads "<your Downloads folder>"`.']
    (ROOT / 'licenses/customaudio279.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print('CUSTOM_AUDIO279 PASS 5 converted tracks; original Ceylon Afterglow retained', flush=True)


if __name__ == '__main__':
    main()
