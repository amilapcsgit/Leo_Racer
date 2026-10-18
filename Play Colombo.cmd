@echo off
if exist "%~dp0build\Colombo\Leo Racer.exe" (
  start "" "%~dp0build\Colombo\Leo Racer.exe"
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\run_godot.ps1"
)
