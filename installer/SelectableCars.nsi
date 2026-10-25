Unicode true
!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "FileFunc.nsh"
!include "Sections.nsh"
!include "StrFunc.nsh"
${StrStr}
Name "Leo Racer 2.3.0"
OutFile "..\dist\release-2.3.0\LeoRacer-Setup-2.3.0.exe"
InstallDir "$LOCALAPPDATA\Programs\Leo Racer"
InstallDirRegKey HKCU "Software\LeoRacer" "InstallDir"
RequestExecutionLevel user
SetCompressor /FINAL zlib
Icon "..\assets\art\launcher\leo-road-crest.ico"
Var ContentTest
Var CarSelection
!define MUI_ABORTWARNING
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_RUN "$INSTDIR\LeoRacer.exe"
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"
Section "Leo Racer + 16 default cars (required)" CORE
 SectionIn RO
 !include "release-required.nsh"
SectionEnd
SectionGroup "Additional Cars (optional; select individually)" ADDONS
 !include "release-cars.nsh"
SectionGroupEnd
Section "-Install selected content"
 SetOutPath "$PLUGINSDIR"
 File /oname=ApplyContent.ps1 "InstallerContent.ps1"
 nsExec::ExecToStack '"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$PLUGINSDIR\ApplyContent.ps1" -Mode Install -Payload "$PLUGINSDIR\payload" -Destination "$INSTDIR"'
 Pop $0
 Pop $1
 ${If} $ContentTest == "yes"
  FileOpen $2 "$EXEDIR\installer-result.txt" w
  FileWrite $2 "$0:$1"
  FileClose $2
 ${EndIf}
 ${If} $0 != 0
  MessageBox MB_ICONSTOP "Installation could not finish. Close Leo Racer and try again.$\r$\n$1" /SD IDOK
  SetErrorLevel 1
  Abort
 ${EndIf}
 WriteUninstaller "$INSTDIR\Uninstall.exe"
 ${If} $ContentTest != "yes"
  SetShellVarContext current
  WriteRegStr HKCU "Software\LeoRacer" "InstallDir" "$INSTDIR"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\LeoRacer" "DisplayName" "Leo Racer"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\LeoRacer" "DisplayVersion" "2.3.0"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\LeoRacer" "UninstallString" '$\"$INSTDIR\Uninstall.exe$\"'
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\LeoRacer" "DisplayIcon" "$INSTDIR\LeoRacer.exe"
  CreateDirectory "$SMPROGRAMS\Leo Racer"
  CreateShortcut "$SMPROGRAMS\Leo Racer\Leo Racer.lnk" "$INSTDIR\LeoRacer.exe"
  CreateShortcut "$SMPROGRAMS\Leo Racer\Uninstall.lnk" "$INSTDIR\Uninstall.exe"
 ${EndIf}
SectionEnd
!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
!insertmacro MUI_DESCRIPTION_TEXT ${CORE} "Game, all three tracks, Workshop, shared drivers and the original 16 vehicles."
!include "release-descriptions.nsh"
!insertmacro MUI_FUNCTION_DESCRIPTION_END
Function .onInit
 InitPluginsDir
 ${GetParameters} $R0
 ClearErrors
 ${GetOptions} $R0 "/CONTENTTEST" $R1
 ${IfNot} ${Errors}
  StrCpy $ContentTest "yes"
 ${EndIf}
 ${GetOptions} $R0 "/CARS=" $CarSelection
 !include "release-selection.nsh"
FunctionEnd
Function un.onInit
 ${GetParameters} $R0
 ClearErrors
 ${GetOptions} $R0 "/CONTENTTEST" $R1
 ${IfNot} ${Errors}
  StrCpy $ContentTest "yes"
 ${EndIf}
FunctionEnd
Section "Uninstall"
 nsExec::ExecToStack '"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$INSTDIR\InstallerContent.ps1" -Mode Uninstall -Destination "$INSTDIR"'
 Pop $0
 Pop $1
 ${If} $ContentTest == "yes"
  FileOpen $2 "$EXEDIR\installer-result.txt" w
  FileWrite $2 "$0:$1"
  FileClose $2
 ${EndIf}
 ${If} $0 != 0
  MessageBox MB_ICONSTOP "Could not remove owned files. Your content was preserved.$\r$\n$1" /SD IDOK
  SetErrorLevel 1
  Abort
 ${EndIf}
 Delete "$INSTDIR\Uninstall.exe"
 ${If} $ContentTest != "yes"
  SetShellVarContext current
  Delete "$SMPROGRAMS\Leo Racer\Leo Racer.lnk"
  Delete "$SMPROGRAMS\Leo Racer\Uninstall.lnk"
  RMDir "$SMPROGRAMS\Leo Racer"
  DeleteRegKey HKCU "Software\LeoRacer"
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\LeoRacer"
 ${EndIf}
 RMDir "$INSTDIR"
SectionEnd
