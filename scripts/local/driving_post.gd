extends CanvasLayer
var game: Node3D
var slot := 0
var blur: ColorRect
func _ready() -> void:
	layer=0
	blur=ColorRect.new();blur.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);blur.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var material:=ShaderMaterial.new();material.shader=preload("res://shaders/driving_motion_blur.gdshader");blur.material=material;add_child(blur)
func _process(_dt: float) -> void:
	if not is_instance_valid(game.local_players[slot].kart):blur.hide();return
	var kart: LeoKart=game.local_players[slot].kart
	var enabled: bool=game.graphics.motion_blur and not game.reduced_motion and is_instance_valid(kart) and game.state in ["race","countdown"] and not game.paused
	if get_viewport()==get_tree().root and game.human_count==2:enabled=false
	blur.visible=enabled
	if enabled:(blur.material as ShaderMaterial).set_shader_parameter("strength",smoothstep(12.,65.,absf(kart.wheel_motion_speed))*.008)
