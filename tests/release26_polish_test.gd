extends SceneTree
func _initialize() -> void:
	root.add_child(load("res://scripts/content/release26_polish_check.gd").new())
