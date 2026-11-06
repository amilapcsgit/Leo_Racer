class_name LeoCockpitCanvas
extends Control
var kart: LeoKart
var navigation:=false
var font: Font
var map_pose:=Transform2D.IDENTITY
func _ready() -> void:
 font=load("res://assets/fonts/BarlowCondensed-BoldItalic.ttf").duplicate()
 if font is FontFile:font.multichannel_signed_distance_field=false
 mouse_filter=MOUSE_FILTER_IGNORE
 if navigation:map_pose=LeoTelemetry.map_transform(kart.circuit.points,Rect2(26,65,size.x-52,size.y-110))
func line(at: Vector2,words: String,height: int,color: Color=Color.WHITE,width: float=-1.) -> void:draw_string(font,at,words,HORIZONTAL_ALIGNMENT_LEFT,width,height,color)
func _draw() -> void:
 if not is_instance_valid(kart) or not font:return
 var cyan:=Color("61eef1");var gold:=Color("ffc857");var speed:=int(absf(kart.wheel_motion_speed)*3.6)
 draw_rect(Rect2(Vector2.ZERO,size),Color("071119"));draw_rect(Rect2(3,3,size.x-6,size.y-6),Color("183640"),false,3.)
 if navigation:
  line(Vector2(24,38),"LEO NAV  /  "+String(kart.get_parent().track_definition.display_name).to_upper(),24,cyan,size.x-50)
  var path:=PackedVector2Array()
  for i in range(0,kart.circuit.points.size(),3):
   var p: Vector3=kart.circuit.points[i];path.append(map_pose*Vector2(p.x,p.z))
  if path.size()>1:path.append(path[0]);draw_polyline(path,Color("234653"),12,true);draw_polyline(path,cyan,4,true)
  for rival in kart.get_parent().karts:
   var at: Vector2=map_pose*Vector2(rival.position.x,rival.position.z)
   draw_circle(at,8. if rival==kart else 4.,gold if rival==kart else Color("7094a5"),true,-1,true)
  var music: Variant=kart.get_parent().get("music")
  line(Vector2(24,size.y-17),"♪ "+String(music.last_track).replace("_"," ").capitalize() if music is LeoRaceAudio else "LEO RACER",20,Color("bacdd4"),size.x-48)
 else:
  var rpm: float=kart.motor_audio.rpm if kart.motor_audio else 900.
  var gear: int=kart.motor_audio.gear if kart.motor_audio else 1
  var c:=Vector2(103,128);draw_arc(c,45,deg_to_rad(135),deg_to_rad(405),64,Color("28414c"),7,true)
  draw_arc(c,45,deg_to_rad(135),deg_to_rad(135+maxf(.01,clampf(rpm/8000.,0.,1.))*270),64,cyan,7,true)
  line(Vector2(70,140),str(int(rpm)),24,Color.WHITE);line(Vector2(85,166),"RPM",14,cyan)
  line(Vector2(223,146),"%03d"%speed,66,Color.WHITE);line(Vector2(242,176),"KM/H",16,cyan)
  line(Vector2(420,141),"R" if kart.wheel_motion_speed<-.2 else "N" if not kart.active else str(gear),49,gold)
  var enabled: bool=kart.vehicle_lighting!=null and kart.vehicle_lighting.headlights_on
  line(Vector2(25,30),"LIGHTS ON" if enabled else "LIGHTS OFF",16,cyan if enabled else Color("667d88"))
  line(Vector2(359,175),"BOOST %d%%"%int(kart.boost_fuel*100),17,gold)
  draw_rect(Rect2(22,182,(size.x-44)*kart.boost_fuel,5),cyan)
