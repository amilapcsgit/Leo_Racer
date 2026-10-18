extends SceneTree

var errors: Array[String] = []
var count := 0
func verify(ok: bool, message: String) -> void:
	count += 1
	if not ok: errors.append(message)
	print(("PASS " if ok else "FAIL ")+message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	verify(ProjectSettings.get_setting("physics/common/physics_interpolation"),"Physics interpolation is enabled")
	verify(game.camera.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_OFF,"Chase camera uses explicit rendered pose without double interpolation")
	var labels := get_nodes_in_group("race_sign_text")
	verify(labels.size() == 8,"Start arch has front/back faces and six mounted track boards")
	for node in labels:
		var l := node as Label3D
		verify(not l.double_sided and not l.no_depth_test and not l.fixed_size,"Text face %s is opaque-facing, depth-tested and physically sized" % l.text)
	var front := labels[0] as Label3D
	var back := labels[1] as Label3D
	verify(front.global_basis.z.dot(Vector3.BACK) > .99 and front.position.z > 72.6,"Start-front label sits outside south beam face and faces approach")
	verify(back.global_basis.z.dot(Vector3.FORWARD) > .99 and back.position.z < 71.4,"Start-back label has its own readable north face")
	var pads := get_nodes_in_group("race_boost_pad")
	verify(pads.size() == 4,"All four boost pads are present")
	for pad in pads:
		var tangent: Vector3 = pad.get_meta("race_direction")
		verify((-pad.global_basis.z).dot(tangent) > .999,"Boost pad %s local forward follows race direction" % pad.name)
	var mesh := LeoRaceVisuals.chevron_mesh()
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var center_leading := 0.0
	var outer_leading := 0.0
	for vertex in vertices:
		if absf(vertex.x) < .01: center_leading = minf(center_leading,vertex.z)
		else: outer_leading = maxf(outer_leading,vertex.z)
	verify(center_leading < -.5 and outer_leading > .5,"Chevron tips point ahead at negative Z, with outer wings trailing")
	var city: LeoCity
	for child in game.world.get_children():
		if child is LeoCity: city = child
	verify(city != null and city.stats.buildings >= 40 and city.stats.skyline >= 15,"Detailed city kit replaces sparse block scenery")
	verify(city.stats.minimum_road_clearance >= 12,"Building footprints stay outside the race barriers")
	verify(city.stats.shop_signs >= 30,"Physical storefront signage is installed")
	game.stop_all_audio()
	var report := {"status":"PASS" if errors.is_empty() else "FAIL","checks":count,"errors":errors}
	FileAccess.open("res://docs/qa-v2/visual-regression.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("VISUAL_REGRESSION ",JSON.stringify(report))
	await process_frame
	await process_frame
	quit(0 if errors.is_empty() else 1)
