class_name LeoRaceAudio
extends AudioStreamPlayer
## One boot-persistent player pair; menus never restart music at screen changes.
const MENU_TRACKS=["intro_main","intro_alt"]
const TRACKS=["intro_main","intro_alt","kandy_race","coast_race","ceylon_afterglow","island_original"]
const FILES={"intro_main":"res://assets/audio/custom279/intro_main.ogg","intro_alt":"res://assets/audio/custom279/intro_alt.ogg","kandy_race":"res://assets/audio/custom279/kandy_race.ogg","coast_race":"res://assets/audio/custom279/coast_race.ogg","ceylon_afterglow":"res://assets/audio/menu279/ceylon_afterglow.ogg","island_original":"res://assets/audio/custom279/island_original.ogg"}
var next: AudioStreamPlayer
var announcer: AudioStreamPlayer
var host: Node
var bag: Array[String]=[]
var menu_bag: Array[String]=[]
var last_menu:=""
var last_track:=""
var incoming_title:=""
var context:="menu"
var track_id:=""
var fade:=0.
var crossing:=false
var duck:=0.
var announcement_count:=0
var cues: Dictionary={}
var menu_theme: AudioStreamOggVorbis
var music_enabled:=true
var paused:=false
var shutting_down:=false
static func shared(tree: SceneTree) -> LeoRaceAudio:
 var existing:=tree.root.get_node_or_null("LeoRaceMusic") as LeoRaceAudio
 if existing:return existing
 var music:=LeoRaceAudio.new();music.name="LeoRaceMusic";tree.root.add_child(music)
 return music
func bind_game(game: Node) -> void:
 host=game
func unbind_game(game: Node) -> void:
 if host==game:host=null
func _ready() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS
 for name in ["Music","Announcer"]:
  if AudioServer.get_bus_index(name)<0:
   AudioServer.add_bus();var index:=AudioServer.bus_count-1;AudioServer.set_bus_name(index,name);AudioServer.set_bus_send(index,"Master")
 var cfg:=ConfigFile.new();cfg.load("user://leo_racer.cfg")
 music_enabled=bool(cfg.get_value("audio","music",true))
 AudioServer.set_bus_volume_db(0,linear_to_db(maxf(.0001,float(cfg.get_value("audio","volume",.72)))))
 AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"),linear_to_db(maxf(.0001,float(cfg.get_value("ui_audio","Music",.75)))))
 AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Announcer"),linear_to_db(maxf(.0001,float(cfg.get_value("ui_audio","Announcer",1.)))))
 bus="Music";volume_db=-15.
 next=AudioStreamPlayer.new();next.bus="Music";add_child(next)
 announcer=AudioStreamPlayer.new();announcer.bus="Announcer";announcer.volume_db=-1.;add_child(announcer)
 if get_parent().get("music_enabled")!=null:host=get_parent()
 var selected:=pick_intro();menu_theme=open_track(selected,true) as AudioStreamOggVorbis
 stream=menu_theme;last_track=selected
 if stream:play();stream_paused=not music_enabled
func open_track(id: String,looping: bool=false) -> AudioStream:
 var path: String=FILES.get(id,"")
 if path.is_empty() or not ResourceLoader.exists(path):
  push_error("Missing bundled music: "+id);return null
 var song: AudioStream=load(path).duplicate()
 if song is AudioStreamOggVorbis:song.loop=looping
 return song
func pick_intro() -> String:
 if menu_bag.is_empty():
  menu_bag.assign(MENU_TRACKS);menu_bag.shuffle()
  if menu_bag.size()>1 and menu_bag[-1]==last_menu:menu_bag.reverse()
 last_menu=menu_bag.pop_back();return last_menu
func dedicated_track(id: String) -> String:
 return "kandy_race" if id=="kandy_lake" else "coast_race"
func pick() -> AudioStream:
 if bag.is_empty():
  bag.assign(TRACKS);bag.shuffle()
  if bag.size()>1 and bag[-1]==last_track:bag.reverse()
 last_track=bag.pop_back()
 return open_track(last_track)
func crossfade_to(song: AudioStream,title: String) -> void:
 if not song:return
 next.stop();next.stream=song;next.volume_db=-70.;next.play()
 incoming_title=title;crossing=true;fade=0.
func set_context(value: String,course: String="") -> void:
 var desired: String="race" if value in ["race","finishing"] else "menu"
 if desired==context and (desired!="race" or course==track_id):return
 context=desired;track_id=course
 if context=="race":
  var dedicated:=dedicated_track(course)
  bag.assign(TRACKS);bag.erase(dedicated);bag.shuffle()
  crossfade_to(open_track(dedicated),dedicated)
 else:
  var selected:=pick_intro();menu_theme=open_track(selected,true) as AudioStreamOggVorbis
  crossfade_to(menu_theme,selected)
func announce(cue: String) -> void:
 if not cues.has(cue):
  var path:="res://assets/audio/racing278/voice_"+cue+".ogg"
  if ResourceLoader.exists(path):cues[cue]=load(path)
 if not cues.has(cue):return
 announcer.stream=cues[cue];announcer.play();duck=announcer.stream.get_length()+.25;announcement_count+=1
func stop_all() -> void:
 stop()
 if is_instance_valid(next):next.stop()
 if is_instance_valid(announcer):announcer.stop()
 duck=0.;crossing=false
func shutdown() -> void:
 shutting_down=true;set_process(false);stop_all();stream=null;host=null
 if is_instance_valid(next):next.stream=null
 if is_instance_valid(announcer):announcer.stream=null
 cues.clear();menu_theme=null
func _process(dt: float) -> void:
 if shutting_down:return
 if is_instance_valid(host):
  music_enabled=bool(host.get("music_enabled"));paused=bool(host.get("paused"))
  var course: String=String(host.get("chosen_track_id")) if host.get("chosen_track_id")!=null else "astra_coast"
  set_context(String(host.get("state")),course)
 stream_paused=not music_enabled or paused
 next.stream_paused=stream_paused;announcer.stream_paused=paused
 if not paused:duck=maxf(0.,duck-dt)
 if stream_paused:return
 if stream==null:return
 var remaining:=stream.get_length()-get_playback_position()
 if context=="race" and not crossing and remaining<=2. and playing:
  var song:=pick();crossfade_to(song,last_track)
 var gain: float=-9. if context=="race" else -15.
 if duck>0.:gain-=9.
 if crossing:
  fade=minf(1.,fade+dt/2.)
  volume_db=gain+linear_to_db(maxf(.0001,1.-fade));next.volume_db=gain+linear_to_db(maxf(.0001,fade))
  if fade>=1.:
   var offset:=next.get_playback_position();stream=next.stream;next.stop();next.stream=null;play(offset);last_track=incoming_title;crossing=false
 else:
  volume_db=move_toward(volume_db,gain,dt*45.)
  if not playing:play()
func _exit_tree() -> void:shutdown()