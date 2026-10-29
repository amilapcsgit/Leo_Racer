# Leo Racer 2.6 validation

Hardware: Windows, RTX A1000 6 GB laptop GPU. Engine: Godot 4.7.2 .NET. Functional checks use isolated profiles and content destinations. The installed game, LightingCheckpoint, Preview-2.6.0, downloaded sources and Blender masters are preserved.

## Evidence and scope

`LeoRacer-2.6.0-Evidence.zip` contains machine-readable results, process logs and rendered captures. A PASS applies only to the assertions in that report; automated injected controller events do not establish compatibility with every physical controller. Performance is advisory, as requested.

The UI suite exercises actual pointer delivery to Home → Content, Results header Back, Escape, controller B and the explicit Home button. It checks shared/effective design text sizes, SQLite worker availability, three stable branded Home heroes and no Home vehicle viewport, shuffled track loading art, fixed operation selection and menus at 1280×720, 1920×1080, 2560×1440 and 2560×1080. Captures cover Home, Settings including scrolling, Records/filters, Controls and split setup. Export checks separately cover the built-in Workshop/import workflow and content refresh.

Prior unchanged-physics regression evidence is included separately: 153 audit checks, 226 contact checks and a deterministic 360-tick replay with zero reported position/speed/fuel deviation. Earlier content checks covered 21 cars, both Dusters' lamps/actions and all six drivers. New exported smoke checks exercise native .NET/SQLite and all 126 driver/car combinations. Track checks cover all three tracks and solo/split racing. These are automated functional checks, not a claim of exhaustive manual playtesting.

Installer testing uses a new workspace-only destination, checks clean discovery and core hashes, modifies a managed file, reinstalls to check backups, then uninstalls to check preservation of custom content and modified files. Portable extraction is tested with SDK paths removed. Generated loading textures are verified before content mounting. ZIP entries and uploaded assets are hash checked.

## Known limits and measurements

- Some cold startup and preview loads exceed the original 3 s selected-preview goal; preparation is staged but cannot eliminate disk/GPU costs. Car assemblies remain substantially heavier than simple UI thumbnails.
- Earlier matched measurements included Kandy Compatibility split dusk p95 31.223 ms, p99 35.589 ms and worst 53.407 ms. The 16.7 ms target did not pass in that case. Do not interpret the release as a universal 60 fps claim.
- Cold first-contact presentation measurements included Forward+ 2.191 ms and Compatibility 2.467 ms, exceeding the 2 ms target; surrounding settled frames were 19.766 ms and 14.619 ms respectively. Scenery insertion and first-lap loading can add separate spikes.
- Godot can report Texture RID/ObjectDB or OpenGL texture leaks during diagnostic shutdown. These remain tracked; runtime script/parse/shader errors are treated as functional failures.
- Home uses complete generated scenes rather than a selected 3D vehicle. The generated artwork is a stylized Colombo/Kandy interpretation, not a geographic survey. Paint presets are visual approximations, not measured factory values.
- Opening doors/trunk are cosmetic; the driving collision envelope stays fixed. Forward+ and Compatibility have different lighting/particle limitations. Lower graphics quality is available.

Final executable/core/installer identities and individual test statuses are recorded in the evidence JSON and SHA256SUMS.txt. No fabricated passing performance data is supplied.

## Final garage/camera revision

Focused assertions cover all 21 front-on previews, four-second rotation hold, orbit/Reduced Motion, aspect-preserving skyline sampling, pointer/Enter/controller A Keep Racing for both players, unchanged selections, visible blocked-placement/device errors, and constant chase offsets at 30/60/120 simulated fps. The FOV target and speed pullback retain 10% of their previous effect. Vehicle translation is carried directly before damping relative camera motion. Actual native Windows picker checks are recorded separately.

Final rerun: 927 UI assertions and 255 focused garage/camera assertions passed in each renderer in both source and exported builds; 449 content assertions passed per exported renderer. All ten standalone boot/content/smoke/UI/polish runs exited successfully without SDK paths. The Workshop source regression passed 20 checks. The exported Workshop imported a fixture through its job interface; pointer Apply/Validate and Install succeeded, Content discovered a 22nd custom car, and closing the in-game Workshop triggered automatic refresh. The fixture was archived outside the release, restoring 21 defaults. Native Windows dialog opening and Escape cancellation were observed; file selection itself was not completed through automation because modal focus could not be retained reliably.

Lighting reruns passed 107 Forward+ and 91 Compatibility assertions across all three tracks. Six actual-engine split-screen transition clips are included. These captures ran alongside UI inspection and are functional evidence, not controlled performance benchmarks. Existing archived performance limits above remain applicable; no new universal frame-rate claim is made.
