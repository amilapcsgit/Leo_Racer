extends SceneTree
## Dynamic registry coverage: every selectable driver on every selectable chassis.
## Run Godot --headless --path . --script tools/astra_vehicle_test.gd

var failures: Array[String] = []
var checks := 0
var combinations: Array[Dictionary] = []
var current := "registry"
var current_errors: Array[String] = []
var current_checks := 0

func _initialize() -> void:
	run.call_deferred()

func verify(ok: bool, message: String) -> void:
	checks += 1
	current_checks += 1
	if not ok:
		failures.append(current + ": " + message)
		current_errors.append(message)
		print("FAIL ", current, ": ", message)

func vec(value: Variant, fallback := Vector3.ZERO) -> Vector3:
	if value is Vector3: return value
	if value is Array and value.size() == 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	if value is float or value is int: return Vector3.ONE * float(value)
	return fallback

func spec_value(spec: Dictionary, key: String, fallback: Vector3) -> Vector3:
	return vec(spec.get(key, fallback), fallback)

func wheel_transform(kart: LeoKart, index: int) -> Transform3D:
	return kart.wheel_steering_pivots[index].transform * kart.wheel_spin_pivots[index].transform * kart.wheels[index].transform

func finite_transform(transform: Transform3D) -> bool:
	return transform.origin.is_finite() and transform.basis.x.is_finite() and transform.basis.y.is_finite() and transform.basis.z.is_finite()

func descendants(node: Node) -> int:
	var count := node.get_child_count()
	for child in node.get_children(): count += descendants(child)
	return count

func run() -> void:
	var main_script: Script = load("res://scripts/main.gd")
	var constants: Dictionary = main_script.get_script_constant_map()
	var roster: Array = constants.get("ROSTER", [])
	var vehicles: Array = constants.get("KARTS", [])
	verify(roster.size() == 5, "Five playable drivers are registered")
	verify(vehicles.size() == 9, "Nine playable chassis are registered")
	verify(roster.any(func(item): return item.get("name", "") == "Shaven Leo"), "Shaven Leo is selectable by name")
	var circuit := LeoCircuit.new()
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(0, 8, 9)
	camera.current = true
	for driver_data in roster:
		for vehicle_data in vehicles:
			await test_combination(circuit, driver_data, vehicle_data, camera)
	current = "registry"
	verify(combinations.size() == 45, "All 45 combinations were exercised through actual LeoKart.setup")
	var report := {"status": "PASS" if failures.is_empty() else "FAIL", "checks": checks,
		"driver_count": roster.size(), "vehicle_count": vehicles.size(),
		"combinations_exercised": combinations.size(), "errors": failures, "combinations": combinations,
		"coverage": ["actual imported wheel binds", "four independent wheel pivots", "seating transforms",
			"collider dimensions", "exhaust attachment positions", "measured displacement rolling",
			"stationary throttle rejection", "front-only steering", "long spin basis stability",
			"reverse wheel travel", "pooled impacts", "repeated recovery", "effect teardown"]}
	FileAccess.open("res://docs/qa-astra/vehicles.json", FileAccess.WRITE).store_string(JSON.stringify(report, "  ") + "\n")
	print("ASTRA_VEHICLE_REPORT ", JSON.stringify({"status": report.status, "checks": checks,
		"combinations": combinations.size(), "errors": failures}))
	camera.free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)

