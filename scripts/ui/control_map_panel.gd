class_name LeoControlMapPanel
extends Control
## A predictable binding-to-action list, including saved device remappings.
const ACTIONS=["accelerate","brake","left","right","drift","boost","recover","horn","look_back","change_camera","pause_race"]
const NAMES=["Accelerate","Brake","Steer left","Steer right","Drift","Nitro","Recover","Horn","Look back","Camera","Pause"]
const PLATE_COLOR=Color(.025,.045,.075,.32)
var player: LeoPlayerInput
var slot:=0
var accent:=Color("69e4ed")
var kind:="keyboard"
var callouts: Array[Dictionary]=[]
var heading: Label
var secondary: Label
var font: Font
var signature:=""
var row_height:=45.
var render_scale:=1.
var device_texture: Texture2D
var device_rect:=Rect2()
var anchor_data: Dictionary={}
func _ready() -> void:
 mouse_filter=MOUSE_FILTER_IGNORE
 font=load("res://assets/fonts/body.ttf")
 heading=label("",30);secondary=label("",23)
 heading.add_theme_font_override("font",load("res://assets/fonts/BarlowCondensed-BoldItalic.ttf"))
 secondary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 resized.connect(reflow);reflow()
func label(words: String,font_size: int) -> Label:
 var node:=Label.new();node.text=words
 node.add_theme_font_override("font",font);node.add_theme_font_size_override("font_size",font_size)
 node.add_theme_color_override("font_color",Color("f5f9fc"))
 node.mouse_filter=MOUSE_FILTER_IGNORE;node.clip_text=true
 node.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 node.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;add_child(node);return node
static func device_kind(p: LeoPlayerInput) -> String:
 return "controller" if p.kind=="gamepad" else "wheel" if p.kind=="wheel" else "keyboard"
static func describe(p: LeoPlayerInput,action: String) -> String:
 if p.bindings.get(action,[]).is_empty():return "Not assigned"
 var words:=p.describe(action)
 return words.replace("Right Stick Click","R3").replace("Left Stick Click","L3").replace("Left Stick","LS").replace("Right Stick","RS").replace("Left Shift","L Shift").replace("Right Shift","R Shift").replace("Kp ","Num ").replace("Kp","Num ")
static func binding_id(device: String,binding: Dictionary,action: String) -> String:
 var index:=int(binding.get("index",-1));var type:=String(binding.get("type",""))
 if device=="keyboard" and type=="key":
  var key:=OS.get_keycode_string(index).to_upper()
  if int(binding.get("location",0))==2:key="RIGHT_"+key
  return "key_"+key
 if device=="controller":
  if type=="button":return {JOY_BUTTON_A:"button_a",JOY_BUTTON_B:"button_b",JOY_BUTTON_X:"button_x",JOY_BUTTON_Y:"button_y",JOY_BUTTON_LEFT_SHOULDER:"l1",JOY_BUTTON_RIGHT_SHOULDER:"r1",JOY_BUTTON_LEFT_STICK:"left_stick",JOY_BUTTON_RIGHT_STICK:"right_stick",JOY_BUTTON_START:"menu",JOY_BUTTON_BACK:"view"}.get(index,"button_"+str(index))
  if type=="axis":return "axis_"+str(index)+("_negative" if float(binding.get("pressed",1.))<float(binding.get("rest",0.)) else "_positive")
 return type+"_"+str(index)
func primary_id(action: String) -> String:
 var bindings: Array=player.bindings.get(action,[])
 return binding_id(kind,bindings[0],action) if not bindings.is_empty() else ""
