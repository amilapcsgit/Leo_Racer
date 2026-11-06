extends Control
var panel: Control
func _draw() -> void:
 if is_instance_valid(panel):panel.draw_connections(self)
