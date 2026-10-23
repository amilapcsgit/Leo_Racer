class_name LeoStatBar
extends Control
var ratio := 0.:
 set(value):ratio=value;queue_redraw()
var flash := 0.:
 set(value):flash=value;queue_redraw()
var target := 0.
var reduced_motion := false
var motion: Tween
func _ready() -> void:
 custom_minimum_size=Vector2(200,18);mouse_filter=MOUSE_FILTER_IGNORE;add_to_group("ui_fx_tick")
func set_value(value: float) -> void:
 var next:=clampf(value,0.,1.)
 if is_equal_approx(target,next):return
 target=next
 if motion:motion.kill()
 if reduced_motion:ratio=target;flash=0.;return
 flash=.65;motion=create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
 motion.tween_property(self,"ratio",target,.5);motion.tween_property(self,"flash",0.,.5)
func fx_set_reduced(value: bool) -> void:
 reduced_motion=value
 if value:
  if motion:motion.kill()
  ratio=target;flash=0.
func fx_tick(_dt: float,reduced: bool) -> void:
 if reduced_motion!=reduced:fx_set_reduced(reduced)
func _draw() -> void:
 for i in 10:
  var w:=(size.x-27)/10.
  draw_rect(Rect2(i*(w+3),0,w,size.y),Color("43e7ef").lerp(Color.WHITE,flash) if ratio>=(i+.5)/10. else Color("33414c"))
