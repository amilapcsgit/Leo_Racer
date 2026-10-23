class_name LeoStatBar
extends Control
var ratio := 0.
var target := 0.
var reduced_motion := false
var motion: Tween
func _ready() -> void:
 custom_minimum_size=Vector2(200,18);mouse_filter=MOUSE_FILTER_IGNORE
func set_value(value: float) -> void:
 if is_equal_approx(target,value):return
 target=clampf(value,0.,1.)
 if motion:motion.kill()
 motion=create_tween();motion.tween_property(self,"ratio",target,0.01 if reduced_motion else .25)
 motion.tween_method(func(_v):queue_redraw(),0.,1.,0.01 if reduced_motion else .25)
func _draw() -> void:
 for i in 10:
  var w:=(size.x-27)/10.
  draw_rect(Rect2(i*(w+3),0,w,size.y),Color("43e7ef") if ratio>=(i+.5)/10. else Color("33414c"))
