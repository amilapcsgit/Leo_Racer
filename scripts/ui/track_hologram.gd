class_name LeoTrackHologram
extends TextureRect
var elapsed:=0.
var reduced_motion:=false
var echo: TextureRect
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
