Unicode true
!include "MUI2.nsh"
!include "LogicLib.nsh"
!ifndef VERSION
!define VERSION "1.5.0"
!endif
Name "Leo Racer ${VERSION}"
OutFile "..\dist\LeoRacer-Setup-${VERSION}.exe"
InstallDir "$LOCALAPPDATA\Programs\Leo Racer"
InstallDirRegKey HKCU "Software\LeoRacer" "InstallDir"
RequestExecutionLevel user
SetCompressor /FINAL zlib
Icon "..\assets\art\launcher\leo-road-crest.ico"
UninstallIcon "..\assets\art\launcher\leo-road-crest.ico"
!define MUI_ABORTWARNING
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_RUN "$INSTDIR\Leo Racer Launcher.exe"
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"
Section "Leo Racer (required)"
  SectionIn RO
  SetShellVarContext current
  SetOutPath "$INSTDIR"
  File /r "..\build\ModularGarage\*.*"
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  WriteRegStr HKCU "Software\LeoRacer" "InstallDir" "$INSTDIR"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\LeoRacer" "DisplayName" "Leo Racer"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\LeoRacer" "DisplayVersion" "${VERSION}"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\LeoRacer" "DisplayIcon" "$INSTDIR\Leo Racer Launcher.exe"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\LeoRacer" "UninstallString" '$\"$INSTDIR\Uninstall.exe$\"'
  CreateDirectory "$SMPROGRAMS\Leo Racer"
  CreateShortcut "$SMPROGRAMS\Leo Racer\Leo Racer.lnk" "$INSTDIR\Leo Racer Launcher.exe"
  CreateShortcut "$SMPROGRAMS\Leo Racer\Uninstall.lnk" "$INSTDIR\Uninstall.exe"
SectionEnd
Section /o "Desktop shortcut"
  CreateShortcut "$DESKTOP\Leo Racer.lnk" "$INSTDIR\Leo Racer Launcher.exe"
SectionEnd
Section "Uninstall"
  SetShellVarContext current
  ; Only packaged files are removed. AppData/Godot settings and records survive.
  !include "owned-files.nsh"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir "$INSTDIR"
  Delete "$SMPROGRAMS\Leo Racer\Leo Racer.lnk"
  Delete "$SMPROGRAMS\Leo Racer\Uninstall.lnk"
  RMDir "$SMPROGRAMS\Leo Racer"
  Delete "$DESKTOP\Leo Racer.lnk"
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\LeoRacer"
  DeleteRegKey HKCU "Software\LeoRacer"
SectionEnd
