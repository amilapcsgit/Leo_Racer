# Leo Racer 2.7.9 custom soundtrack

The four MP3 recordings below were supplied by the user. They are credited as **User-supplied custom soundtrack**. This conversion does not dedicate these recordings to CC0 or assert a new third-party license grant.

| Game ID | Original recording |
|---|---|
| `intro_main` | Leo Racer Intro menu garage continus loading audio.mp3 |
| `intro_alt` | additional intro to shuffle Colombo Grand Prix.mp3 |
| `kandy_race` | Kandy sound track.mp3 |
| `coast_race` | astra lotus Colombo Grand-prix.mp3 |

`island_original.ogg` is a conversion of the existing project `assets/audio/island_music.wav`; its original project provenance remains unchanged. The existing original Ceylon Afterglow theme remains at `assets/audio/menu279/ceylon_afterglow.ogg`.

All five converted files use 48 kHz stereo Ogg Vorbis. Two-pass normalization targets −18 LUFS; decoded Vorbis outputs are checked for true peaks at or below −2 dBTP. A conditional 80 ms circular overlap removes a discontinuous loop boundary; musical arrangement, pitch, tempo, and source character are retained.

Original MP3s remain in Downloads and the project WAV remains untouched. `customaudio279.json` records their original SHA-256 hashes, output hashes, preparation steps, full loudness measurements, and decoded loop-boundary checks.

Rebuild with the bundled Python/NumPy runtime: `python tools/prepare_custom_audio279.py --downloads "<your Downloads folder>"`.
