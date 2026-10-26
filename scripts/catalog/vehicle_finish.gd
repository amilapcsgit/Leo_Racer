extends RefCounted
## Preserve the checkpoint paint/glass finish independently of lamp controls.
static func install(body: Node3D, profile: String) -> void:
	if profile == "bigster_pbr_v1":apply_finish(body,{})

static func apply_finish(node: Node, shared: Dictionary) -> void:
	if node is MeshInstance3D:
		for i in node.mesh.get_surface_count():
			var old: Material = node.get_active_material(i)
			if not old is StandardMaterial3D: continue
			if not shared.has(old):
				var m := old.duplicate() as StandardMaterial3D
				var label := m.resource_name
				if label.begins_with("CarPaint_"):
					m.clearcoat_enabled = true
					m.clearcoat = 1.
					m.clearcoat_roughness = .14
					m.metallic = .55
					m.roughness = .27
				elif label.begins_with("Glass_"):
					# Fresnel reflections + alpha transmission work in both renderers.
					# Screen-space refraction loses other glass surfaces and is avoided.
					m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					m.cull_mode = BaseMaterial3D.CULL_BACK
					m.metallic = 0.
					m.metallic_specular = .5
				elif label.begins_with("Lamp_Head_"):
					m.emission_enabled = true
					m.emission = Color(.8, .88, 1.)
					m.emission_energy_multiplier = 0.
				elif label.begins_with("Lamp_TailBrake_"):
					m.emission_enabled = true
					m.emission = Color(1., .008, .012)
					m.emission_energy_multiplier = 0.
				shared[old] = m
			node.set_surface_override_material(i, shared[old])
		if node.name.contains("glass") or node.name.contains("Glass"):
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children(): apply_finish(child, shared)
