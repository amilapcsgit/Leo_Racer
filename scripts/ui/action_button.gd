class_name LeoActionButton
extends Button
@export var primary := false
@export var glyph_name := ""
@export var contained := false
var visual: PanelContainer
var label: Label
var motion: Tween
var hovered := false
var reduced_motion := false
var color_motion: Tween
func _ready() -> void:
 add_to_group("ui_buttons")
 custom_minimum_size.y=88 if primary else 64
 mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
 for state in ["normal","hover","pressed","focus","disabled"]:add_theme_stylebox_override(state,StyleBoxEmpty.new())
 for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_disabled_color"]:add_theme_color_override(state,Color.TRANSPARENT)
 visual=PanelContainer.new();visual.mouse_filter=MOUSE_FILTER_IGNORE;visual.set_anchors_and_offsets_preset(PRESET_FULL_RECT);add_child(visual)
 if contained:visual.offset_left=16;visual.offset_right=-16;visual.offset_top=4;visual.offset_bottom=-4
 var line:=HBoxContainer.new();line.alignment=BoxContainer.ALIGNMENT_CENTER;line.mouse_filter=MOUSE_FILTER_IGNORE;visual.add_child(line)
 if not glyph_name.is_empty():
  var glyph:=TextureRect.new();glyph.texture=load("res://assets/ui/icons/"+glyph_name+".svg");glyph.custom_minimum_size=Vector2(32,32);glyph.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;glyph.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;glyph.mouse_filter=MOUSE_FILTER_IGNORE;line.add_child(glyph)
 label=Label.new();label.text=text;label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;label.mouse_filter=MOUSE_FILTER_IGNORE;label.add_theme_font_size_override("font_size",28 if primary else 24);line.add_child(label)
 focus_entered.connect(enter);focus_exited.connect(leave);mouse_entered.connect(func():hovered=true;enter());mouse_exited.connect(func():hovered=false;leave())
 button_down.connect(func():animate(.98,.07));button_up.connect(func():animate(1.035 if has_focus() or hovered else 1.,.12))
 pressed.connect(func():cue("select"))
 resized.connect(func():visual.pivot_offset=size*.5)
 refresh()
func refresh() -> void:
 if not visual:return
 label.text=text
 var selected:=has_focus() or hovered
 var box:=StyleBoxFlat.new();box.bg_color=Color("ffc857") if primary else Color("101722ee")
 box.border_color=Color("43e7ef") if selected else Color("526372");box.set_border_width_all(3 if selected else 1);box.set_corner_radius_all(44 if primary else 12)
 box.set_content_margin_all(12);box.shadow_color=Color(0.26,.9,.94,.22) if selected else Color(0,0,0,.4);box.shadow_size=12 if selected else 4
 visual.add_theme_stylebox_override("panel",box)
 label.modulate=Color("101722") if primary else Color("f5f7fa")
 visual.modulate.a=.4 if disabled else 1.
func enter() -> void:
 if disabled:return
 refresh();animate(1.035,.12);cue("move")
 if color_motion:color_motion.kill()
 if not primary:
  label.modulate=Color("ffc857");color_motion=create_tween();color_motion.tween_property(label,"modulate",Color("f5f7fa"),.24)
 if primary and not reduced_motion:stars()
func leave() -> void:
 refresh();animate(1.035 if has_focus() or hovered else 1.,.12)
func animate(value: float,duration: float) -> void:
 if not visual:return
 if motion:motion.kill()
 visual.pivot_offset=size*.5
 motion=create_tween();motion.tween_property(visual,"scale",Vector2.ONE*(1. if reduced_motion else value),duration)
func cue(kind: String) -> void:
 var audio:=get_tree().get_first_node_in_group("ui_audio")
 if audio:audio.cue(kind)
func stars() -> void:
 if size.x<32:await get_tree().process_frame
 if not is_inside_tree() or reduced_motion:return
 if get_meta("spark_time",0)+350>Time.get_ticks_msec():return
 set_meta("spark_time",Time.get_ticks_msec())
 for i in 6:
  var spark:=TextureRect.new();spark.texture=load("res://assets/ui/icons/star.svg");spark.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;spark.size=Vector2(12,12);spark.position=Vector2(size.x-32,size.y*.5);spark.mouse_filter=MOUSE_FILTER_IGNORE;add_child(spark)
  var tween:=create_tween().set_parallel(true)
  tween.tween_property(spark,"position",spark.position+Vector2(cos(i*TAU/6),sin(i*TAU/6))*42,.3)
  tween.tween_property(spark,"modulate:a",0.,.3)
  tween.chain().tween_callback(spark.queue_free)

func set_reduced_motion(value: bool) -> void:
 reduced_motion=value
 if value and motion:motion.kill()
 if value and visual:visual.scale=Vector2.ONE

func _process(_dt: float) -> void:
 if label and (label.text!=text or not is_equal_approx(visual.modulate.a,.4 if disabled else 1.)):refresh()
