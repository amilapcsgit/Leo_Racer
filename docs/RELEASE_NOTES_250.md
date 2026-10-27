# Leo Racer 2.5.0

Twenty tested cars, three Sri Lankan circuits and fully offline solo or local split-screen racing.

- Bundles the selected twenty-car roster in both the full installer and portable ZIP. Automatic AI grids use this roster; manually installed Vehicle API 1 add-ons remain selectable. Existing installed add-ons survive upgrades.
- Polishes asphalt, terrain, lake tones, exposure, contact shadows and authored reflection placement while retaining the bright style, baked lighting and Compatibility support.
- Adds continuous roadside collision contact and sliding, relative-velocity vehicle impacts, directional sparks/dust and scrape sound. Cosmetic scratches and dent shading reset on a new race and survive recovery; they do not change performance or silhouettes.
- Grounds tire marks on the actual road surface, including elevated sections. Shared effects have bounded budgets.
- Keeps the dynamic camera effect with **50% less speed-driven pull-back**. Vehicle-size clearance and the existing FOV curve are preserved.
- Preserves the Distinct-v3-final RC's fair AI, ordered checkpoints, independent human finishes, controller reassignment, restored solo instruments, realistic sizes and layered engine audio.
- Uses `distinct_v4` records for the new collision behavior. Earlier records remain available as legacy entries; imported cars remain modded/unranked.
- Fixes track shader-material retirement during world changes. Vehicle source meshes, original package files and professional finishes remain unchanged.

## Included cars

Bigster, Duster, BYD Yangwang U8, Colombo Tuk-Tuk, Cyberpunk GT, Formula Blue, Neon Hover, McLaren MP4-25, Volkswagen Beetle, DeLorean Time Machine, Jeep Wrangler, Jeep Gladiator, Ford Mustang RTR, Ferrari Roma, Toyota Supra A90, BMW M4 Widebody, Pininfarina Teorema, McLaren 765LT, BYD Atto 2 and Future Car.

## Install and play

Download **LeoRacer-Setup.exe** for the full offline Windows installer. The default Complete installation includes all twenty cars and three tracks. Upgrades preserve custom content and back up modified files before replacing them.

Or extract **LeoRacer-2.5.0-win64.zip** in full and run **LeoRacer.exe**. Keep the executable, runtime folder and `GameAssets` together. No Godot editor, .NET SDK, account or download is required. Run **Play Compatibility.cmd** if Vulkan is unavailable.

Checksums are in **SHA256SUMS.txt**. See **TEST_REPORT.md** and **LeoRacer-2.5.0-Evidence.zip** for validation and measured limits. Generated README artwork is labeled promotional; gameplay screenshots are untouched.

## Scope

Temporary body marks are cosmetic. Full deformation, detachable parts, performance damage, suspension replacement, motion blur and dynamic weather are not included. Reduced Motion suppresses procedural camera/chassis jolts while retaining useful instruments and contact cues. Asset attribution remains in `GameAssets/licenses` and each vehicle's `LICENSE.txt`.

## Measured release validation

The exact executable passed nine native content/camera/race cases. The twenty-car installer passed clean install, hash verification, reinstall, backup and uninstall-preservation tests. RTX A1000 1080p Medium: all twelve solo/split renderer cases meet the 16.7 ms warmed p95 target; worst p95 16.052 ms. Larger individual frames and cold-load times remain; see TEST_REPORT.md and raw evidence.