func binding_text(action: String) -> String:
 var bindings: Array=player.bindings.get(action,[])
 if bindings.is_empty():return "Not assigned"
 var bound: Dictionary=bindings[0]
 if bound.get("type","")=="axis":
  var axis:=int(bound.get("index",0));var negative:=float(bound.get("pressed",1.))<float(bound.get("rest",0.))
  if player.kind=="gamepad":
   if axis==JOY_AXIS_TRIGGER_LEFT:return "LT"
   if axis==JOY_AXIS_TRIGGER_RIGHT:return "RT"
   if axis in [JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y,JOY_AXIS_RIGHT_X,JOY_AXIS_RIGHT_Y]:
    var stick: String="LS" if axis in [JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y] else "RS"
    if action=="left" and same_steering_axis():return stick+" ← / →"
    return stick+" "+(("←" if negative else "→") if axis in [JOY_AXIS_LEFT_X,JOY_AXIS_RIGHT_X] else ("↑" if negative else "↓"))
  return "Axis %d %s"%[axis,"−" if negative else "+"]
 if player.kind=="wheel" and bound.get("type","")=="button":return "Button %d"%int(bound.get("index",0))
 # The primary binding is always usable; the complete list stays in Controls.
 var first:=LeoPlayerInput.new(player.kind)
 first.bindings[action]=[bindings[0]]
 return describe(first,action)
func current_signature() -> String:
 return str(size)+str(get_global_transform_with_canvas().get_scale())+player.kind+JSON.stringify(player.bindings)
func load_device() -> void:
 var bytes:=FileAccess.get_file_as_bytes("res://assets/ui/controls/"+kind+"-279.png")
 var image:=Image.new()
 if image.load_png_from_buffer(bytes)==OK:
  var texture:=ImageTexture.create_from_image(image)
  if kind=="keyboard":
   var atlas:=AtlasTexture.new();atlas.atlas=texture;atlas.region=Rect2(Vector2(image.get_size())*Vector2(.02,.25),Vector2(image.get_size())*Vector2(.96,.55));device_texture=atlas
  else:device_texture=texture
 anchor_data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/controls/anchors-279.json"))
func same_steering_axis() -> bool:
 var left: Array=player.bindings.get("left",[]);var right: Array=player.bindings.get("right",[])
 return not left.is_empty() and not right.is_empty() and left[0].get("type")=="axis" and right[0].get("type")=="axis" and left[0].get("index")==right[0].get("index")
func anchor_for(action: String) -> Vector2:
 var bindings: Array=player.bindings.get(action,[])
 var key:=primary_id(action)
 if not bindings.is_empty() and String(bindings[0].get("type",""))=="axis":
  var index:=int(bindings[0].index)
  if kind=="controller":key="l2" if index==JOY_AXIS_TRIGGER_LEFT else "r2" if index==JOY_AXIS_TRIGGER_RIGHT else "left_stick" if index in [JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y] else "right_stick"
  elif kind=="wheel":key="accelerator" if action=="accelerate" else "brake" if action=="brake" else "rim"
 if kind=="keyboard" and key.begins_with("key_RIGHT_"):key=key.replace("key_RIGHT_","key_")
 var data: Dictionary=anchor_data.get(kind,{})
 if data.has(key):
  var at: Array=data[key]
  return device_rect.position+Vector2(float(at[0])/360.,float(at[1])/240.)*device_rect.size
 return Vector2(-1,-1)
func _process(_dt: float) -> void:
 if is_visible_in_tree() and player and signature!=current_signature():reflow()
