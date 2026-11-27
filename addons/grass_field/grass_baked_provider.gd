class_name GrassBakedProvider
extends "grass_provider.gd"

const Bake := preload("grass_bake.gd")

@export_file("*.res", "*.tres") var bake_path: String
var atlas: Bake

func _ready() -> void:
	if atlas == null and ResourceLoader.exists(bake_path):
		atlas = load(bake_path) as Bake

func bind_material(material: ShaderMaterial) -> bool:
	if atlas == null or atlas.samples == null or atlas.spacing <= 0.0:
		return false
	material.set_shader_parameter("terrain_mode", 0)
	material.set_shader_parameter("baked_samples", atlas.samples)
	material.set_shader_parameter("baked_origin", atlas.origin)
	material.set_shader_parameter("spacing", atlas.spacing)
	return true

func height_range() -> Vector2:
	return atlas.elevation if atlas else Vector2.ZERO

func covers_tile(area: Rect2) -> bool:
	return atlas != null and Rect2(atlas.origin, Vector2(atlas.samples.get_size()) * atlas.spacing).intersects(area)
