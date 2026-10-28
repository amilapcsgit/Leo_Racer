class_name LeoBackdropFX
extends Control
var art: TextureRect
var ambient: ColorRect
var particles: CPUParticles2D
var elapsed:=0.
var pointer:=Vector2.ZERO
var reduced_motion:=false
func _ready() -> void:
 name="BackdropFX";set_anchors_and_offsets_preset(PRESET_FULL_RECT);mouse_filter=MOUSE_FILTER_IGNORE;add_to_group("ui_fx_tick")
 ambient=ColorRect.new();ambient.set_anchors_and_offsets_preset(PRESET_FULL_RECT);ambient.mouse_filter=MOUSE_FILTER_IGNORE
 var shader:=ShaderMaterial.new();shader.shader=preload("res://shaders/ui_atmosphere.gdshader");ambient.material=shader;add_child(ambient)
 particles=CPUParticles2D.new();particles.amount=8 if RenderingServer.get_current_rendering_method()=="gl_compatibility" else 16;particles.lifetime=5.;particles.preprocess=2.;particles.position=Vector2(1000,500);particles.emission_shape=CPUParticles2D.EMISSION_SHAPE_RECTANGLE;particles.emission_rect_extents=Vector2(600,360);particles.direction=Vector2(0,-1);particles.spread=20.;particles.gravity=Vector2.ZERO;particles.initial_velocity_min=8.;particles.initial_velocity_max=18.;particles.texture=preload("res://assets/ui/icons/star.svg");particles.scale_amount_min=.10;particles.scale_amount_max=.22
 var gradient:=Gradient.new();gradient.set_color(0,Color(.26,.9,.94,0.));gradient.add_point(.3,Color(.26,.9,.94,.45));gradient.set_color(gradient.get_point_count()-1,Color(.26,.9,.94,0.));particles.color_ramp=gradient;add_child(particles)
 var blend:=CanvasItemMaterial.new();blend.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD;particles.material=blend
 visibility_changed.connect(func():particles.process_mode=Node.PROCESS_MODE_INHERIT if is_visible_in_tree() else Node.PROCESS_MODE_DISABLED)
 fx_set_reduced(reduced_motion);apply_parallax(Vector2.ZERO)
func apply_parallax(value: Vector2) -> void:
 var extent:=get_viewport_rect().size/maxf(.001,get_global_transform().get_scale().x)
 var extra:=(extent-size)*.5
 art.offset_left=-24-maxf(0.,extra.x)+value.x*20.;art.offset_right=24+maxf(0.,extra.x)+value.x*20.;art.offset_top=-24-maxf(0.,extra.y)+value.y*24.;art.offset_bottom=24+maxf(0.,extra.y)+value.y*24.
 ambient.offset_left=-24-maxf(0.,extra.x)+value.x*32.;ambient.offset_right=24+maxf(0.,extra.x)+value.x*32.;ambient.offset_top=-24-maxf(0.,extra.y)+value.y*24.;ambient.offset_bottom=24+maxf(0.,extra.y)+value.y*24.
func fx_tick(dt: float,reduced: bool) -> void:
 if reduced_motion!=reduced:fx_set_reduced(reduced)
 if reduced:apply_parallax(Vector2.ZERO);return
 elapsed+=dt;ambient.material.set_shader_parameter("effect_time",elapsed)
 var mouse:=get_local_mouse_position();var target:=Vector2(clampf(mouse.x/maxf(1.,size.x)*2.-1.,-1.,1.),clampf(mouse.y/maxf(1.,size.y)*2.-1.,-1.,1.))
 pointer=pointer.lerp(target,1.-exp(-dt*5.));apply_parallax(pointer)
func fx_set_reduced(value: bool) -> void:
 reduced_motion=value
 if particles:particles.visible=not value;particles.emitting=not value;particles.process_mode=Node.PROCESS_MODE_DISABLED if value else Node.PROCESS_MODE_INHERIT
 if value:pointer=Vector2.ZERO;apply_parallax(pointer);ambient.material.set_shader_parameter("effect_time",0.)
