"""Verify a tool-only update in a disposable extracted build; restore it always."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


def sha256(path: Path) -> str:
    return hashlib.file_digest(path.open("rb"), "sha256").hexdigest()


def run(command: list[str], cwd: Path, env: dict[str, str], timeout: int = 90) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, cwd=cwd, env=env, capture_output=True,
                          text=True, encoding="utf-8", errors="replace", timeout=timeout)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--folder", required=True, type=Path)
    args = parser.parse_args()
    project = Path(__file__).resolve().parent.parent
    game = args.folder.resolve()
    build = (project / "build").resolve()
    if not game.is_relative_to(build):
        parser.error("Only a disposable extracted folder under this project's build directory is allowed")
    console = game / "LeoRacer.console.exe"
    pack = game / "Tools/VehicleWorkshop/workshop.pck"
    metadata = pack.with_name("workshop.json")
    for required in (console, game / "LeoRacer.exe", game / "LeoRacer.pck", pack, metadata):
        if not required.is_file():
            parser.error("The extracted build is incomplete; wait until extraction and tool assembly finish")
    output = build / "customcars"
    output.mkdir(parents=True, exist_ok=True)
    report: dict = {"status": "FAIL", "offline": True, "errors": [], "checks": []}
    core_files = [game / name for name in ("LeoRacer.exe", "LeoRacer.console.exe", "LeoRacer.pck")]
    before = {p.name: sha256(p) for p in core_files}
    originals = {pack: pack.read_bytes(), metadata: metadata.read_bytes()}
    with tempfile.TemporaryDirectory(prefix="tool-probe-", dir=output) as scratch_name:
        scratch = Path(scratch_name)
        env = os.environ.copy()
        env["APPDATA"] = str(scratch / "user-data")
        Path(env["APPDATA"]).mkdir()
        env["DOTNET_BUNDLE_EXTRACT_BASE_DIR"] = str(scratch / "runtime")
        try:
            local_engine = project / ".tools/godot/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe"
            engine = local_engine if local_engine.is_file() else project.parent.parent / "tools/godot-net/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe"
            local_sdk = project / ".tools/dotnet/dotnet.exe"
            sdk = local_sdk if local_sdk.is_file() else project.parent.parent / "tools/dotnet/dotnet.exe"
            env["DOTNET_ROOT"] = str(sdk.parent)
            env["PATH"] = str(sdk.parent) + os.pathsep + env.get("PATH", "")
            result = run([str(engine), "--headless", "--path", str(project), "--script",
                          "res://tests/workshop_pack_probe.gd", "--quit-after", "60", "--",
                          "--drive-test", "--output=" + str(scratch)], project, env)
            text = result.stdout + result.stderr
            (output / "tool-replacement-build.log").write_text(text, encoding="utf-8")
            if result.returncode or "WORKSHOP_PROBE_PACK_BUILT" not in text or "SCRIPT ERROR" in text:
                raise RuntimeError("Replacement probe pack did not build; see tool-replacement-build.log")
            shutil.copyfile(scratch / "workshop.pck", pack)
            info = json.loads(originals[metadata].decode("utf-8-sig"))
            info["version"] = "0.0.0-test-probe"
            info["sha256"] = sha256(pack)
            metadata.write_text(json.dumps(info, indent=2) + "\n", encoding="utf-8")
            env["DOTNET_ROOT"] = ""
            env["PATH"] = os.pathsep.join(p for p in env["PATH"].split(os.pathsep) if "dotnet" not in p.lower())
            result = run([str(console), "--headless", "--quit-after", "300", "--",
                          "--drive-test", "--vehicle-workshop", "--workshop-smoke"], game, env)
            text = result.stdout + result.stderr
            (output / "tool-replacement.log").write_text(text, encoding="utf-8")
            if result.returncode or "WORKSHOP_REPLACEMENT_PROBE" not in text or "WORKSHOP_BOOT_TEST" not in text or "SCRIPT ERROR" in text:
                raise RuntimeError("Exported core did not run the replacement tool; see tool-replacement.log")
            report["checks"].append("Exported core mounted and ran independently replaced API 1 tool pack")
        except (OSError, RuntimeError, ValueError, subprocess.TimeoutExpired) as error:
            report["errors"].append(str(error) if isinstance(error, RuntimeError) else type(error).__name__)
        finally:
            for path, data in originals.items():
                path.write_bytes(data)
            after = {p.name: sha256(p) for p in core_files}
            report["core_sha256_before"] = before
            report["core_sha256_after"] = after
            report["exe_and_core_unchanged"] = before == after
            report["original_tool_restored"] = all(p.read_bytes() == data for p, data in originals.items())
            if before != after:
                report["errors"].append("Executable or core changed during tool-only replacement")
            if not report["original_tool_restored"]:
                report["errors"].append("Original tool restoration failed")
    report["status"] = "PASS" if not report["errors"] else "FAIL"
    (output / "tool-replacement.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("WORKSHOP_TOOL_REPLACEMENT " + json.dumps(report))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
