class_name LeoControlMapPanel
extends Control
## Live labels and control overlays; the source SVG remains a Texture2D.
const ACTIONS=["accelerate","brake","left","right","drift","boost","recover","horn","look_back","change_camera","pause_race"]
const NAMES=["Accelerate","Brake","Steer left","Steer right","Drift","Boost","Recover","Horn","Look back","Camera","Pause"]
const GRID=2.
var player: LeoPlayerInput
var slot:=0
var accent:=Color("00e5ed")
var overlay: Control
var image: TextureRect
var kind:="keyboard"
var anchors: Dictionary={}
var control_bounds: Dictionary={}
var controls: Dictionary={}
var extras: Dictionary={}
var callouts: Array[Dictionary]=[]
var route_errors: Array[String]=[]
var signature:=""
var secondary: Label
var heading: Label
var font: Font
var used_paths: Dictionary={}
var drawing_bounds:=Rect2(0,0,360,240)
func _ready() -> void:
 mouse_filter=MOUSE_FILTER_IGNORE;font=load("res://assets/fonts/BarlowCondensed-BoldItalic.ttf")
 control_bounds=JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/controls/control-bounds-v1.json"))
 anchors=JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/controls/anchors.json"))
 image=TextureRect.new();image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;image.mouse_filter=MOUSE_FILTER_IGNORE;add_child(image)
 overlay=preload("res://scripts/ui/control_map_overlay.gd").new();overlay.panel=self;overlay.mouse_filter=MOUSE_FILTER_IGNORE;add_child(overlay)
 heading=label("",23);heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT;secondary=label("",17);secondary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;resized.connect(reflow)
 reflow()
func label(text: String,font_size: int) -> Label:
 var node:=Label.new();node.text=text;node.add_theme_font_override("font",font);node.add_theme_font_size_override("font_size",font_size);node.add_theme_color_override("font_outline_color",Color(0,0,0,.9));node.add_theme_constant_override("outline_size",3);node.mouse_filter=MOUSE_FILTER_IGNORE;node.clip_text=true;node.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;add_child(node);return node
static func device_kind(p: LeoPlayerInput) -> String:return "controller" if p.kind=="gamepad" else "wheel" if p.kind=="wheel" else "keyboard"
static func describe(p: LeoPlayerInput,action: String) -> String:
 var words:=p.describe(action)
 if p.kind=="wheel":
  var names: Array[String]=[]
  for binding in p.bindings.get(action,[]):
   names.append("B%d"%int(binding.index) if binding.type=="button" else "Axis %d"%int(binding.index) if binding.type=="axis" else OS.get_keycode_string(int(binding.index)))
  words=" / ".join(names) if not names.is_empty() else "UNBOUND"
 return words.replace("Right Stick Click","R3").replace("Left Stick Click","L3").replace("Left Stick","LS").replace("Right Stick","RS").replace("Left Shift","LShift").replace("Right Shift","RShift").replace("Shift","SHIFT").replace("Space","SPACE")
static func binding_id(device: String,binding: Dictionary,action: String) -> String:
 var index:=int(binding.get("index",-1));var type:=String(binding.get("type",""))
 if device=="keyboard" and type=="key":
  var key:=OS.get_keycode_string(index).to_upper()
  if int(binding.get("location",0))==2:key="RIGHT_"+key
  return "key_"+key
 if device=="controller":
  if type=="button":return {JOY_BUTTON_A:"button_a",JOY_BUTTON_B:"button_b",JOY_BUTTON_X:"button_x",JOY_BUTTON_Y:"button_y",JOY_BUTTON_LEFT_SHOULDER:"l1",JOY_BUTTON_RIGHT_SHOULDER:"r1",JOY_BUTTON_LEFT_STICK:"left_stick",JOY_BUTTON_RIGHT_STICK:"right_stick",JOY_BUTTON_START:"menu",JOY_BUTTON_BACK:"view",JOY_BUTTON_DPAD_LEFT:"dpad_left",JOY_BUTTON_DPAD_RIGHT:"dpad_right",JOY_BUTTON_DPAD_UP:"dpad_up",JOY_BUTTON_DPAD_DOWN:"dpad_down"}.get(index,"button_"+str(index))
  if type=="axis":
   if index==JOY_AXIS_TRIGGER_RIGHT:return "r2"
   if index==JOY_AXIS_TRIGGER_LEFT:return "l2"
   var direction: String=("left" if index in [JOY_AXIS_LEFT_X,JOY_AXIS_RIGHT_X] else "up") if float(binding.get("pressed",1.))<float(binding.get("rest",0.)) else ("right" if index in [JOY_AXIS_LEFT_X,JOY_AXIS_RIGHT_X] else "down")
   return ("left_stick_" if index in [JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y] else "right_stick_")+direction if index in [JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y,JOY_AXIS_RIGHT_X,JOY_AXIS_RIGHT_Y] else "axis_"+str(index)
 if device=="wheel" and type=="axis":
  if index==JOY_AXIS_LEFT_X:return "rim_left" if float(binding.get("pressed",1.))<float(binding.get("rest",0.)) else "rim_right"
  if index==JOY_AXIS_TRIGGER_LEFT:return "brake"
  if index==JOY_AXIS_TRIGGER_RIGHT:return "accelerator"
 return type+"_"+str(index)
