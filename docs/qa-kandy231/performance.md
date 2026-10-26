# Kandy performance comparison

Serial six-racer 1080p runs, 6s warmup then 30s sample; baseline uses unchanged v2.3.0 track on the same current core for controlled scenery comparison. Single player and separated two-player split-screen; 120fps cap.

GPU: NVIDIA RTX A1000 6GB Laptop GPU. MB are decimal; static memory is Godot's monitor, not total process working set. Values below are baseline → updated.

| Renderer / mode | FPS | p95 ms | longest frame ms | draw calls | static MB | video MB |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| forward_plus / single | 119.9 → 119.9 | 10.6 → 10.6 | 38.5 → 34.4 | 1171.2 → 964.7 | 253.0 → 252.6 | 585.1 → 1159.8 |
| forward_plus / split | 118.8 → 120.0 | 10.7 → 10.6 | 12.2 → 11.5 | 2203.3 → 1884.9 | 274.4 → 257.6 | 808.9 → 1365.2 |
| gl_compatibility / single | 119.7 → 119.9 | 10.7 → 10.6 | 60.9 → 39.3 | 2169.8 → 1646.4 | 208.5 → 191.7 | 255.4 → 677.7 |
| gl_compatibility / split | 98.1 → 112.9 | 14.6 → 11.5 | 286.0 → 69.7 | 3750.4 → 3104.8 | 210.8 → 193.9 | 343.2 → 729.5 |

Compatibility retains occasional frame spikes. Forward+ is recommended. Streaming/track-change stability is checked separately in acceptance.json.