func test_combination(circuit: LeoCircuit, driver_data: Dictionary, vehicle_data: Dictionary, camera: Camera3D) -> void:
	var animal := str(driver_data.animal)
	var key := str(vehicle_data.color)
	current = str(driver_data.name) + " / " + str(vehicle_data.name)
	current_errors = []
	current_checks = 0
	var spec: Dictionary = LeoKart.vehicle_spec(key)
	var model_path := LeoKart.chassis_path(key)
	var driver_path := LeoKart.driver_path(animal)
	verify(ResourceLoader.exists(model_path), "Chassis GLB resolves")
	verify(ResourceLoader.exists(driver_path), "Driver GLB resolves")
	if not ResourceLoader.exists(model_path) or not ResourceLoader.exists(driver_path):
		combinations.append({"driver": animal, "vehicle": key, "checks": current_checks, "errors": current_errors.duplicate()})
		return
	var source := load(model_path).instantiate() as Node3D
	var authored: Array[Transform3D] = []
	for axle in ["front", "back"]:
		for side in ["left", "right"]:
			var wheel := source.find_child("wheel-%s-%s" % [axle, side], true, false) as Node3D
			verify(wheel != null, "Imported wheel exists: %s %s" % [axle, side])
			if wheel: authored.append(wheel.transform)
	source.free()
	var kart := LeoKart.new()
	root.add_child(kart)
	kart.setup(circuit, 0, false, animal, key)
	kart.set_process(false)
	kart.set_physics_process(false)
	kart.effects.set_process(false)
	kart.place(20, 0)
	camera.position = kart.position + Vector3(0, 8, 9)
	verify(kart.wheels.size() == 4 and kart.wheel_spin_pivots.size() == 4 and kart.wheel_steering_pivots.size() == 4,
		"Four independent wheel, spin, and steering bindings")
	var unique: Dictionary = {}
	var binds_preserved := authored.size() == 4
	var axes_identity := true
	for i in mini(4, kart.wheels.size()):
		for node in [kart.wheels[i], kart.wheel_spin_pivots[i], kart.wheel_steering_pivots[i]]:
			unique[node.get_instance_id()] = true
		binds_preserved = binds_preserved and wheel_transform(kart, i).is_equal_approx(authored[i])
		axes_identity = axes_identity and kart.wheels[i].basis.is_equal_approx(Basis.IDENTITY)
		axes_identity = axes_identity and kart.wheels[i].position.is_zero_approx()
	verify(unique.size() == 12, "Every wheel has its own steering and roll pivot without duplicate binding")
	verify(binds_preserved, "Imported wheel centres and bind transforms are preserved")
	verify(axes_identity, "Wheel mesh bases are identity beneath their independent pivots")
	verify(kart.driver.position.is_equal_approx(spec_value(spec, "driver_position", Vector3.ZERO)), "Driver has the specified seat offset")
	verify(kart.driver.scale.is_equal_approx(spec_value(spec, "driver_scale", Vector3.ONE)), "Driver has the specified seat scale")
	var collider: CollisionShape3D
	for child in kart.get_children():
		if child is CollisionShape3D: collider = child
	verify(is_instance_valid(collider), "Kart has a physical collision shape")
	if is_instance_valid(collider):
		verify(collider.shape is BoxShape3D and collider.shape.size.is_equal_approx(spec_value(spec, "collision_size", Vector3(2.15, 1.4, 3.5))), "Collision size matches the vehicle specification")
		verify(collider.position.is_equal_approx(spec_value(spec, "collision_position", Vector3(0, .78, 0))), "Collision centre matches the vehicle specification")
	var exhausts: Array = spec.get("exhausts", [Vector3(-.5, .47, 2.05), Vector3(.5, .47, 2.05)])
	var exhaust_ok := kart.flames.size() == exhausts.size() and kart.exhaust_trails.size() == exhausts.size()
	for i in mini(exhausts.size(), kart.flames.size()):
		exhaust_ok = exhaust_ok and kart.flames[i].position.distance_to(vec(exhausts[i])) < .001
		exhaust_ok = exhaust_ok and kart.exhaust_trails[i].position.distance_to(vec(exhausts[i])) < .001
	verify(exhaust_ok, "Flames and exhaust particles attach to the authored exhaust locations")
	if kart.wheels.size() == 4 and authored.size() == 4:
		test_wheel_motion(kart, authored, spec)
	test_recovery_pools(kart, camera)
	var errors_copy := current_errors.duplicate()
	var row := {"driver": animal, "driver_name": str(driver_data.name), "vehicle": key,
		"vehicle_name": str(vehicle_data.name), "checks": current_checks, "errors": errors_copy,
		"status": "PASS" if current_errors.is_empty() else "FAIL", "model": model_path}
	combinations.append(row)
	print(row.status, " ASTRA_COMBINATION ", current, " (", current_checks, " checks)")
	kart.free()
	await process_frame
	verify(not is_instance_valid(kart), "Kart and its effect pools release during teardown")
	row.checks = current_checks
	row.errors = current_errors.duplicate()
	row.status = "PASS" if current_errors.is_empty() else "FAIL"

