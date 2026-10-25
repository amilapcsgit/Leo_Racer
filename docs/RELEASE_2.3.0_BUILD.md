# v2.3.0 reproducible release checkpoint

Branch: kandy. Build with `tools/build_release_230.ps1` after provisioning the
pinned local toolchain and licensed local content. This deliberately uses the
checked template (`-DebugExport`), not the unchecked optimized template that
failed native shutdown tests. No debugger endpoint or network service is enabled.
The development profile in tools/content.py remains Bigster + Duster only.

`content/releases/2.3.0.json` is the explicit 16-default / 32-optional roster and
records the supplier's public redistribution confirmation. Existing per-model
licenses are retained. Source GLBs and personal build directories are not pushed.
`tools/release_230.py assemble` stages loose content, static compiler inputs and
NSIS component lists; `package` creates archives and their publishing manifest.
All optional sections start unchecked; selection is also testable with /CARS=all
or a comma-separated ID list. /CONTENTTEST suppresses shortcuts/registry changes.
The standard Components page supplies native keyboard/mouse controls and a
full-name/installed-size description for every optional car.

InstallerContent.ps1 keeps a hash-based file-ownership ledger, preserves unrelated
files, backs up changed replacements to ContentBackups with an original-path
index, and removes only unchanged owned files on uninstall. Deselecting an old
car never removes it. Windows PowerShell uses process-scoped execution policy and
built-in .NET hashing; installation does not download prerequisites or content.

Verification is in docs/qa-release-2.3.0/validation.json. Car-load validation:
48 compatible / 16 official. Imported wheel/steering/caliper/reverse/boost checks:
32 pass, zero driver tests. Beetle, BYD U8 and Land Cruiser complete representative
split-screen driving. Bigster: 130 checks. Rankings: 26 checks using an official
track/roster fixture. Six exported three-lap races cover both modes and all tracks.
Streaming: 178 checks, stable memory over three track-change cycles.
Default, individual, mixed and all-car silent installations, upgrade additions,
deselection retention, edited-file backups and uninstall preservation pass.
Native pointer verification remains unavailable: Computer Use app-access approval
timed out. Do not report actual checkbox clicks as verified.

The rejected unchecked candidate's native failures and the known Compatibility
frame spikes are disclosed. Checked-runtime diagnostic shutdown still reports
Godot ObjectDB/resource cleanup warnings, but the race matrix exits successfully.
Build archives, CRC verification, exact sizes and SHA256SUMS are produced under
dist/release-2.3.0. Publish only the named manifest artifacts after the final
installed-package checks; the legacy workflow excludes kandy and v2.3 tags.
