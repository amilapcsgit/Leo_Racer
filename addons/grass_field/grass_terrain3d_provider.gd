class_name GrassTerrain3DProvider
extends "grass_provider.gd"

@export var terrain: Node3D
@export var grass_texture_ids: PackedInt32Array = [0]
@export var allow_auto_shader: bool = false
@export_range(0.0, 1.0) var minimum_up: float = 0.83

var data: Object

func _ready() -> void:
	if is_instance_valid(terrain) and terrain.is_class("Terrain3D"):
		data = terrain.get("data")
		if is_instance_valid(data) and data.has_signal("maps_changed"):
			data.connect("maps_changed", _maps_changed)

func _maps_changed() -> void:
	changed.emit()

func bind_material(material: ShaderMaterial) -> bool:
	if not is_instance_valid(data) or not data.has_method("get_height_maps_rid"):
		return false
	var heights: RID = data.call("get_height_maps_rid")
	var controls: RID = data.call("get_control_maps_rid")
	var lookup: PackedInt32Array = data.call("get_region_map")
	if not heights.is_valid() or not controls.is_valid() or lookup.size() != 1024:
		return false
	var eligible := 0
	for id in grass_texture_ids:
		if id >= 0 and id < 32:
			eligible |= 1 << id
	material.set_shader_parameter("terrain_mode", 1)
	material.set_shader_parameter("region_map", lookup)
	material.set_shader_parameter("region_size", int(terrain.get("region_size")))
	material.set_shader_parameter("spacing", float(terrain.get("vertex_spacing")))
	material.set_shader_parameter("eligible_textures", eligible)
	material.set_shader_parameter("allow_auto", allow_auto_shader)
	material.set_shader_parameter("minimum_up", minimum_up)
	RenderingServer.material_set_param(material.get_rid(), &"height_maps", heights)
	RenderingServer.material_set_param(material.get_rid(), &"control_maps", controls)
	return true

func height_range() -> Vector2:
	if not is_instance_valid(data):
		return Vector2.ZERO
	var bounds: Vector2 = data.call("get_height_range")
	return Vector2(minf(bounds.x, bounds.y), maxf(bounds.x, bounds.y))
