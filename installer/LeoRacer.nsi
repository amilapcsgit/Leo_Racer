Unicode true
!include "MUI2.nsh"
!include "LogicLib.nsh"
!ifndef VERSION
!define VERSION "1.5.0"
!endif
!ifndef CHANNEL
!define CHANNEL "False"
!endif
!ifndef BUILD_ROOT
!define BUILD_ROOT "..\build\ModularGarage"
!endif
!ifdef DEVELOPMENT
!define APP_NAME "Leo Racer Development"
!define APP_KEY "LeoRacerDevelopment"
!else
!if "${CHANNEL}" == "True"
!define APP_NAME "Leo Racer RC"
!define APP_KEY "LeoRacerRC"
!else
!define APP_NAME "Leo Racer"
!define APP_KEY "LeoRacer"
!endif
!endif
Name "${APP_NAME} ${VERSION}"
OutFile "..\dist\LeoRacer-Setup-${VERSION}.exe"
InstallDir "$LOCALAPPDATA\Programs\${APP_NAME}"
InstallDirRegKey HKCU "Software\${APP_KEY}" "InstallDir"
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
  File /r "${BUILD_ROOT}\*.*"
  ; Empty override folders also exist on a clean hybrid-content installation.
  CreateDirectory "$INSTDIR\GameAssets\textures"
  CreateDirectory "$INSTDIR\GameAssets\vehicles"
  CreateDirectory "$INSTDIR\GameAssets\roads"
  CreateDirectory "$INSTDIR\GameAssets\signs"
  CreateDirectory "$INSTDIR\GameAssets\glb"
  CreateDirectory "$INSTDIR\GameAssets\tracks"
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  WriteRegStr HKCU "Software\${APP_KEY}" "InstallDir" "$INSTDIR"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_KEY}" "DisplayName" "${APP_NAME}"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_KEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_KEY}" "DisplayIcon" "$INSTDIR\Leo Racer Launcher.exe"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_KEY}" "UninstallString" '$\"$INSTDIR\Uninstall.exe$\"'
  CreateDirectory "$SMPROGRAMS\${APP_NAME}"
  CreateShortcut "$SMPROGRAMS\${APP_NAME}\Leo Racer.lnk" "$INSTDIR\Leo Racer Launcher.exe"
  CreateShortcut "$SMPROGRAMS\${APP_NAME}\Uninstall.lnk" "$INSTDIR\Uninstall.exe"
SectionEnd
Section /o "Desktop shortcut"
  CreateShortcut "$DESKTOP\${APP_NAME}.lnk" "$INSTDIR\Leo Racer Launcher.exe"
SectionEnd
Section "Uninstall"
  SetShellVarContext current
  ; Only packaged files are removed. AppData/Godot settings and records survive.
  !include "owned-files.nsh"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir "$INSTDIR"
  Delete "$SMPROGRAMS\${APP_NAME}\Leo Racer.lnk"
  Delete "$SMPROGRAMS\${APP_NAME}\Uninstall.lnk"
  RMDir "$SMPROGRAMS\${APP_NAME}"
  Delete "$DESKTOP\${APP_NAME}.lnk"
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_KEY}"
  DeleteRegKey HKCU "Software\${APP_KEY}"
SectionEnd
