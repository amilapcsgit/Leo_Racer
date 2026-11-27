"""Build the offline engine loops from the supplied RPM-indexed WAV library."""
from array import array
from hashlib import file_digest
from pathlib import Path
import argparse
import json
import math
import subprocess
import wave

RATE = 24000
PROFILES = {
    "small": ("CJX_ENG", "CJX_EXH", [900, 1900, 3100, 4500, 5900]),
    "suv": ("FSI_ENG", "FSI_EXH", [900, 1800, 2850, 4050, 5500]),
    "sport": ("EJ257_ENG_STOCK_ECU", "EJ257_EXH_STOCK_ECU", [950, 2200, 3400, 5000, 6500]),
    "bus": ("GM_LT1_ENG", "GM_LT1_EXH", [820, 1450, 2300, 3050, 3900]),
}


def read_table(source, blend):
    data = json.loads((source / "blends" / f"{blend}.sfxBlend2D.json").read_text(encoding="utf-8-sig"))
    return [
        sorted((float(rpm), source / path.removeprefix("art/sound/")) for path, rpm, *_ in bank
               if (source / path.removeprefix("art/sound/")).is_file())
        for bank in data["samples"][:2]
    ]


def samples(ffmpeg, path, rate=RATE):
    command = [ffmpeg, "-hide_banner", "-loglevel", "error", "-i", str(path), "-ac", "1",
               "-ar", str(rate), "-f", "f32le", "-"]
    result = array("f")
    result.frombytes(subprocess.check_output(command))
    return result


def prepare(ffmpeg, bank, target):
    rpm, path = min(bank, key=lambda item: abs(math.log(item[0] / target)))
    data = samples(ffmpeg, path, round(RATE * rpm / target))
    midpoint = len(data) // 2
    half = min(midpoint, RATE)
    data = data[midpoint - half:midpoint + half]
    overlap = min(int(RATE * .045), len(data) // 5)
    for i in range(overlap):
        ease = .5 - .5 * math.cos(math.pi * i / overlap)
        data[i] = data[len(data) - overlap + i] * (1. - ease) + data[i] * ease
    return data[:-overlap], path


def smooth_wrap(pcm, rate):
    """Join both sides of a loop at the same level with a short raised-cosine blend."""
    span = min(round(rate * .003), len(pcm) // 4)
    if span < 2:
        return
    midpoint = round((pcm[0] + pcm[-1]) / 2)
    for index in range(span):
        weight = .5 + .5 * math.cos(math.pi * index / (span - 1))
        for sample in (index, -1 - index):
            pcm[sample] = round(pcm[sample] * (1 - weight) + midpoint * weight)


def write_loop(output, values):
    average = sum(values) / len(values)
    peak = max(abs(sample - average) for sample in values)
    pcm = array("h", (round((sample - average) / max(.02, peak) * 19000) for sample in values))
    smooth_wrap(pcm, RATE)
    with wave.open(str(output), "wb") as file:
        file.setparams((1, 2, RATE, len(pcm), "NONE", "not compressed"))
        file.writeframes(pcm.tobytes())


def sha(path):
    with path.open("rb") as file:
        return file_digest(file, "sha256").hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("ffmpeg")
    parser.add_argument("--tire", type=Path)
    args = parser.parse_args()
    source = args.source
    output = Path(__file__).resolve().parents[1] / "assets/audio/vehicle280"
    output.mkdir(parents=True, exist_ok=True)
    manifest = {"profiles": {}, "recordings": {}, "tire": {}}
    for profile, (engine, exhaust, ranges) in PROFILES.items():
        engine_rows = read_table(source, engine)
        exhaust_rows = read_table(source, exhaust)
        rows = []
        for rpm in ranges:
            row = {"rpm": rpm}
            for bank, name in [(0, "on"), (1, "off")]:
                on = engine_rows[min(bank, len(engine_rows) - 1)] or engine_rows[0]
                ex = exhaust_rows[min(bank, len(exhaust_rows) - 1)] or exhaust_rows[0]
                engine_loop, eng_source = prepare(args.ffmpeg, on, rpm)
                exhaust_loop, exh_source = prepare(args.ffmpeg, ex, rpm)
                # Equalize the lengths and close the composite seam after layering.
                length = max(len(engine_loop), len(exhaust_loop))
                result = [engine_loop[i % len(engine_loop)] * .72 + exhaust_loop[i % len(exhaust_loop)] * .42
                          for i in range(length)]
                tail = min(int(RATE * .035), length // 5)
                for i in range(tail):
                    blend = i / tail
                    result[i] = result[length - tail + i] * (1. - blend) + result[i] * blend
                filename = f"{profile}_{rpm}_{name}.wav"
                write_loop(output / filename, result[:-tail])
                row[name] = filename
                manifest["recordings"][filename] = {
                    "source": [path.relative_to(source).as_posix() for path in (eng_source, exh_source)],
                    "source_sha256": [sha(path) for path in (eng_source, exh_source)],
                    "sha256": sha(output / filename),
                }
            rows.append(row)
        manifest["profiles"][profile] = rows
    if args.tire and args.tire.is_file():
        for name, cutoff in [("squeal", ""), ("scrub", "lowpass=f=1100")]:
            target = output / f"tire_{name}.wav"
            filters = ["-af", cutoff] if cutoff else []
            subprocess.run([args.ffmpeg, "-hide_banner", "-loglevel", "error", "-y", "-i", str(args.tire),
                            *filters, "-ar", str(RATE), "-ac", "1", str(target)], check=True)
            manifest["tire"][name] = target.name
        manifest["tire_credit"] = {"name": "Car tire squeal skid loop", "author": "Tom Haigh (audible-edge), loop by qubodup",
                                   "license": "CC BY 3.0", "url": "https://lpc.opengameart.org/content/car-tire-squeal-skid-loop",
                                   "changes": "Mono 24 kHz conversion; low-pass treatment for scrub"}
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Prepared {len(manifest['recordings'])} engine loops and {len(manifest['tire'])} tire layers")


if __name__ == "__main__":
    main()
