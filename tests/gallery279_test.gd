extends SceneTree
var failures: Array[String]=[]
var checks:=0
class AudioHost:
 extends Node
 var state:="menu"
 var music_enabled:=true
 var paused:=false
func check(value: bool,message: String) -> void:
 checks+=1
 if not value:failures.append(message)
func _initialize() -> void:run.call_deferred()
func run() -> void:
 var choices:=LeoLoadingBackdrops.paths()
 check(choices.size()>=23,"all loading heroes including five new locations available")
 var seen: Dictionary={};var last:=""
 LeoLoadingBackdrops.bags.clear();LeoLoadingBackdrops.previous.clear()
 for i in choices.size():
  var id:=LeoLoadingBackdrops.new_operation("gallery-test")
  var path:=LeoLoadingBackdrops.begin_load(id,LeoLoadingBackdrops.TRACKS[i%3])
  check(not seen.has(path),"no repeats before whole gallery exhausted")
  check(LeoLoadingBackdrops.begin_load(id,"another-track")==path,"stable artwork throughout operation")
  check(not LeoLoadingBackdrops.caption(path).is_empty(),"place or artwork caption")
  seen[path]=true;last=path
 check(LeoLoadingBackdrops.begin_load(LeoLoadingBackdrops.new_operation("next"))!=last,"no immediate boundary repeat")
 var saved:=LeoLoadingBackdrops.entries
 LeoLoadingBackdrops.entries=[{"path":"res://missing-artwork-279.png","caption":"missing"}]
 check(not LeoLoadingBackdrops.paths().is_empty(),"missing-art fallback")
 LeoLoadingBackdrops.entries=saved
 LeoLoadingBackdrops.entries.clear();LeoLoadingBackdrops.bags.clear();LeoLoadingBackdrops.previous.clear()
 print("GALLERY_AUDIO_279 ",JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"errors":failures}))
 quit(0 if failures.is_empty() else 1)
