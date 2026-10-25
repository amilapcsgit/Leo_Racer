extends Node3D
## Opt-in finish for the checkpoint 024 portable Bigster. Materials are per vehicle;
## mesh resources stay shared, so one car braking never changes another car.
var brake_materials: Array[StandardMaterial3D] = []
var tail_lights: Array[OmniLight3D] = []
var headlights: Array[SpotLight3D] = []
var braking := false

static func install(body: Node3D, profile: String) -> Node3D:
	if profile != "bigster_pbr_v1": return null
	var controller := new()
	controller.name = "VehicleLighting"
	body.add_child(controller)
	controller.apply_finish(body, {})
	for side in [-1., 1.]:
		var lamp := SpotLight3D.new()
		lamp.name = "LowBeamLeft" if side < 0 else "LowBeamRight"
		lamp.position = Vector3(side * .64, .91, -2.09)
		lamp.rotation.x = deg_to_rad(-5.)
		lamp.light_color = Color(.88, .94, 1.)
		lamp.light_energy = 2.2
		lamp.spot_range = 26.
		lamp.spot_angle = 32.
		lamp.spot_attenuation = 1.25
		lamp.shadow_enabled = false
		lamp.distance_fade_enabled = true
		lamp.distance_fade_begin = 40.
		lamp.distance_fade_length = 15.
		controller.add_child(lamp)
		controller.headlights.append(lamp)
		var tail := OmniLight3D.new()
		tail.name = "TailGlowLeft" if side < 0 else "TailGlowRight"
		tail.position = Vector3(side * .77, 1.05, 2.19)
		tail.light_color = Color(1., .015, .008)
		tail.omni_range = 1.35
		tail.light_energy = .12
		tail.shadow_enabled = false
		controller.add_child(tail)
		controller.tail_lights.append(tail)
	controller.update_state(false)
	return controller

func apply_finish(node: Node, shared: Dictionary) -> void:
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
					m.emission_energy_multiplier = 3.
				elif label.begins_with("Lamp_TailBrake_"):
					m.emission_enabled = true
					m.emission = Color(1., .008, .012)
					brake_materials.append(m)
				shared[old] = m
			node.set_surface_override_material(i, shared[old])
		if node.name.contains("glass") or node.name.contains("Glass"):
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children(): apply_finish(child, shared)

func update_state(is_braking: bool) -> void:
	braking = is_braking
	for material in brake_materials:
		material.emission_energy_multiplier = 3.5 if braking else .45
	for lamp in tail_lights: lamp.light_energy = .8 if braking else .12