func primary_id(action: String) -> String:
 var bindings: Array=player.bindings.get(action,[])
 return binding_id(kind,bindings[0],action) if not bindings.is_empty() else ""
func build_controls(origin: Vector2,scale_factor: float) -> void:
 controls.clear();extras.clear()
 for key in anchors[kind]:
  var raw: Array=anchors[kind][key];var extent:=Vector2(23,25)
  if kind=="keyboard":
   if key=="key_SHIFT":extent=Vector2(56,25)
   elif key=="key_SPACE":extent=Vector2(146,25)
  elif kind=="controller":extent=Vector2(24,24) if key in ["left_stick","right_stick","dpad"] else Vector2(18,18)
  else:extent=Vector2(24,24)
  var at:=Vector2(float(raw[0]),float(raw[1]));var rect:=Rect2(at-extent*.5,extent)
  if control_bounds[kind].has(key):
   var bounds: Array=control_bounds[kind][key];rect=Rect2(float(bounds[0]),float(bounds[1]),float(bounds[2]),float(bounds[3]))
  controls[key]={"point":origin+at*scale_factor,"rect":Rect2(origin+rect.position*scale_factor,rect.size*scale_factor),"extra":false}
 if kind=="keyboard":
  var active: Array[String]=[]
  for action in ACTIONS.slice(0,6):active.append(primary_id(action))
  for key in controls.keys():
   if key not in active:controls.erase(key)
 if kind=="keyboard":
  for key in controls:controls[key].point=controls[key].rect.position+Vector2(3.,3.)
 if kind=="controller":
  for pair in [["dpad_left",Vector2(134,164)],["dpad_right",Vector2(154,164)],["dpad_up",Vector2(144,154)],["dpad_down",Vector2(144,174)]]:
   controls[pair[0]]={"point":origin+pair[1]*scale_factor,"rect":controls.dpad.rect,"extra":false}
  for stick in ["left_stick","right_stick"]:
   for direction in ["left","right","up","down"]:
    var offset: Vector2={"left":Vector2(-8,0),"right":Vector2(8,0),"up":Vector2(0,-8),"down":Vector2(0,8)}[direction]
    controls[stick+"_"+direction]={"point":controls[stick].point+offset*scale_factor,"rect":controls[stick].rect,"extra":false}
 if kind=="wheel":
  for pair in [["rim_left",Vector2(65,70)],["rim_right",Vector2(249,70)]]:controls[pair[0]]={"point":origin+pair[1]*scale_factor,"rect":Rect2(origin+(pair[1]-Vector2(10,10))*scale_factor,Vector2(20,20)*scale_factor),"extra":false}
 for action in ACTIONS.slice(0,6):
  var key:=primary_id(action)
  if key!="" and not controls.has(key):extras[key]=describe(player,action).split(" / ")[0]
 var index:=0;var width:=minf(60.,(size.x-80.)/maxi(1,extras.size()))
 for key in extras:
  var at:=Vector2(size.x*.5-float(extras.size())*width*.5+(index+.5)*width,size.y-62.)
  controls[key]={"point":at,"rect":Rect2(at-Vector2(width*.45,13),Vector2(width*.9,26)),"extra":true};index+=1
func preferred(key: String) -> String:
 if kind=="controller":
  if key in ["l1","l2","r1","r2","menu","view"]:return "top"
  if key.begins_with("left_stick") or key in ["dpad","dpad_left","dpad_right","dpad_up","dpad_down"]:return "left"
  if key.begins_with("right_stick"):return "bottom"
  return "right"
 if kind=="keyboard":
  if key in ["key_C","key_V","key_SPACE"]:return "bottom"
  if key in ["key_R","key_H"]:return "top"
  if key in ["key_D","key_P"]:return "right"
  return "left" if float(controls[key].point.x)<size.x*.5 else "right"
 return "bottom" if controls[key].extra else "left" if float(controls[key].point.x)<size.x*.5 else "right"
