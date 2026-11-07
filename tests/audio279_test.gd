extends SceneTree
var errors: Array[String]=[]
var checks:=0
class AudioHost:
 extends Node
 var state:="garage"
 var chosen_track_id:="kandy_lake"
 var music_enabled:=true
 var paused:=false
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:errors.append(message);push_error(message)
func settle() -> void:
 for frame in 3:await process_frame
func _initialize() -> void:run.call_deferred()
func run() -> void:
 var music:=LeoRaceAudio.shared(root.get_tree())
 await settle()
 check(LeoRaceAudio.shared(root.get_tree())==music,"One persistent music controller across bootstrap/main handoff")
 check(music.last_track in LeoRaceAudio.MENU_TRACKS and music.menu_theme.loop,"Startup selects an authentic looping intro")
 var selected:=music.stream
 var began:=music.get_playback_position()
 for state in ["garage","settings","loading","countdown"]:
  music.set_context(state,"kandy_lake");await settle()
  check(music.stream==selected and not music.crossing,"Menu/garage/loading/countdown keep the same playing intro / "+state)
 check(music.get_playback_position()>=began,"Screen changes preserve playback offset")
 for id in LeoRaceAudio.TRACKS:
  var song:=music.open_track(id)
  check(song!=null and song.get_length()>10.,"Bundled custom/original recording decodes / "+id)
 var menus: Array=[]
 for i in 6:menus.append(music.pick_intro())
 check(menus.slice(0,2).size()==2 and menus[0]!=menus[1],"Both authentic intros appear in the shuffle")
 for i in range(1,menus.size()):check(menus[i]!=menus[i-1],"No repeated intro at shuffle boundary")
 music.set_context("race","kandy_lake");await create_timer(2.2).timeout
 check(music.context=="race" and music.last_track=="kandy_race" and not music.crossing,"Kandy starts with its dedicated recording at GO")
 var seen: Dictionary={"kandy_race":true}
 for i in 5:
  var song:=music.pick()
  check(song!=null and not seen.has(music.last_track),"Long-race bag uses each other custom/original once")
  seen[music.last_track]=true
 check(seen.size()==6 and seen.has("ceylon_afterglow") and seen.has("island_original"),"Long races include all four custom songs plus both generated originals")
 var previous:=music.last_track
 music.pick();check(music.last_track!=previous,"No repeated race song at bag boundary")
 music.set_context("results","kandy_lake");await create_timer(2.2).timeout
 check(music.context=="menu" and music.last_track in LeoRaceAudio.MENU_TRACKS,"Results returns to the menu-intro pool")
 music.set_context("race","astra_coast");await create_timer(2.2).timeout
 check(music.last_track=="coast_race","Astra uses the dedicated coast recording")
 check(music.dedicated_track("colombo_city")=="coast_race","Colombo uses the shared dedicated coast recording")
 music.seek(music.stream.get_length()-1.8);await create_timer(2.4).timeout
 check(music.context=="race" and music.last_track!="coast_race" and not music.crossing and music.playing,"A long race automatically crossfades into the mixed playlist when its dedicated recording ends")
 var first:=AudioHost.new();root.add_child(first);music.bind_game(first)
 await settle();await create_timer(2.2).timeout
 var stream_before:=music.stream;var position_before:=music.get_playback_position()
 var second:=AudioHost.new();root.add_child(second);music.bind_game(second);first.queue_free();await settle()
 check(music.stream==stream_before and music.get_playback_position()>=position_before,"Main handoff preserves the existing intro and playback offset")
 second.paused=true;await settle()
 check(music.stream_paused and (not music.next.playing or music.next.stream_paused),"Pause preserves all active music players")
 second.paused=false;second.music_enabled=false;await settle()
 check(music.stream_paused,"Saved music disable applies to the persistent controller")
 second.music_enabled=true;await settle()
 music.announce("3");check(music.duck>0. and music.announcement_count==1,"Announcer retains independent playback and music ducking")
 music.shutdown();await create_timer(.1,true,false,true).timeout
 check(music.stream==null and music.next.stream==null and music.menu_theme==null,"Shutdown releases audio streams before teardown")
 second.queue_free();music.queue_free();await settle()
 var out:=ProjectSettings.globalize_path("res://build/qa279/audio-state")
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--qa-output="):out=arg.trim_prefix("--qa-output=")
 DirAccess.make_dir_recursive_absolute(out)
 var report:={"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors}
 FileAccess.open(out.path_join("audio279.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("AUDIO279 ",JSON.stringify(report));quit(0 if errors.is_empty() else 1)