func reflow() -> void:
 if not is_inside_tree() or not player or not heading:return
 signature=current_signature()
 var next_kind:=device_kind(player)
 if next_kind!=kind or not device_texture:kind=next_kind;load_device()
 render_scale=maxf(.1,absf(get_global_transform_with_canvas().get_scale().y))
 accent=Color("69e4ed") if slot==0 else Color("ffd078")
 var fs:=maxi(25,int(ceil(20./render_scale)))
 var binding_fs:=maxi(23,int(ceil(18./render_scale)))
 heading.text="PLAYER %d  ·  %s"%[slot+1,"CONTROLLER" if kind=="controller" else kind.to_upper()]
 heading.position=Vector2(20,5);heading.size=Vector2(size.x-40,37)
 heading.add_theme_font_size_override("font_size",maxi(30,int(ceil(24./render_scale))))
 heading.add_theme_color_override("font_color",accent)
 var aspect:=2.62 if kind=="keyboard" else 1.5
 var image_width:=minf((size.y-68.)*aspect,size.x*.52)
 var image_height:=image_width/aspect
 device_rect=Rect2(Vector2((size.x-image_width)*.5,45.+(size.y-68.-image_height)*.5),Vector2(image_width,image_height))
 for row in callouts:
  row.title.free();row.binding.free()
 callouts.clear()
 var gap:=18.;var label_width:=minf(185.,(size.x-device_rect.size.x)*.5-gap-12.)
 for i in 6:
  var side:=i in [1,3,4] if kind=="keyboard" else i in [0,3,4,5]
  var rank: int={0:0,1:0,2:1,3:1,4:2,5:2}[i] if kind=="keyboard" else {0:0,1:0,2:1,3:1,4:2,5:1}[i]
  var at:=Vector2(device_rect.end.x+gap if side else device_rect.position.x-gap-label_width,49.+rank*63.)
  var title:=label(NAMES[i],fs)
  title.position=at;title.size=Vector2(label_width,29)
  title.add_theme_constant_override("outline_size",4)
  title.add_theme_color_override("font_outline_color",Color(.01,.02,.035,.95))
  var binding:=label(binding_text(ACTIONS[i]),binding_fs)
  binding.position=at+Vector2(0,32);binding.size=Vector2(label_width,29)
  binding.add_theme_color_override("font_color",accent)
  binding.add_theme_constant_override("outline_size",3)
  binding.add_theme_color_override("font_outline_color",Color(.01,.02,.035,.95))
  if kind!="keyboard" and same_steering_axis() and i==3:title.hide();binding.hide()
  if kind!="keyboard" and same_steering_axis() and i==2:title.text="Steer"
  if not side:title.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;binding.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
  callouts.append({"action":ACTIONS[i],"key":primary_id(ACTIONS[i]),"rect":Rect2(at,Vector2(label_width,62)),"title":title,"binding":binding,"anchor":anchor_for(ACTIONS[i]),"side":side})
 var extras: Array[String]=[]
 for i in range(6,ACTIONS.size()):extras.append(NAMES[i]+" "+binding_text(ACTIONS[i]))
 secondary.text="  ·  ".join(extras)
 secondary.position=Vector2(18,size.y-28);secondary.size=Vector2(size.x-36,26)
 secondary.add_theme_font_size_override("font_size",maxi(17,int(ceil(13./render_scale))))
 secondary.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 secondary.add_theme_constant_override("outline_size",3)
 secondary.add_theme_color_override("font_outline_color",Color(.01,.02,.035,.95))
 queue_redraw()
func _draw() -> void:
 var plate:=StyleBoxFlat.new();plate.bg_color=PLATE_COLOR
 plate.border_color=Color(accent,.55);plate.set_border_width_all(1);plate.set_corner_radius_all(15)
 draw_style_box(plate,Rect2(Vector2.ZERO,size))
 draw_line(Vector2(20,43),Vector2(size.x-20,43),Color(accent,.25),1.)
 if device_texture:draw_texture_rect(device_texture,device_rect,false,Color(1,1,1,.94))
 for row in callouts:
  if not row.title.visible:continue
  var target: Vector2=row.anchor
  if target.x<0:continue
  var rect: Rect2=row.rect
  var start:=Vector2(rect.position.x-5 if row.side else rect.end.x+5,rect.position.y+25.)
  var bend:=Vector2(device_rect.end.x+8 if row.side else device_rect.position.x-8,start.y)
  var path:=PackedVector2Array([start,bend,target])
  draw_polyline(path,Color(.005,.01,.02,.65),3.,true)
  draw_polyline(path,Color(accent,.85),1.5,true)
  if kind=="keyboard" and row.binding.text.length()==1:
   var fs:=int(ceil(18./render_scale));var glyph_size:=font.get_string_size(row.binding.text,HORIZONTAL_ALIGNMENT_LEFT,-1,fs)
   draw_string_outline(font,target+Vector2(-glyph_size.x*.5,glyph_size.y*.25),row.binding.text,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,3,Color(.01,.02,.03))
   draw_string(font,target+Vector2(-glyph_size.x*.5,glyph_size.y*.25),row.binding.text,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,accent)
  else:draw_circle(target,3.5,accent,true,-1,true)
  draw_circle(target,6.,Color(accent,.14),true,-1,true)