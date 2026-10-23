class_name LeoActionButton
extends Button
@export var primary := false
@export var glyph_name := ""
@export var contained := false
@export var sound_key := "select"
var visual: Control
var label: Label
var fx: LeoButtonFX
var hovered := false
var active := false
var reduced_motion := false
var previous_disabled := false
func _ready() -> void:
 add_to_group("ui_buttons");custom_minimum_size.y=88 if primary else 64;mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
 for state in ["normal","hover","pressed","focus","disabled"]:add_theme_stylebox_override(state,StyleBoxEmpty.new())
 for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_disabled_color"]:add_theme_color_override(state,Color.TRANSPARENT)
 fx=LeoButtonFX.new();add_child(fx);fx.build(self);visual=fx.visual;label=fx.label
 focus_entered.connect(enter);focus_exited.connect(leave);mouse_entered.connect(func():hovered=true;enter());mouse_exited.connect(func():hovered=false;leave())
 button_down.connect(func():fx.animate(.98,.07));button_up.connect(func():fx.animate(1.05 if active else 1.,.15))
 # Feedback must precede callbacks which can replace this screen.
 var callbacks:=pressed.get_connections()
 for connection in callbacks:pressed.disconnect(connection.callable)
 pressed.connect(activate_feedback)
 for connection in callbacks:pressed.connect(connection.callable,connection.flags)
 visibility_changed.connect(func():
  if not is_visible_in_tree():hovered=false;active=false;fx.set_active(false)
  set_process(is_visible_in_tree()))
 refresh()
func refresh() -> void:
 if not fx:return
 previous_disabled=disabled;fx.refresh();update_active()
func update_active() -> void:
 var next:=(has_focus() or hovered) and not disabled
 if next==active:return
 active=next;fx.set_active(active)
 if active:cue("move")
func enter() -> void:update_active()
func leave() -> void:update_active()
func activate_feedback() -> void:
 if disabled:return
 cue(sound_key);stars(18)
func cue(kind: String) -> void:
 var audio:=get_tree().get_first_node_in_group("ui_audio")
 if audio:audio.cue(kind)
func stars(amount: int=6) -> void:
 if reduced_motion:return
 var effects:=get_tree().get_first_node_in_group("ui_effects")
 if effects:effects.burst(self,amount)
func set_reduced_motion(value: bool) -> void:
 reduced_motion=value
 if fx:fx.fx_set_reduced(value)
func _process(_dt: float) -> void:
 if fx and (label.text!=text or disabled!=previous_disabled):refresh()
