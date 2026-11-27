extends SceneTree
func _initialize() -> void:
 root.add_child(load("res://scripts/content/release26_ui_check.gd").new())
