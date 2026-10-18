class_name LeoAstraDecals
extends RefCounted
## Raised alpha-painted meshes work in Forward+ and Compatibility alike.
static func build(parent: Node3D, circuit: LeoCircuit) -> void:
	var materials: Dictionary = {}
	var designs := [["leo_road_crest",.018,Vector2(6.2,6.2)], ["colombo_road_stencil",.13,Vector2(12,4.5)], ["lotus_road_emblem",.29,Vector2(6,6)], ["colombo_road_stencil",.46,Vector2(11,4.2)], ["lotus_road_emblem",.63,Vector2(6,6)], ["leo_road_crest",.80,Vector2(6.2,6.2)], ["colombo_road_stencil",.925,Vector2(11,4.2)]]
	for spec in designs:
		var key: String = spec[0]
		if not materials.has(key):
			var material := StandardMaterial3D.new()
			material.albedo_texture = load("res://assets/art/astra/%s.png"%key)
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
			material.roughness = .42
			material.metallic_specular = .35
			material.cull_mode = BaseMaterial3D.CULL_BACK
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			materials[key] = material
		var s := float(spec[1])*circuit.length
		var paint := MeshInstance3D.new()
		paint.name = "RoadPaint_"+key
		var plane := PlaneMesh.new()
		plane.size = spec[2]
		paint.mesh = plane
		paint.material_override = materials[key]
		paint.position = circuit.sample(s)+Vector3.UP*.065
		var direction := circuit.direction(s)
		paint.rotation.y = atan2(-direction.x,-direction.z)
		paint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		paint.visibility_range_end = 160
		paint.visibility_range_end_margin = 15
		paint.add_to_group("astra_road_decal")
		paint.set_meta("design",key)
		paint.set_meta("distance",s)
		parent.add_child(paint)
