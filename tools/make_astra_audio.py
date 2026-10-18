"""Create Leo Racer's original Astra arcade cues using only Python's standard library.

All oscillators, envelopes and arrangements are original procedural compositions;
no recorded or third-party samples are used. Regeneration is deterministic.
Run from any directory: python tools/make_astra_audio.py
"""
from __future__ import annotations

import array
import hashlib
import json
import math
from pathlib import Path
import random
import sys
import wave

RATE = 44100
TAU = math.tau
DESTINATION = Path(__file__).resolve().parents[1] / "assets" / "audio"


def envelope(t: float, duration: float, attack: float = .008, release: float = .07) -> float:
    if not 0 <= t < duration:
        return 0.0
    return min(1.0, t / attack) * min(1.0, (duration-t) / release)


def bell(t: float, hz: float, duration: float, amplitude: float = 1.0) -> float:
    if not 0 <= t < duration:
        return 0.0
    fundamental = math.sin(TAU * hz * t)
    shimmer = .25 * math.sin(TAU * hz * 2.006 * t) + .08 * math.sin(TAU * hz * 4.01 * t)
    return amplitude * (fundamental + shimmer) * math.exp(-t * 8 / duration) * envelope(t, duration)


def synthesize(kind: str) -> list[float]:
    durations = {"select": .20, "lap": .92, "ready": .52, "bus_horn": .72, "tuk_horn": .43}
    duration = durations[kind]
    randomizer = random.Random(20261018)
    samples: list[float] = []
    for index in range(round(duration * RATE)):
        t = index / RATE
        value = 0.0
        if kind == "select":
            # A springy confirmation chirp with a compact major-third resolution.
            value = bell(t, 880, .17, .7) + bell(t-.036, 1108.73, .16, .55)
            value += .12 * math.sin(TAU * (140*t-150*t*t)) * envelope(t,.075,.002,.045)
        elif kind == "lap":
            for start, pitch, strength in [(0,523.251,.65),(.11,659.255,.65),(.22,783.991,.7),(.36,1046.502,.95)]:
                value += bell(t-start,pitch,.52,strength)
            value += .12 * math.sin(TAU * 261.626*t) * envelope(t,.65,.03,.26)
        elif kind == "ready":
            value = bell(t,987.767,.35,.65) + bell(t-.115,1318.51,.38,.85)
            value += .08 * math.sin(TAU * (500*t+900*t*t)) * envelope(t,.30,.01,.18)
        elif kind == "bus_horn":
            # Warm, comic brass pair; intentionally short enough for busy races.
            gate = envelope(t,.67,.025,.16)
            flutter = 1+.008*math.sin(TAU*6*t)
            for hz, strength in [(196.0,.7),(246.942,.46),(293.665,.25)]:
                phase = TAU*hz*t*flutter
                brass = math.sin(phase)+.35*math.sin(2*phase)+.16*math.sin(3*phase)
                value += brass*strength*gate
            value = math.tanh(value*1.2)*.8
        elif kind == "tuk_horn":
            # A two-part bright taxi beep with a playful upward finish.
            for start, length, hz in [(0,.155,587.33),(.205,.205,739.989)]:
                local = t-start
                gate = envelope(local,length,.008,.034)
                phase = TAU*hz*local
                value += gate*(math.sin(phase)+.3*math.sin(phase*2)+.12*math.sin(phase*3))
        # Deterministic, inaudible-level dither avoids correlated truncation noise.
        samples.append(value + (randomizer.random()-randomizer.random())/65536)
    peak = max(abs(value) for value in samples)
    target = .76 if kind in ("select", "ready") else .84
    return [value*target/max(peak,.00001) for value in samples]


def main() -> None:
    DESTINATION.mkdir(parents=True, exist_ok=True)
    report = []
    for kind in ["select", "lap", "ready", "bus_horn", "tuk_horn"]:
        samples = synthesize(kind)
        pcm = array.array("h",[round(max(-1,min(1,s))*32767) for s in samples])
        if sys.byteorder != "little":
            pcm.byteswap()
        output = DESTINATION / f"astra_{kind}.wav"
        with wave.open(str(output), "wb") as stream:
            stream.setnchannels(1)
            stream.setsampwidth(2)
            stream.setframerate(RATE)
            stream.writeframes(pcm.tobytes())
        report.append({"file":output.name,"seconds":len(samples)/RATE,"peak":round(max(abs(s) for s in samples),3),"rms":round(math.sqrt(sum(s*s for s in samples)/len(samples)),4),"sha256":hashlib.sha256(output.read_bytes()).hexdigest()})
    print(json.dumps(report,indent=2))


if __name__ == "__main__":
    main()
