# Mirror refresh — 2.7.9

Visible cockpit mirrors target 30 updates per second. Each mirror retains its deadline remainder, skips missed deadlines after a slow frame, and requests at most one render per process frame. Newly visible glass refreshes immediately. Player slots and mirror roles use staggered phases to spread work across frames.

Mirror cameras follow the interpolated chassis pose. Both rear and side glass are checked against the local player's actual camera frustum; side mirrors additionally require the appropriate head-look direction. Chase, Ghost, photo mode and offscreen mirrors do not render, including during warm-up. The narrower split view may place the 2014 center mirror outside the forward view; a small rightward head-look brings it onscreen.

| Mode | Texture | Far clip | Mesh LOD threshold |
| --- | --- | --- | --- |
| Solo | 128 × 64 | 80 m | 5 |
| Split screen | 64 × 32 | 60 m | 6 |

Mirror views retain the 0.06 m near clip and exclude their owner's body/driver and both mirror-surface layers. Positional shadow atlases, MSAA, screen-space AA, glow, SSAO, SSIL, SSR and volumetric fog are disabled. Ambient light and simple fog follow the active race environment. Instruments and navigation retain their separate display cadence.

`tests/mirrors279_test.gd` measures actual changed mirror pixels from moving reflected world geometry, rather than relying only on requested-update counters. It saves raw mirror frames, timestamp series, contact sheets and real cockpit/exterior screenshots. Functional coverage includes all three reviewed cars, both side mirrors, inactive/offscreen states, split-screen night and simultaneous head-look. Separate off/on performance sampling performs no texture readback.

Clean source and native validation results are recorded after the final audio import and release checks. Exploratory captures remain separate from accepted evidence.
