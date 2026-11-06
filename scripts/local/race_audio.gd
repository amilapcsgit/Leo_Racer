class_name LeoRaceAudio
extends AudioStreamPlayer
## One shared music/announcer mix, independent of split-screen viewports.
const TRACKS=["strange_factory","rock_city","cheap_speed"]
var next: AudioStreamPlayer
var announcer: AudioStreamPlayer
var bag: Array[String]=[]
var last_track:=""
var fade:=0.
var crossing:=false
var duck:=0.
var announcement_count:=0
var cues: Dictionary={}
func _ready() -> void:
 bus="Music";volume_db=-9.
 next=AudioStreamPlayer.new();next.bus="Music";add_child(next)
 announcer=AudioStreamPlayer.new();announcer.bus="Announcer";announcer.volume_db=-1.;add_child(announcer)
 for cue in ["3","2","1","go"]:cues[cue]=load("res://assets/audio/racing278/voice_"+cue+".ogg")
 stream=pick();play()
func pick() -> AudioStream:
 if bag.is_empty():
  bag.assign(TRACKS);bag.shuffle()
  if bag.size()>1 and bag[0]==last_track:bag.reverse()
 last_track=bag.pop_front()
 var song:=load("res://assets/audio/racing278/"+last_track+".ogg") as AudioStreamOggVorbis
 song.loop=false
 return song
func announce(cue: String) -> void:
 if not cues.has(cue):return
 announcer.stream=cues[cue];announcer.play();duck=announcer.stream.get_length()+.25;announcement_count+=1
func stop_all() -> void:
 stop();next.stop();announcer.stop();duck=0.
func _process(dt: float) -> void:
 var game:=get_parent()
 stream_paused=not game.music_enabled
 next.stream_paused=stream_paused
 announcer.stream_paused=game.paused
 if not game.paused:duck=maxf(0.,duck-dt)
 if stream_paused:return
 var remaining:=stream.get_length()-get_playback_position()
 if not crossing and remaining<=2. and playing:
  next.stream=pick();next.volume_db=-70.;next.play();crossing=true;fade=0.
 var gain: float=-9. if game.state in ["countdown","race","finishing"] else -15.
 if duck>0.:gain-=9.
 if crossing:
  fade=minf(1.,fade+dt/2.)
  volume_db=gain+linear_to_db(maxf(.0001,1.-fade));next.volume_db=gain+linear_to_db(maxf(.0001,fade))
  if fade>=1.:
   var offset:=next.get_playback_position();stream=next.stream;next.stop();play(offset);crossing=false
 else:
  volume_db=move_toward(volume_db,gain,dt*45.)
  if not playing:stream=pick();play()
