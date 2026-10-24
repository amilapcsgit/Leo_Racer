Unicode true
!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "FileFunc.nsh"
Var ContentTest
Function .onInit
  ${GetParameters} $R0
  ClearErrors
  ${GetOptions} $R0 "/CONTENTTEST" $R1
  ${IfNot} ${Errors}
    StrCpy $ContentTest "yes"
  ${EndIf}
FunctionEnd
Function un.onInit
  ${GetParameters} $R0
  ClearErrors
  ${GetOptions} $R0 "/CONTENTTEST" $R1
  ${IfNot} ${Errors}
    StrCpy $ContentTest "yes"
  ${EndIf}
FunctionEnd
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
!define APP_EXEC "LeoRacer.exe"
!else
!if "${CHANNEL}" == "True"
!define APP_NAME "Leo Racer RC"
!define APP_KEY "LeoRacerRC"
!else
!define APP_NAME "Leo Racer"
!define APP_KEY "LeoRacer"
!endif
!endif
!ifndef APP_EXEC
!ifdef CITY_ASSETS
!define APP_EXEC "LeoRacer.exe"
!else
!define APP_EXEC "Leo Racer Launcher.exe"
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
!define MUI_FINISHPAGE_RUN "$INSTDIR\${APP_EXEC}"
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"
Section "Leo Racer (required)"
  SectionIn RO
  SetShellVarContext current
  SetOutPath "$INSTDIR"
  File /r "${BUILD_ROOT}\*.*"
!ifdef MODULAR_CONTENT
  ; Remove only the superseded known stock bundle. Loose user folders survive.
  Delete "$INSTDIR\GameAssets\vehicles\roster.pck"
!endif
  ; Empty override folders also exist on a clean hybrid-content installation.
  CreateDirectory "$INSTDIR\GameAssets\textures"
  CreateDirectory "$INSTDIR\GameAssets\vehicles"
  CreateDirectory "$INSTDIR\GameAssets\roads"
  CreateDirectory "$INSTDIR\GameAssets\signs"
  CreateDirectory "$INSTDIR\GameAssets\glb"
  CreateDirectory "$INSTDIR\GameAssets\tracks"
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  ${If} $ContentTest != "yes"
!ifdef CITY_ASSETS
  ; Known files owned by the old bundled installer. User records live elsewhere.
  Delete "$INSTDIR\Leo Racer.exe"
  Delete "$INSTDIR\Leo Racer.pck"
  Delete "$INSTDIR\Leo Racer Launcher.exe"
!endif
  WriteRegStr HKCU "Software\${APP_KEY}" "InstallDir" "$INSTDIR"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_KEY}" "DisplayName" "${APP_NAME}"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_KEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_KEY}" "DisplayIcon" "$INSTDIR\${APP_EXEC}"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_KEY}" "UninstallString" '$\"$INSTDIR\Uninstall.exe$\"'
  CreateDirectory "$SMPROGRAMS\${APP_NAME}"
  CreateShortcut "$SMPROGRAMS\${APP_NAME}\Leo Racer.lnk" "$INSTDIR\${APP_EXEC}"
!ifdef DEVELOPMENT
  CreateShortcut "$SMPROGRAMS\${APP_NAME}\Compatibility mode.lnk" "$INSTDIR\${APP_EXEC}" "--rendering-method gl_compatibility --rendering-driver opengl3"
!endif
  CreateShortcut "$SMPROGRAMS\${APP_NAME}\Uninstall.lnk" "$INSTDIR\Uninstall.exe"
  ${EndIf}
SectionEnd
Section /o "Desktop shortcut"
  ${If} $ContentTest != "yes"
  CreateShortcut "$DESKTOP\${APP_NAME}.lnk" "$INSTDIR\${APP_EXEC}"
  ${EndIf}
SectionEnd
Section "Uninstall"
  SetShellVarContext current
  ; Only packaged files are removed. AppData/Godot settings and records survive.
  !include "owned-files.nsh"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir "$INSTDIR"
  ${If} $ContentTest != "yes"
  Delete "$SMPROGRAMS\${APP_NAME}\Leo Racer.lnk"
!ifdef DEVELOPMENT
  Delete "$SMPROGRAMS\${APP_NAME}\Compatibility mode.lnk"
!endif
  Delete "$SMPROGRAMS\${APP_NAME}\Uninstall.lnk"
  RMDir "$SMPROGRAMS\${APP_NAME}"
  Delete "$DESKTOP\${APP_NAME}.lnk"
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_KEY}"
  DeleteRegKey HKCU "Software\${APP_KEY}"
  ${EndIf}
SectionEnd
