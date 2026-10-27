extends RefCounted
## Exact authored material roles, never inferred from colors or node substrings.
const PAINT=preload("res://assets/materials/automotive_paint.tres")
const GLASS=preload("res://assets/materials/automotive_glass.tres")
static var manifest: Dictionary={}
static func install(body: Node3D, key: String) -> void:
	if manifest.is_empty():manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/config/vehicle-material-repairs-v1.json"))
	var entry: Dictionary=manifest.get(key,{})
	for target in entry.get("targets",[]):
		var node:=body.get_node_or_null(NodePath(target.node)) as MeshInstance3D
		if not node or not node.mesh or int(target.surface)>=node.mesh.get_surface_count():continue
		var old:=node.get_active_material(int(target.surface)) as StandardMaterial3D
		if not old or old.resource_name!=String(target.material):continue
		var template: StandardMaterial3D=PAINT if target.role=="paint" else GLASS
		var material:=old.duplicate() as StandardMaterial3D
		for property in ["shading_mode","transparency","metallic","metallic_specular","roughness","clearcoat_enabled","clearcoat","clearcoat_roughness","cull_mode"]:material.set(property,template.get(property))
		material.albedo_color.a=1. if target.role=="paint" else clampf(old.albedo_color.a,.18,.65)
		node.set_surface_override_material(int(target.surface),material)
