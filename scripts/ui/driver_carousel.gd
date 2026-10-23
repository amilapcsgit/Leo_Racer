class_name LeoDriverCarousel
extends Control
signal driver_selected(driver_id: StringName)
var catalog: GarageCatalog
var selected := 0
var reduced_motion := false
var cards: Array[Button]=[]
var materials: Array[ShaderMaterial]=[]
var moves: Dictionary={}
var driver_name: Label
var left: LeoActionButton
var right: LeoActionButton
func _ready() -> void:
 name="DriverCarousel";focus_mode=FOCUS_ALL;mouse_filter=MOUSE_FILTER_PASS;custom_minimum_size=Vector2(432,224);add_to_group("ui_fx_tick")
 for i in catalog.drivers.size():
  var index: int=i
  var card:=Button.new();card.name="Driver"+str(i);card.focus_mode=FOCUS_NONE;card.mouse_default_cursor_shape=CURSOR_POINTING_HAND;card.tooltip_text=catalog.drivers[i].display_name
  for state in ["normal","hover","pressed","focus"]:card.add_theme_stylebox_override(state,StyleBoxEmpty.new())
  add_child(card);cards.append(card)
  var face:=TextureRect.new();face.name="PortraitFrame";face.texture=preload("res://assets/ui/icons/hex_frame.svg");face.mouse_filter=MOUSE_FILTER_IGNORE;face.set_anchors_and_offsets_preset(PRESET_FULL_RECT);face.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;card.add_child(face)
  var material:=ShaderMaterial.new();material.shader=preload("res://shaders/ui_portrait_perspective.gdshader");face.material=material;materials.append(material)
  var portrait:=TextureRect.new();portrait.texture=catalog.drivers[i].portrait;portrait.mouse_filter=MOUSE_FILTER_IGNORE;portrait.set_anchors_and_offsets_preset(PRESET_FULL_RECT);portrait.offset_left=10;portrait.offset_right=-10;portrait.offset_top=12;portrait.offset_bottom=-14;portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;portrait.use_parent_material=true;face.add_child(portrait)
  card.pressed.connect(func():
   if index==selected:return
   var effects:=get_tree().get_first_node_in_group("ui_effects")
   if effects:effects.burst(card)
   step(-1 if index==posmod(selected-1,cards.size()) else 1))
 left=arrow("‹",Vector2(0,60),-1);right=arrow("›",Vector2(384,60),1)
 driver_name=Label.new();driver_name.position=Vector2(0,182);driver_name.size=Vector2(432,36);driver_name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;driver_name.add_theme_font_size_override("font_size",26);driver_name.mouse_filter=MOUSE_FILTER_IGNORE;add_child(driver_name)
 focus_entered.connect(queue_redraw);focus_exited.connect(queue_redraw);layout_cards(false)
func arrow(words: String,pos: Vector2,direction: int) -> LeoActionButton:
 var button: LeoActionButton=preload("res://scenes/ui/ActionButton.tscn").instantiate();button.text=words;button.sound_key="";button.reduced_motion=reduced_motion;button.position=pos;button.custom_minimum_size=Vector2(48,64);button.size=Vector2(48,64);add_child(button);button.pressed.connect(func():step(direction));return button
func select_id(id: StringName) -> void:
 var index:=catalog.driver_index(id)
 if selected==index and driver_name and not driver_name.text.is_empty():return
 var animate:=driver_name!=null and not driver_name.text.is_empty();selected=index
 if is_node_ready():layout_cards(animate)
func step(direction: int) -> void:
 selected=posmod(selected+direction,catalog.drivers.size());layout_cards(true);grab_focus()
 var audio:=get_tree().get_first_node_in_group("ui_audio")
 if audio:audio.cue("carousel")
 driver_selected.emit(catalog.drivers[selected].id)
func layout_cards(animate: bool) -> void:
 for i in cards.size():
  var card:=cards[i]
  if moves.has(i):moves[i].kill()
  var offset:=posmod(i-selected+cards.size()/2,cards.size())-cards.size()/2
  var visible_slot:=absi(offset)<=1;var entering:=not card.visible;card.visible=visible_slot
  if not visible_slot:continue
  var center:=offset==0;var target_pos:=Vector2(144,4) if center else Vector2(52 if offset<0 else 308,42)
  var target_size:=Vector2(144,160) if center else Vector2(72,104)
  var yaw:=0. if center else deg_to_rad(-25. if offset<0 else 25.)
  var color:=Color.WHITE if center else Color(.62,.72,.8,.8)
  card.z_index=2 if center else 1
  var face:=card.get_node("PortraitFrame") as TextureRect;face.texture=preload("res://assets/ui/icons/hex_selected.svg") if center else preload("res://assets/ui/icons/hex_frame.svg")
  if animate and not reduced_motion:
   if entering:card.position=target_pos+Vector2(offset*40.,0);card.size=target_size;card.modulate.a=0.
   var tween:=create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT);moves[i]=tween
   tween.tween_property(card,"position",target_pos,.22);tween.tween_property(card,"size",target_size,.22);tween.tween_property(card,"modulate",color,.22);tween.tween_method(func(value: float):materials[i].set_shader_parameter("yaw",value),float(materials[i].get_shader_parameter("yaw") if materials[i].get_shader_parameter("yaw")!=null else 0.),yaw,.22)
  else:card.position=target_pos;card.size=target_size;card.modulate=color;materials[i].set_shader_parameter("yaw",yaw)
 driver_name.text=catalog.drivers[selected].display_name;queue_redraw()
func _gui_input(event: InputEvent) -> void:
 if event.is_action_pressed("ui_left"):step(-1);accept_event()
 elif event.is_action_pressed("ui_right"):step(1);accept_event()
func _draw() -> void:
 draw_line(Vector2(196,174),Vector2(236,174),Color("ffc857"),3.,true)
 if has_focus():draw_style_box(focus_box(),Rect2(134,0,164,174))
func focus_box() -> StyleBoxFlat:
 var box:=StyleBoxFlat.new();box.bg_color=Color.TRANSPARENT;box.border_color=Color("43e7ef");box.set_border_width_all(2);box.set_corner_radius_all(14);box.shadow_color=Color(.26,.9,.94,.55);box.shadow_size=12;return box
func fx_set_reduced(value: bool) -> void:
 reduced_motion=value
 if value:layout_cards(false)
func fx_tick(_dt: float,reduced: bool) -> void:
 if reduced_motion!=reduced:fx_set_reduced(reduced)
func _exit_tree() -> void:
 for tween in moves.values():tween.kill()
