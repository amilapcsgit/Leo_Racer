class_name LeoTrackHologram
extends TextureRect
var elapsed:=0.
var reduced_motion:=false
var echo: TextureRect
static var route_textures: Dictionary={}
func set_route(course: LeoTrackDefinition) -> void:
 var key:=course.id+":"+str(course.revision)+":"+JSON.stringify(course.route.get("points",[])).sha256_text()
 if route_textures.has(key):texture=route_textures[key];return
 var points: PackedVector3Array=[]
 for point in course.route.get("points",[]):
  if point is Array and point.size()==3:
   var p:=LeoVehicleCodec.vector(point)
   if p.is_finite():points.append(p)
 if points.size()<2:return
 var transform:=LeoTelemetry.map_transform(points,Rect2(24,24,272,212))
 var coords:=PackedStringArray()
 for point in points:
  var p:=transform*Vector2(point.x,point.z)
  coords.append("%.2f,%.2f" % [p.x,p.y])
 coords.append(coords[0])
 var start:=transform*Vector2(points[0].x,points[0].z)
 var svg:='<svg xmlns="http://www.w3.org/2000/svg" width="320" height="260"><polyline points="%s" fill="none" stroke="#43e7ef" stroke-width="5" stroke-linejoin="round"/><circle cx="%.2f" cy="%.2f" r="7" fill="#ffc857"/></svg>' % [" ".join(coords),start.x,start.y]
 var image:=Image.new()
 if image.load_svg_from_string(svg)==OK:
  texture=ImageTexture.create_from_image(image);route_textures[key]=texture
func _ready() -> void:
 mouse_filter=MOUSE_FILTER_IGNORE;expand_mode=EXPAND_IGNORE_SIZE;stretch_mode=STRETCH_KEEP_ASPECT_CENTERED
 var shader:=ShaderMaterial.new();shader.shader=preload("res://shaders/ui_portrait_perspective.gdshader");material=shader
 echo=TextureRect.new();echo.texture=texture;echo.expand_mode=EXPAND_IGNORE_SIZE;echo.stretch_mode=STRETCH_KEEP_ASPECT_CENTERED;echo.set_anchors_and_offsets_preset(PRESET_FULL_RECT);echo.offset_left=3;echo.offset_top=4;echo.offset_right=3;echo.offset_bottom=4;echo.modulate=Color(.26,.9,.94,.25);echo.mouse_filter=MOUSE_FILTER_IGNORE;echo.use_parent_material=true;show_behind_parent=true;add_child(echo);echo.show_behind_parent=true
 add_to_group("ui_fx_tick")
func fx_tick(dt: float,reduced: bool) -> void:
 if reduced_motion!=reduced:fx_set_reduced(reduced)
 if reduced:return
 elapsed+=dt;material.set_shader_parameter("yaw",sin(elapsed*TAU/10.)*deg_to_rad(16.))
func fx_set_reduced(value: bool) -> void:
 reduced_motion=value
 if value:material.set_shader_parameter("yaw",0.)
