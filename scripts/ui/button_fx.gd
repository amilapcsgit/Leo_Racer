class_name LeoButtonFX
extends Control
var owner_button: Button
var visual: Control
var surface: PanelContainer
var label: Label
var halo: ColorRect
var glint: ColorRect
var motion: Tween
var glow_motion: Tween
var reduced_motion := false
var active := false
var elapsed := 0.
func build(button: Button) -> void:
 owner_button=button;name="ButtonFX";mouse_filter=MOUSE_FILTER_IGNORE;set_anchors_and_offsets_preset(PRESET_FULL_RECT)
 visual=Control.new();visual.name="VisualRoot";visual.mouse_filter=MOUSE_FILTER_IGNORE;visual.set_anchors_and_offsets_preset(PRESET_FULL_RECT);add_child(visual)
 button.resized.connect(layout_visual)
 layout_visual()
 halo=ColorRect.new();halo.name="NeonHalo";halo.mouse_filter=MOUSE_FILTER_IGNORE;halo.set_anchors_and_offsets_preset(PRESET_FULL_RECT);halo.offset_left=-16;halo.offset_top=-16;halo.offset_right=16;halo.offset_bottom=16
 var h:=ShaderMaterial.new();h.shader=preload("res://shaders/ui_neon_halo.gdshader");halo.material=h;visual.add_child(halo)
 surface=PanelContainer.new();surface.name="Surface";surface.mouse_filter=MOUSE_FILTER_IGNORE;surface.set_anchors_and_offsets_preset(PRESET_FULL_RECT);visual.add_child(surface)
 glint=ColorRect.new();glint.name="Glint";glint.mouse_filter=MOUSE_FILTER_IGNORE;glint.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
 var g:=ShaderMaterial.new();g.shader=preload("res://shaders/ui_glint.gdshader");g.set_shader_parameter("phase",randf()*3.);glint.material=g;visual.add_child(glint)
 var content:=HBoxContainer.new();content.name="Content";content.mouse_filter=MOUSE_FILTER_IGNORE;content.alignment=BoxContainer.ALIGNMENT_CENTER;content.set_anchors_and_offsets_preset(PRESET_FULL_RECT);visual.add_child(content)
 if not button.glyph_name.is_empty():
  var glyph:=TextureRect.new();glyph.texture=load("res://assets/ui/icons/"+button.glyph_name+".svg");glyph.custom_minimum_size=Vector2(32,32);glyph.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;glyph.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;glyph.mouse_filter=MOUSE_FILTER_IGNORE;content.add_child(glyph)
 label=Label.new();label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;label.mouse_filter=MOUSE_FILTER_IGNORE;label.add_theme_font_size_override("font_size",28 if button.primary else 24);content.add_child(label)
 var origin:=Marker2D.new();origin.name="BurstOrigin";visual.add_child(origin)
 visual.resized.connect(func():visual.pivot_offset=visual.size*.5;origin.position=visual.size*.5;update_materials())
 reduced_motion=button.reduced_motion;add_to_group("ui_fx_tick");refresh()
func layout_visual() -> void:
 if owner_button.contained:
  var inset:=owner_button.size.x*.025+18.
  visual.offset_left=inset;visual.offset_right=-inset;visual.offset_top=8;visual.offset_bottom=-8
func update_materials() -> void:
 if not halo:return
 var radius:=10. if owner_button.primary else 8.
 halo.material.set_shader_parameter("rect_size",visual.size+Vector2(32,32));halo.material.set_shader_parameter("radius",radius)
 glint.material.set_shader_parameter("rect_size",visual.size);glint.material.set_shader_parameter("radius",radius)
func refresh() -> void:
 label.text=owner_button.text
 var box:=StyleBoxFlat.new();box.bg_color=Color("ffc857") if owner_button.primary else Color("101722ee");box.border_color=Color("43e7ef") if active else Color("526372");box.set_border_width_all(3 if active else 1);box.set_corner_radius_all(10 if owner_button.primary else 8);box.set_content_margin_all(12);box.shadow_color=Color(0,0,0,.4);box.shadow_size=5;surface.add_theme_stylebox_override("panel",box)
 label.modulate=Color("101722") if owner_button.primary else Color("f5f7fa");visual.modulate.a=.4 if owner_button.disabled else 1.
 halo.visible=not owner_button.disabled;halo.material.set_shader_parameter("tint",Color("ffc857") if owner_button.primary else Color("43e7ef"));halo.modulate.a=.35 if active else .08
 update_materials();glint.material.set_shader_parameter("enabled",active and not reduced_motion and not owner_button.disabled)
func set_active(value: bool) -> void:
 if active==value:return
 active=value;refresh();animate(1.05 if value else 1.,.15)
 if glow_motion:glow_motion.kill()
 if owner_button.primary:
  if value and not reduced_motion:
   glow_motion=create_tween();glow_motion.tween_method(func(value: float):halo.material.set_shader_parameter("glow_strength",value),1.,2.,.15);glow_motion.tween_method(func(value: float):halo.material.set_shader_parameter("glow_strength",value),2.,1.35,.25)
  else:halo.material.set_shader_parameter("glow_strength",1.)
func animate(value: float,duration: float) -> void:
 if motion:motion.kill()
 visual.pivot_offset=visual.size*.5
 if reduced_motion:visual.scale=Vector2.ONE;return
 motion=create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT);motion.tween_property(visual,"scale",Vector2.ONE*value,duration)
func fx_set_reduced(value: bool) -> void:
 reduced_motion=value
 if value:
  if motion:motion.kill()
  if glow_motion:glow_motion.kill()
  visual.scale=Vector2.ONE;halo.material.set_shader_parameter("glow_strength",1.)
 refresh()
func fx_tick(dt: float,reduced: bool) -> void:
 if reduced_motion!=reduced:fx_set_reduced(reduced)
 if reduced or owner_button.disabled:return
 elapsed+=dt;glint.material.set_shader_parameter("effect_time",elapsed)
func _exit_tree() -> void:
 if motion:motion.kill()
 if glow_motion:glow_motion.kill()
