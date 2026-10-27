class_name LeoPlayerHUD
extends Control
var game: Node3D
var slot:=0
var title: Label
var info: Label
var speed: Label
var units: Label
var boost: TextureProgressBar
var boost_text: Label
var message: Label
var countdown: Label
var tip: Label
var track: Label
var map_points:=PackedVector2Array()
var map_min:=Vector2(INF,INF)
var map_max:=Vector2(-INF,-INF)
var previous_size:=Vector2.ZERO
var last_ready:=true
var elapsed:=0.
func make_label(fs: int,color: Color=Color.WHITE) -> Label:
 var node:=Label.new();node.add_theme_font_override("font",load("res://assets/fonts/heading.ttf"));node.add_theme_font_size_override("font_size",fs);node.add_theme_color_override("font_color",color);node.add_theme_color_override("font_outline_color",Color("050b12"));node.add_theme_constant_override("outline_size",2);node.mouse_filter=MOUSE_FILTER_IGNORE;add_child(node);return node
func _ready() -> void:
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_IGNORE
 title=make_label(22,Color("43e7ef") if slot==0 else Color("ffc857"));info=make_label(26);speed=make_label(72);units=make_label(20)
 boost_text=make_label(22,Color("43e7ef"));message=make_label(30,Color("ffc857"));message.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 countdown=make_label(110,Color("ffc857"));countdown.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 tip=make_label(20);tip.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 track=make_label(28);track.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 boost=TextureProgressBar.new();boost.max_value=1.;boost.texture_under=load("res://assets/ui/icons/nitro_empty.svg");boost.texture_progress=load("res://assets/ui/icons/nitro_fill.svg");boost.nine_patch_stretch=true;boost.mouse_filter=MOUSE_FILTER_IGNORE;add_child(boost)
 rebuild_map()
func rebuild_map() -> void:
 map_points.clear();map_min=Vector2(INF,INF);map_max=Vector2(-INF,-INF)
 if not game.circuit:return
 for point in game.circuit.points:
  var p:=Vector2(point.x,point.z);map_min=map_min.min(p);map_max=map_max.max(p)
 for point in game.circuit.points:map_points.append(map_position(Vector3(point)))
func map_position(point: Vector3) -> Vector2:
 var span:=map_max-map_min
 return Vector2(28,size.y-220)+(Vector2(point.x,point.z)-map_min)/maxf(1.,maxf(span.x,span.y))*155.
func _process(dt: float) -> void:
 if not game or not game.local_players[slot].kart:return
 if size!=previous_size:previous_size=size;rebuild_map()
 if not game.paused:elapsed+=dt
 var local: LeoLocalPlayer=game.local_players[slot];var kart:=local.kart;var p: LeoPlayerInput=game.input_router.players[slot]
 visible=not local.photo
 var width:=size.x;var height:=size.y;var compact: bool=game.human_count==2
 title.position=Vector2(28,20);title.size=Vector2(width-56,32);title.text="P%d · %s" % [slot+1,kart.racer_name]
 info.position=Vector2(28,54);info.size=Vector2(width-56,40);info.text="#%d / 6     Lap %d / 3     %s" % [game.player_place(slot),kart.lap,game.format_time(kart.finish_time if kart.finished else game.race_time)]
 speed.position=Vector2(width-220,height-170);speed.size=Vector2(190,95);speed.text="%03d" % int(absf(kart.wheel_motion_speed)*3.6);speed.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
 units.position=Vector2(width-100,height-80);units.text="KM/H"
 boost.position=Vector2(width-258,height-50);boost.size=Vector2(228,18);boost.value=kart.boost_fuel
 var ready:=kart.boost_fuel>=.999
 boost.modulate=Color(1,1,1,1. if game.reduced_motion or not ready else .82+.18*(.5+.5*sin(elapsed*TAU/1.4)))
 boost_text.position=Vector2(width-290,height-217);boost_text.size=Vector2(265,38);boost_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
 boost_text.text=("Nitro Ready · "+p.describe("boost")) if ready else "Nitro %d%%" % int(kart.boost_fuel*100)
 if ready and not last_ready and not game.paused:
  if game.hud:game.hud.play_arcade_cue("ready")
 last_ready=ready
 message.position=Vector2(24,height*.3);message.size=Vector2(width-48,100)
 message.text="Race finished · Waiting for Player %d" % (2 if slot==0 else 1) if kart.finished and game.human_count==2 else "Race finished" if kart.finished else "Turn around!" if local.wrong_way>1. else local.announcement if local.announcement_time>0 else "Release Drift for a boost!" if kart.drifting and kart.drift_charge>=.65 else ""
 if kart.checkpoint_missed and not kart.finished:message.text="Checkpoint missed / "+p.describe("recover")+" Recover"
 countdown.position=Vector2(width*.5-130,height*.43);countdown.size=Vector2(260,140);countdown.text=str(clampi(int(ceil(game.countdown)),1,3)) if game.state=="countdown" else "GO!" if game.race_time<.85 else ""
 tip.position=Vector2(210,height-56);tip.size=Vector2(maxf(100,width-530),50);tip.text="Drift "+p.describe("drift")+"   ·   Nitro "+p.describe("boost")+"   ·   Esc Pause";tip.visible=not compact and game.race_time<9.
 track.position=Vector2(width*.15,110);track.size=Vector2(width*.7,60);track.text=game.track_definition.display_name;track.visible=game.race_time<4.
 queue_redraw()
func _draw() -> void:
 var color:=Color(.035,.055,.085,.84)
 draw_colored_polygon(PackedVector2Array([Vector2(16,12),Vector2(minf(size.x-16,530),12),Vector2(minf(size.x-28,518),104),Vector2(16,104)]),color)
 draw_rect(Rect2(16,size.y-232,180,180),color)
 draw_colored_polygon(PackedVector2Array([Vector2(size.x-268,size.y-230),Vector2(size.x-18,size.y-230),Vector2(size.x-18,size.y-20),Vector2(size.x-294,size.y-20)]),color)
 if map_points.size()>1:
  draw_polyline(map_points,Color("43e7ef"),2.,true);draw_line(map_points[-1],map_points[0],Color("43e7ef"),2.,true)
  for kart in game.karts:draw_circle(map_position(kart.position),5. if kart.local_slot==slot else 3.,Color("ffc857") if kart.local_slot==slot else Color("43e7ef") if kart.is_player else Color("b9c7d6"))
