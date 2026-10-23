class_name LeoUIEffects
extends Node
var reduced_motion := false
var layer: Control
var emitters: Array[CPUParticles2D] = []
var cursor := 0
var burst_count := 0
func _ready() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS;add_to_group("ui_effects")
 layer=Control.new();layer.name="FeedbackLayer";layer.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.z_index=100;get_parent().add_child.call_deferred(layer)
 for i in 4:
  var emitter:=CPUParticles2D.new();emitter.emitting=false;emitter.one_shot=true;emitter.amount=18;emitter.lifetime=.4;emitter.explosiveness=1.;emitter.spread=180.;emitter.gravity=Vector2.ZERO;emitter.initial_velocity_min=90.;emitter.initial_velocity_max=210.;emitter.scale_amount_min=.25;emitter.scale_amount_max=.5;emitter.texture=preload("res://assets/ui/icons/star.svg");emitter.local_coords=false
  var gradient:=Gradient.new();gradient.set_color(0,Color("ffc857"));gradient.add_point(.5,Color("43e7ef"));gradient.set_color(gradient.get_point_count()-1,Color(0.263,.906,.937,0.));emitter.color_ramp=gradient
  var blend:=CanvasItemMaterial.new();blend.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD;emitter.material=blend
  layer.add_child(emitter);emitters.append(emitter)
func burst(source: Control,amount: int=18) -> void:
 if reduced_motion or not is_instance_valid(layer) or not layer.is_inside_tree():return
 var emitter:=emitters[cursor];cursor=(cursor+1)%emitters.size()
 emitter.position=layer.get_global_transform().affine_inverse()*source.get_global_rect().get_center();emitter.amount=amount;emitter.visible=true;emitter.restart();emitter.emitting=true;burst_count+=1
func set_reduced_motion(value: bool) -> void:
 reduced_motion=value
 for emitter in emitters:emitter.visible=not value;emitter.emitting=false
 get_tree().call_group("ui_fx_tick","fx_set_reduced",value)
func _process(dt: float) -> void:
 for effect in get_tree().get_nodes_in_group("ui_fx_tick"):
  if effect is CanvasItem and effect.is_visible_in_tree():effect.fx_tick(dt,reduced_motion)
