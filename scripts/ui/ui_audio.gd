class_name LeoUIAudio
extends Node
var effect: AudioStreamPlayer
var voice: AudioStreamPlayer
var players: Array[AudioStreamPlayer]=[]
var streams: Dictionary={}
var next_player:=0
var quiet_until:=0
var cue_counts: Dictionary={}
const SYNTH=preload("res://scripts/ui/vendor/menu_kit_sounds.gd")
var last_move := 0
var levels := {"Music":.75,"Effects":1.,"UI":.7,"Voice":.8}
var voice_enabled := true
var last_voice: Dictionary={}
func _ready() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS;add_to_group("ui_audio")
 for bus in levels:
  if AudioServer.get_bus_index(bus)<0:
   AudioServer.add_bus();var index:=AudioServer.bus_count-1;AudioServer.set_bus_name(index,bus);AudioServer.set_bus_send(index,"Master")
 for i in 4:
  var player:=AudioStreamPlayer.new();player.bus="UI";add_child(player);players.append(player)
 effect=players[0]
 for key in ["move","select","open","back","tick","deny","done","toggle_on","toggle_off"]:streams[key]=SYNTH._build("soft",key,1.12,.05)
 streams["carousel"]=SYNTH._build("soft",&"tick",.94,.05)
 streams["preview"]=SYNTH._build("soft",&"done",1.12,.05)
 voice=AudioStreamPlayer.new();voice.bus="Voice";add_child(voice)
 load_preferences()
func cue(key: String) -> void:
 var now:=Time.get_ticks_msec()
 if key=="move":
  if now<quiet_until or now-last_move<85:return
  last_move=now
 if key in ["open","back"]:quiet_until=now+180
 var mapped: String={"unavailable":"deny","connect":"toggle_on","start":"done"}.get(key,key)
 var stream: AudioStream=streams.get(mapped)
 if not stream:
  var path:="res://assets/audio/ui/"+key+".wav"
  if ResourceLoader.exists(path):stream=load(path)
 if not stream:return
 var player:=players[next_player];next_player=(next_player+1)%players.size();player.stream=stream;player.play()
 cue_counts[key]=int(cue_counts.get(key,0))+1
func stop_effects() -> void:
 for player in players:player.stop()
func say(key: String) -> void:
 if not voice_enabled:return
 if Time.get_ticks_msec()-int(last_voice.get(key,-3000))<2000:return
 last_voice[key]=Time.get_ticks_msec()
 var path:="res://assets/audio/ui/voice_"+key+".wav"
 if ResourceLoader.exists(path):
  voice.stop();voice.stream=load(path);voice.play()
func set_level(bus: String,value: float) -> void:
 levels[bus]=value
 AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus),linear_to_db(maxf(.0001,value)))
 save_preferences()
func set_voice(value: bool) -> void:
 voice_enabled=value
 if not value:voice.stop()
 save_preferences()
func load_preferences() -> void:
 var cfg:=ConfigFile.new();cfg.load("user://leo_racer.cfg")
 for bus in levels:
  levels[bus]=float(cfg.get_value("ui_audio",bus,levels[bus]))
  AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus),linear_to_db(maxf(.0001,levels[bus])))
 voice_enabled=bool(cfg.get_value("ui_audio","voice_enabled",true))
func save_preferences() -> void:
 var game:=get_parent()
 if game.has_method("diagnostic_run") and game.diagnostic_run():return
 var cfg:=ConfigFile.new();cfg.load("user://leo_racer.cfg")
 for bus in levels:cfg.set_value("ui_audio",bus,levels[bus])
 cfg.set_value("ui_audio","voice_enabled",voice_enabled);cfg.save("user://leo_racer.cfg")
