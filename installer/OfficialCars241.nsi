Unicode true
!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "FileFunc.nsh"
!include "Sections.nsh"
!include "StrFunc.nsh"
${StrStr}
Name "Leo Racer 2.4.1"
OutFile "..\dist\release-2.4.1\LeoRacer-Setup.exe"
InstallDir "$LOCALAPPDATA\Programs\Leo Racer"
InstallDirRegKey HKCU "Software\LeoRacer" "InstallDir"
RequestExecutionLevel user
SetCompressor /FINAL zlib
VIProductVersion "2.4.1.0"
VIAddVersionKey "ProductName" "Leo Racer"
VIAddVersionKey "ProductVersion" "2.4.1"
VIAddVersionKey "FileVersion" "2.4.1.0"
VIAddVersionKey "FileDescription" "Leo Racer offline installer"
VIAddVersionKey "LegalCopyright" "Leo Racer contributors"
InstType "Complete - all tracks and 16 official cars"
InstType "Standard - all tracks and 16 cars"
InstType /CUSTOMSTRING=Custom
Var InstallProfile
Var TrackSelection
Icon "..\assets\art\launcher\leo-road-crest.ico"
Var ContentTest
Var CarSelection
!define MUI_ABORTWARNING
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!define MUI_PAGE_CUSTOMFUNCTION_LEAVE ValidateComponents
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_RUN "$INSTDIR\LeoRacer.exe"
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"
Section "Leo Racer + 16 default cars (required)" CORE
 SectionIn 1 2 RO
 !include "release241-required.nsh"
SectionEnd
SectionGroup "Tracks (choose at least one)" TRACKS
 !include "release241-tracks.nsh"
SectionGroupEnd
Section "-Install selected content"
 Call ValidateComponents
 SetOutPath "$PLUGINSDIR"
 File /oname=ApplyContent.ps1 "InstallerContent.ps1"
 nsExec::ExecToStack '"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$PLUGINSDIR\ApplyContent.ps1" -Mode Install -Version "2.4.1" -Payload "$PLUGINSDIR\payload" -Destination "$INSTDIR"'
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
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\LeoRacer" "DisplayVersion" "2.4.1"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\LeoRacer" "UninstallString" '$\"$INSTDIR\Uninstall.exe$\"'
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\LeoRacer" "DisplayIcon" "$INSTDIR\LeoRacer.exe"
  CreateDirectory "$SMPROGRAMS\Leo Racer"
  CreateShortcut "$SMPROGRAMS\Leo Racer\Leo Racer.lnk" "$INSTDIR\LeoRacer.exe"
  CreateShortcut "$SMPROGRAMS\Leo Racer\Uninstall.lnk" "$INSTDIR\Uninstall.exe"
 ${EndIf}
SectionEnd
!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
!insertmacro MUI_DESCRIPTION_TEXT ${CORE} "Required game, Workshop, shared drivers and the original 16 vehicles. Choose tracks below."
!include "release241-descriptions.nsh"
!insertmacro MUI_FUNCTION_DESCRIPTION_END
Function ValidateComponents
 SectionGetFlags ${TRACK_0} $0
 SectionGetFlags ${TRACK_1} $1
 SectionGetFlags ${TRACK_2} $2
 IntOp $0 $0 | $1
 IntOp $0 $0 | $2
 IntOp $0 $0 & ${SF_SELECTED}
 ${If} $0 == 0
  MessageBox MB_ICONSTOP "Select at least one race track." /SD IDOK
  SetErrorLevel 2
  Abort
 ${EndIf}
FunctionEnd
Function .onInit
 InitPluginsDir
 StrCpy $InstallProfile "complete"
 StrCpy $TrackSelection "all"
 StrCpy $CarSelection ""
 ${GetParameters} $R0
 ClearErrors
 ${GetOptions} $R0 "/CONTENTTEST" $R1
 ${IfNot} ${Errors}
  StrCpy $ContentTest "yes"
  ClearErrors
  ${GetOptions} $R0 "/TESTDIR=" $R1
  ${If} ${Errors}
   SetErrorLevel 2
   Abort
  ${EndIf}
  ${If} $R1 == ""
  ${OrIf} $INSTDIR != $R1
   SetErrorLevel 2
   Abort
  ${EndIf}
 ${EndIf}
 ClearErrors
 ${GetOptions} $R0 "/CARS=" $R1
 ${IfNot} ${Errors}
  StrCpy $CarSelection $R1
  StrCpy $InstallProfile "custom"
 ${EndIf}
 ClearErrors
 ${GetOptions} $R0 "/TRACKS=" $R1
 ${IfNot} ${Errors}
  StrCpy $TrackSelection $R1
  StrCpy $InstallProfile "custom"
 ${EndIf}
 ClearErrors
 ${GetOptions} $R0 "/PROFILE=" $R1
 ${IfNot} ${Errors}
  StrCpy $InstallProfile $R1
 ${EndIf}
 ${If} $InstallProfile == "complete"
  SetCurInstType 0
 ${ElseIf} $InstallProfile == "standard"
  SetCurInstType 1
 ${ElseIf} $InstallProfile != "custom"
  MessageBox MB_ICONSTOP "Unknown install profile." /SD IDOK
  SetErrorLevel 2
  Abort
 ${EndIf}
 !include "release241-selection.nsh"
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
