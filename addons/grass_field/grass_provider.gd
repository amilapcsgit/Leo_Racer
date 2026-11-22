class_name GrassProvider
extends Node

signal changed

func bind_material(_material: ShaderMaterial) -> bool:
	return false

func height_range() -> Vector2:
	return Vector2.ZERO

func covers_tile(_area: Rect2) -> bool:
	return true
