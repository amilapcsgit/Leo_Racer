# Leo Racer 2.8.0 validation

## Environment Detail

Frame times are milliseconds on the NVIDIA RTX A1000 Laptop GPU at 1024 × 576. These are sampled gameplay camera windows. Auto targets 16.67 ms per frame. The raw evidence includes Low, Medium, High, and Auto measurements, grass counts, and actual tiers.

| Renderer | Track | One player p50 / p95 | Two players p50 / p95 |
|---|---|---:|---:|
| Forward+ | Astra Lotus Coast | 5.19 / 7.68 | 6.04 / 7.55 |
| Forward+ | Colombo City | 4.96 / 7.99 | 5.57 / 6.15 |
| Forward+ | Kandy Lake | 8.32 / 9.55 | 9.57 / 12.37 |
| Forward+ | Wennappuwa | 4.79 / 5.17 | 5.74 / 6.77 |
| Compatibility | Astra Lotus Coast | 6.61 / 7.44 | 8.83 / 10.20 |
| Compatibility | Colombo City | 6.55 / 7.20 | 8.29 / 10.17 |
| Compatibility | Kandy Lake | 9.96 / 10.95 | 12.27 / 18.22 |
| Compatibility | Wennappuwa | 5.86 / 6.46 | 7.82 / 8.38 |

Kandy split-screen in Compatibility exceeded the 16.67 ms target at the 95th percentile. The automatic controller reduced detail after simulated sustained load and recovered after sustained headroom.

## Content and audio

- The standalone Kandy ZIP loaded in stock Leo Racer 2.7.9. The packaged upgrade retains the original route hash and all 2,049 resident collision shapes.
- A tree replacement and roof adjustment survived save, reopen, and rebake in the local Kandy authoring project.
- Content validation mounted all four tracks in the Windows build and confirmed that Wennappuwa is unranked.
- The offline soundtrack regression passed all 36 checks. The new audio bank contains 40 recorded engine loops and two layers derived from one credited tire recording.
- The EmacE Art grass sample rendered with MultiMesh in both renderer trials. The release uses Leo Racer's shader so the source distribution can include it.

See the release evidence archive for the native race, installer, portable extraction, and renderer logs.