func focused_keyboard() -> Texture2D:
 var selected: Array[String]=[];var bounds:=Rect2();var first:=true
 for action in ACTIONS.slice(0,6):
  var key:=primary_id(action)
  if not control_bounds.keyboard.has(key):continue
  selected.append(key);var raw: Array=control_bounds.keyboard[key]
  var rect:=Rect2(float(raw[0]),float(raw[1]),float(raw[2]),float(raw[3]))
  bounds=rect if first else bounds.merge(rect);first=false
 if first:drawing_bounds=Rect2(0,0,360,240);return load("res://assets/ui/controls/keyboard.svg")
 drawing_bounds=bounds.grow(12.)
 var svg:=FileAccess.get_file_as_string("res://assets/ui/controls/keyboard.svg")
 var groups:=RegEx.new();groups.compile("(?s)<g id=\"([^\"]+)\">.*?</g>")
 for found in groups.search_all(svg):
  if found.get_string(1) not in selected:svg=svg.replace(found.get_string(),"")
 var plate:=RegEx.new();plate.compile("<rect[^>]+/>");var old:=plate.search(svg)
 if old:svg=svg.replace(old.get_string(),"")
 svg=svg.replace('viewBox="0 0 360 240"','viewBox="%f %f %f %f"'%[drawing_bounds.position.x,drawing_bounds.position.y,drawing_bounds.size.x,drawing_bounds.size.y])
 svg=svg.replace('width="360" height="240"','width="%f" height="%f"'%[drawing_bounds.size.x,drawing_bounds.size.y])
 var bitmap:=Image.new();bitmap.load_svg_from_string(svg,3.)
 return ImageTexture.create_from_image(bitmap)
func slots() -> Array[Dictionary]:
 var result: Array[Dictionary]=[];var width:=132.
 var left:=maxf(10.,image.position.x-width-14.)
 var right:=minf(size.x-width-10.,image.position.x+image.size.x+14.)
 for i in 4:
  var y:=48.+float(i)*45.
  result.append({"side":"left","rect":Rect2(left,y,width,40),"port":Vector2(left+width+5.,y+20)})
  result.append({"side":"right","rect":Rect2(right,y,width,40),"port":Vector2(right-5.,y+20)})
 return result
func reflow() -> void:
 if not is_inside_tree() or not player or not image:return
 kind=device_kind(player);accent=Color("00e5ed") if slot==0 else Color("ffc857")
 drawing_bounds=Rect2(0,0,360,240)
 image.texture=focused_keyboard() if kind=="keyboard" else load("res://assets/ui/controls/"+kind+".svg")
 image.position=Vector2(size.x*.5-155.,42.)
 image.size=Vector2(310.,190.)
 var fit:=minf(image.size.x/drawing_bounds.size.x,image.size.y/drawing_bounds.size.y);var origin:=image.position+(image.size-drawing_bounds.size*fit)*.5-drawing_bounds.position*fit
 build_controls(origin,fit)
 for row in callouts:row.title.queue_free();row.binding.queue_free()
 callouts.clear();route_errors.clear();used_paths.clear()
 heading.text="PLAYER %d · %s"%[slot+1,player.kind.to_upper()];heading.position=Vector2(18,5);heading.size=Vector2(size.x-36,32);heading.add_theme_color_override("font_color",accent)
 var available:=slots()
 var secondary_words: Array[String]=[]
 for i in range(6,ACTIONS.size()):secondary_words.append(NAMES[i]+" "+(describe(player,ACTIONS[i]) if primary_id(ACTIONS[i])!="" else "Not assigned"))
 secondary.text="   ".join(secondary_words);secondary.position=Vector2(18,size.y-43.);secondary.size=Vector2(size.x-36,40);secondary.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 for i in 6:
  var action: String=ACTIONS[i];var key:=primary_id(action);var desired:=preferred(key) if key!="" else "bottom"
  var best:=0;var cost:=INF
  for n in available.size():
   var point: Vector2=controls[key].point if key!="" else Vector2(size.x*.5,size.y)
   var score:=point.distance_squared_to(available[n].port)+(0. if available[n].side==desired else 6000.)
   if score<cost:cost=score;best=n
  var place: Dictionary=available.pop_at(best)
  var title:=label(NAMES[i],21);var binding:=label(describe(player,action) if key!="" else "Not assigned",17)
  title.position=place.rect.position;title.size=Vector2(place.rect.size.x,20);binding.position=title.position+Vector2(0,21);binding.size=Vector2(place.rect.size.x,20)
  title.add_theme_color_override("font_color",Color.WHITE if key!="" else Color("95a6b2"));binding.add_theme_color_override("font_color",accent if key!="" else Color("95a6b2"))
  for node in [title,binding]:node.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT if place.side=="left" else HORIZONTAL_ALIGNMENT_LEFT if place.side=="right" else HORIZONTAL_ALIGNMENT_CENTER
  callouts.append({"action":action,"key":key,"rect":place.rect,"port":place.port,"title":title,"binding":binding,"side":place.side,"path":PackedVector2Array()})
 for attempt in 16:
  used_paths.clear();route_errors.clear()
  for row in callouts:
   if row.key!="":row.path=route(row.port,controls[row.key].point,row.key)
  var crossed:=crossing_pair()
  if crossed.x<0:break
  var first: Dictionary=callouts[crossed.x];var second: Dictionary=callouts[crossed.y]
  var old_rect: Rect2=first.rect;var old_port: Vector2=first.port;var old_side: String=first.side
  first.rect=second.rect;first.port=second.port;first.side=second.side;second.rect=old_rect;second.port=old_port;second.side=old_side
  for row in [first,second]:
   row.title.position=row.rect.position;row.title.size.x=row.rect.size.x;row.binding.position=row.rect.position+Vector2(0,21);row.binding.size.x=row.rect.size.x
   for node in [row.title,row.binding]:node.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT if row.side=="left" else HORIZONTAL_ALIGNMENT_LEFT if row.side=="right" else HORIZONTAL_ALIGNMENT_CENTER
 overlay.size=size;overlay.queue_redraw();queue_redraw()