func test_wheel_motion(kart: LeoKart, authored: Array[Transform3D], spec: Dictionary) -> void:
	kart.speed = 45.0
	kart.update_wheel_motion(Vector3.ZERO, 1.0 / 60.0)
	for frame in 144: kart.animate_wheels(1.0 / 144.0)
	var resting_roll := kart.wheel_roll
	kart.animate_wheels(.25)
	verify(kart.wheel_motion_speed == 0 and kart.wheel_visual_speed == 0 and is_equal_approx(resting_roll, kart.wheel_roll),
		"Stationary tires remain stopped despite high commanded throttle")
	kart.wheel_roll = 0
	kart.wheel_visual_speed = 0
	kart.update_wheel_motion(-kart.global_basis.z * 27.0 / 120.0, 1.0 / 120.0)
	verify(absf(kart.wheel_motion_speed - 27.0) < .001, "Wheel velocity follows measured forward displacement")
	for frame in 120: kart.animate_wheels(1.0 / 120.0)
	var radius := float(spec.get("wheel_radius", .49))
	var expected_travel := 27.0 * (1.0 - (1.0 - exp(-28.0)) / 28.0)
	var expected_roll := wrapf(-expected_travel / radius, -PI, PI)
	verify(absf(wrapf(kart.wheel_roll - expected_roll, -PI, PI)) < .002, "Rolling uses displacement and the authored tire radius")
	var finite := true
	var stable_centres := true
	var orthogonal := true
	var front_only := true
	for frame in 900:
		kart.steer = sin(float(frame) * .057)
		kart.update_wheel_motion(-kart.global_basis.z * (33.0 if frame % 160 < 120 else -9.0) / 144.0, 1.0 / 144.0)
		kart.animate_wheels(1.0 / 144.0)
		for i in 4:
			var combined := wheel_transform(kart, i)
			var yaw := -kart.steer * .35 if i < 2 else 0.0
			finite = finite and finite_transform(combined) and is_finite(kart.wheel_roll) and absf(kart.wheel_roll) <= PI
			stable_centres = stable_centres and combined.origin.distance_to(authored[i].origin) < .00001
			orthogonal = orthogonal and combined.basis.is_equal_approx(combined.basis.orthonormalized()) and absf(combined.basis.determinant() - 1.0) < .00001
			front_only = front_only and (combined.basis * Vector3.RIGHT).distance_to(Basis(Vector3.UP, yaw) * Vector3.RIGHT) < .00001
	verify(finite and orthogonal, "900 steering/rolling/reverse frames retain finite orthonormal bases and bounded angles")
	verify(stable_centres, "All wheel centres remain at their authored axle positions")
	verify(front_only, "Only front tires steer; rolling never tips an axle")
	kart.wheel_roll = 0
	kart.wheel_visual_speed = 0
	kart.update_wheel_motion(kart.global_basis.z * 8.0 / 60.0, 1.0 / 60.0)
	kart.animate_wheels(.05)
	verify(kart.wheel_motion_speed < -7.9 and kart.wheel_roll > 0, "Reverse displacement rolls every chassis in the opposite direction")

func test_recovery_pools(kart: LeoKart, camera: Camera3D) -> void:
	var effects: LeoKartEffects = kart.effects
	var pool_count := descendants(kart)
	var marks_count := effects.marks.size()
	var smoke_count := effects.smoke.size()
	var recovery_ok := true
	var reset_velocity := true
	var traces_created := false
	for iteration in 12:
		camera.position = kart.position + Vector3(0, 8, 9)
		kart.active = true
		kart.drifting = true
		kart.drift_charge = 1.2
		kart.wheel_motion_speed = 24
		kart.wheel_visual_speed = 24
		kart.boost_time = 1.6
		effects._process(.07)
		traces_created = traces_created or effects.marks.any(func(mark): return mark.visible)
		kart.impacted.emit(kart, kart.global_position, Vector3.RIGHT, 1.0)
		kart.next_gate = (iteration % maxi(1, LeoCircuit.GATES - 1)) + 1
		kart.recover()
		recovery_ok = recovery_ok and effects.marks.all(func(mark): return not mark.visible)
		recovery_ok = recovery_ok and effects.smoke.all(func(emitter): return not emitter.emitting)
		recovery_ok = recovery_ok and effects.ribbons.all(func(emitter): return not emitter.emitting)
		recovery_ok = recovery_ok and kart.exhaust_trails.all(func(emitter): return not emitter.emitting)
		reset_velocity = reset_velocity and is_zero_approx(kart.wheel_motion_speed) and is_zero_approx(kart.wheel_visual_speed)
	verify(traces_created, "Moving drift creates traces before recovery")
	verify(recovery_ok, "Twelve recoveries clear smoke, ribbons, trails, and road traces immediately")
	verify(reset_velocity, "Recovery clears measured and filtered tire velocities")
	verify(descendants(kart) == pool_count and effects.marks.size() == marks_count and effects.smoke.size() == smoke_count,
		"Repeated boosts, impacts, drifting, and recovery never accumulate effect nodes")
