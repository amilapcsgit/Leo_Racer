class_name GrassInteractor
extends Marker3D

@export_range(0.2, 4.0) var radius: float = 0.65
@export_range(0.0, 1.0) var strength: float = 0.9

func _enter_tree() -> void:
	add_to_group(&"grass_interactors")
