StrCpy $R3 ",$TrackSelection,"
SectionSetFlags ${TRACK_0} 0
${StrStr} $R2 $R3 ",astra_coast,"
${If} $TrackSelection == "all"
${OrIf} $R2 != ""
SectionSetFlags ${TRACK_0} ${SF_SELECTED}
${EndIf}
SectionSetFlags ${TRACK_1} 0
${StrStr} $R2 $R3 ",colombo_city,"
${If} $TrackSelection == "all"
${OrIf} $R2 != ""
SectionSetFlags ${TRACK_1} ${SF_SELECTED}
${EndIf}
SectionSetFlags ${TRACK_2} 0
${StrStr} $R2 $R3 ",kandy_lake,"
${If} $TrackSelection == "all"
${OrIf} $R2 != ""
SectionSetFlags ${TRACK_2} ${SF_SELECTED}
${EndIf}