func crossing_pair() -> Vector2i:
 for i in callouts.size():
  var a: Dictionary=callouts[i]
  if a.key=="":continue
  for j in range(i+1,callouts.size()):
   var b: Dictionary=callouts[j]
   if b.key=="" or controls[a.key].rect==controls[b.key].rect:continue
   for x in range(1,a.path.size()):
    for y in range(1,b.path.size()):
     if Geometry2D.segment_intersects_segment(a.path[x-1],a.path[x],b.path[y-1],b.path[y])!=null:return Vector2i(i,j)
 return Vector2i(-1,-1)
func solid_rect(grid: AStarGrid2D,rect: Rect2,solid: bool) -> void:
 var from:=Vector2i((rect.position/GRID).ceil());var to:=Vector2i((rect.end/GRID).floor())
 for x in range(maxi(0,from.x),mini(grid.region.end.x,to.x+1)):
  for y in range(maxi(0,from.y),mini(grid.region.end.y,to.y+1)):grid.set_point_solid(Vector2i(x,y),solid)
func route(start: Vector2,target: Vector2,key: String) -> PackedVector2Array:
 var grid:=AStarGrid2D.new();grid.region=Rect2i(Vector2i.ZERO,Vector2i((size/GRID).ceil())+Vector2i.ONE);grid.cell_size=Vector2.ONE*GRID;grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER;grid.default_compute_heuristic=AStarGrid2D.HEURISTIC_MANHATTAN;grid.default_estimate_heuristic=AStarGrid2D.HEURISTIC_MANHATTAN;grid.update()
 for id in controls:
  if id!=key and controls[id].rect!=controls[key].rect:solid_rect(grid,controls[id].rect.grow(-.7),true)
 solid_rect(grid,Rect2(secondary.position,secondary.size),true)
 for row in callouts:solid_rect(grid,row.rect.grow(3.),true)
 for cell in used_paths:
  if grid.is_in_boundsv(cell):grid.set_point_weight_scale(cell,1000000.)
 var a:=Vector2i((start/GRID).round());var b:=Vector2i((target/GRID).round());grid.set_point_solid(a,false);grid.set_point_solid(b,false)
 var path:=grid.get_point_path(a,b)
 if path.is_empty():route_errors.append(key);return path
 for point in path:
  var cell:=Vector2i((point/GRID).round());used_paths[cell]=true
 var simplified:=PackedVector2Array([start])
 for i in range(1,path.size()-1):
  if (path[i]-path[i-1]).normalized()!=(path[i+1]-path[i]).normalized():simplified.append(path[i])
 simplified.append(target);return simplified
func _draw() -> void:
 if not image:return
 var plate:=StyleBoxFlat.new();plate.bg_color=Color(.02,.045,.065,.30);plate.border_color=Color(accent,.65);plate.set_border_width_all(1);plate.set_corner_radius_all(18);draw_style_box(plate,Rect2(Vector2.ZERO,size))
 for key in extras:
  var rect: Rect2=controls[key].rect;draw_rect(rect,Color("173643"));draw_rect(rect,accent,false,1.);draw_string(font,rect.position+Vector2(4,19),extras[key],HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-8,14,Color.WHITE)
func draw_connections(canvas: Control) -> void:
 for row in callouts:
  if row.key=="":continue
  var point: Vector2=controls[row.key].point
  canvas.draw_rect(controls[row.key].rect.grow(-1.),Color(accent,.18),true)
  if row.path.size()>1:canvas.draw_polyline(row.path,accent,1.6,true);canvas.draw_circle(point,2.8,accent,true,-1,true)
