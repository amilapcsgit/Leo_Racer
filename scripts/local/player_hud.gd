class_name LeoPlayerHUD
extends Control
var game: Node3D
var slot := 0
var title: Label
var info: Label
var speed: Label
var units: Label
var boost: ProgressBar
var boost_text: Label
var message: Label
var countdown: Label
var map_points := PackedVector2Array()
var map_min := Vector2(INF,INF)
var map_max := Vector2(-INF,-INF)
func make_label(font_size: int, color: Color = Color.WHITE) -> Label:
 var node:=Label.new();node.add_theme_font_override("font",load("res://assets/fonts/heading.ttf"));node.add_theme_font_size_override("font_size",font_size);node.add_theme_color_override("font_color",color);node.add_theme_color_override("font_shadow_color",Color.BLACK);node.add_theme_constant_override("shadow_offset_x",2);node.add_theme_constant_override("shadow_offset_y",2);add_child(node);return node
func _ready() -> void:
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_IGNORE
 title=make_label(25,Color("67d6db") if slot==0 else Color("e8b976"));info=make_label(22);speed=make_label(64)
 units=make_label(17)
 boost_text=make_label(19);message=make_label(24,Color("ffd180"));message.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 countdown=make_label(100);countdown.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 boost=ProgressBar.new();boost.max_value=1.;boost.show_percentage=false;add_child(boost)
 var fill:=StyleBoxFlat.new();fill.bg_color=Color("67d6db") if slot==0 else Color("e8b976");boost.add_theme_stylebox_override("fill",fill)
 rebuild_map()
func rebuild_map() -> void:
 map_points.clear();map_min=Vector2(INF,INF);map_max=Vector2(-INF,-INF)
 for point in game.circuit.points:
  var p:=Vector2(point.x,point.z);map_min=map_min.min(p);map_max=map_max.max(p)
 for point in game.circuit.points:map_points.append(map_position(Vector3(point)))
func map_position(point: Vector3) -> Vector2:
 var span:=map_max-map_min
 return Vector2(22,150)+(Vector2(point.x,point.z)-map_min)/maxf(span.x,span.y)*145.
func _process(_dt: float) -> void:
 if not game or not game.local_players[slot].kart:return
 var local: LeoLocalPlayer=game.local_players[slot]
 var kart:=local.kart
 visible=not local.photo
 var width:=get_viewport_rect().size.x;var height:=get_viewport_rect().size.y
 title.position=Vector2(20,15);title.size=Vector2(width-40,35)
 title.text="P%d / %s" % [slot+1,kart.racer_name]
 info.position=Vector2(20,55);info.size=Vector2(width-40,35)
 info.text="POS %d / 6    LAP %d / 3    %s" % [game.player_place(slot),kart.lap,game.format_time(kart.finish_time if kart.finished else game.race_time)]
 speed.position=Vector2(width-210,height-125);speed.size=Vector2(200,100);speed.text="%03d" % int(absf(kart.wheel_motion_speed)*3.6)
 units.position=Vector2(width-125,height-45);units.text="KM/H"
 boost.position=Vector2(22,height-50);boost.size=Vector2(maxf(140.,width*.33),18);boost.value=kart.boost_fuel
 boost_text.position=Vector2(22,height-88);boost_text.size=Vector2(width-40,35)
 boost_text.text="RELEASE DRIFT!" if kart.drifting and kart.drift_charge>=.65 else "NITRO READY" if kart.boost_fuel>=.999 else "NITRO %d%%" % int(kart.boost_fuel*100)
 message.position=Vector2(20,height*.35);message.size=Vector2(width-40,100)
 message.text="RETIRED / DNF" if kart.retired else "FINISHED / WAITING FOR PLAYER %d" % (2 if slot==0 else 1) if kart.finished else "WRONG WAY / TURN AROUND" if local.wrong_way>1. else local.announcement if local.announcement_time>0 else ""
 countdown.position=Vector2(width*.5-100,height*.48);countdown.size=Vector2(200,140)
 countdown.text=str(clampi(int(ceil(game.countdown)),1,3)) if game.state=="countdown" else "GO!" if game.race_time<.85 else ""
 queue_redraw()
func _draw() -> void:
 draw_style_box(background_style(),Rect2(8,7,get_viewport_rect().size.x-16,95))
 if map_points.size()>1:
  draw_polyline(map_points,Color(.1,.8,.9,.7),2.,true)
  draw_line(map_points[-1],map_points[0],Color(.1,.8,.9,.7),2.,true)
  for kart in game.karts:
   draw_circle(map_position(kart.position),5. if kart.local_slot==slot else 3.,Color("ffbe66") if kart.local_slot==slot else Color("70e8ee") if kart.is_player else Color("eeeeee"))
func background_style() -> StyleBoxFlat:
 var style:=StyleBoxFlat.new();style.bg_color=Color(.02,.04,.07,.8);style.corner_radius_top_left=8;style.corner_radius_top_right=8;style.corner_radius_bottom_left=8;style.corner_radius_bottom_right=8;return style
