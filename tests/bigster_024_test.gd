extends SceneTree
var errors: Array[String] = []
var checks := 0
var out := OS.get_environment("BIGSTER_QA_ROOT") if OS.has_environment("BIGSTER_QA_ROOT") else ProjectSettings.globalize_path("res://../../Bigster/leo_racer_024")
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: errors.append(label); push_error(label)
func bounds(node: Node3D) -> AABB:
	var box := AABB()
	var found := false
	for mesh in node.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = (node.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
		box = box.merge(b) if found else b
		found = true
	return box
func run() -> void:
	var asset_root := OS.get_environment("LEO_ASSET_ROOT") if OS.has_environment("LEO_ASSET_ROOT") else ProjectSettings.globalize_path("res://build/CustomCars-delivery/LeoRacer/GameAssets")
	check(LeoAssets.configure(asset_root) == OK, "Installed external assets resolve")
	check(LeoAssets.mount_packs() == OK, "Installed driver packs mount")
	LeoVehicleLibrary.discover(out.path_join("stage/vehicles"))
	var catalog := GarageCatalog.shared()
	var v := catalog.vehicle(&"bigster")
	check(v != null, "Bigster discovered")
	if not v: quit(1); return
	check(v.visual_profile == "bigster_pbr_v1", "Portable finish profile")
	check(await LeoAssets.scene_async(v.model_path, self) != null, "Runtime GLB importer")
	check(LeoVehicleLibrary.problems(v.content_data,v.content_folder).is_empty(), "Vehicle API validation")
	var raw := v.model.instantiate() as Node3D
	root.add_child(raw)
	var box := bounds(raw)
	check(absf(box.size.z - 4.569805) < .002, "Checkpoint length preserved")
	check(absf(box.position.y) < .001, "Tyres on ground")
	var meshes := raw.find_children("*", "MeshInstance3D", true, false)
	check(meshes.size() >= 250, "Physical meshes remain separate")
	var caps: Dictionary = {};var cap_count := 0
	for mesh in meshes:
		if mesh.name.begins_with("Bigster_Lower_Copper_Tab"):
			caps[mesh.mesh] = true; cap_count += 1
	check(cap_count == 52 and caps.size() == 1, "52 grille caps share one mesh")
	raw.free()
	var rows: Array = []
	for d in catalog.drivers:
		var kart := LeoKart.new();root.add_child(kart)
		kart.setup(LeoCircuit.new(),0,false,String(d.id),"bigster")
		kart.set_physics_process(false);kart.set_process(false)
		check(kart.driver != null and kart.driver.get_meta("visible_driver_id") == d.id, "Cabin driver " + String(d.id))
		check(kart.wheels.size() == 4, "Four wheels: " + String(d.id))
		for i in 4:
			check(kart.wheels[i].global_position.distance_to(kart.wheel_steering_pivots[i].global_position) < .0001, "Wheel pivot %s/%d" % [d.id,i])
			check(kart.wheels[i].get_parent() == kart.wheel_spin_pivots[i], "Wheel spin hierarchy")
			check(absf(v.wheels[i].radius - .4667) < .001, "Correct metre radius")
		kart.steer=.8;kart.wheel_motion_speed=12.;kart.animate_wheels(.1)
		check(absf(kart.wheel_angles[0]) > .1, "Wheel animation")
		var light: Node = kart.vehicle_lighting
		check(light != null and light.headlights.size() == 2 and light.brake_materials.size() >= 2, "Light setup")
		if not light: kart.stop_audio();kart.free();continue
		light.update_state(true)
		check(light.braking and light.brake_materials[0].emission_energy_multiplier > 3., "Brake lamp response")
		var other := VehicleAssembler.assemble(v,d)
		root.add_child(other)
		var second: Node = other.get_node("Chassis/VehicleLighting")
		check(second.brake_materials[0] != light.brake_materials[0] and second.brake_materials[0].emission_energy_multiplier < 1., "Independent brake materials")
		other.free();light.update_state(false)
		var paint := false;var glass := false
		for mesh in kart.chassis.find_children("*","MeshInstance3D",true,false):
			for i in mesh.mesh.get_surface_count():
				var material: Material = mesh.get_active_material(i)
				if material.resource_name.begins_with("CarPaint_"):paint = material.clearcoat_enabled and material.clearcoat > .9
				if material.resource_name.begins_with("Glass_Clear"):glass = material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA and material.albedo_color.a < .3
		check(paint and glass,"Paint and glass finish")
		rows.append({"driver":String(d.id),"fit":LeoVehicleCodec.encode(kart.driver.transform),"bounds":str(bounds(kart.driver))})
		kart.stop_audio();kart.free()
	var tracks: Array = []
	for track in LeoTrackDefinition.discover():
		check(track.mount(),"Installed track mounts: " + String(track.id))
		var circuit := LeoCircuit.new(track)
		check(circuit.length > 100., "Track circuit: " + String(track.id))
		tracks.append(String(track.id))
	var report := {"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors,"drivers":rows,"tracks":tracks,"mesh_objects":meshes.size(),"linked_grille_caps":cap_count,"bounds":str(box)}
	FileAccess.open(out.path_join("runtime_validation.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("BIGSTER_024_VALIDATION ",JSON.stringify(report))
	quit(0 if errors.is_empty() else 1)
