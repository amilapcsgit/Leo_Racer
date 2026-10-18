extends SceneTree

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	run.call_deferred()

func verify(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)
	print(("PASS " if value else "FAIL ") + message)

func wheel_transform(kart: LeoKart, index: int) -> Transform3D:
	return kart.wheel_steering_pivots[index].transform * kart.wheel_spin_pivots[index].transform * kart.wheels[index].transform

func run() -> void:
	var circuit := LeoCircuit.new()
	for color in ["blue", "coral", "aqua", "pink"]:
		var source := load("res://assets/models/kart_%s.glb" % color).instantiate() as Node3D
		var authored: Array[Transform3D] = []
		for axle in ["front", "back"]:
			for side in ["left", "right"]:
				var wheel := source.find_child("wheel-%s-%s" % [axle, side], true, false) as MeshInstance3D
				authored.append(wheel.transform)
		source.free()
		var kart := LeoKart.new()
		root.add_child(kart)
		kart.setup(circuit, 1, false, "hedgehog", color)
		kart.set_physics_process(false)
		kart.set_process(false)
		verify(kart.wheels.size() == 4 and kart.wheel_spin_pivots.size() == 4, color + ": four independent spin and steering pivots")
		var bind_preserved := true
		for i in 4:
			bind_preserved = bind_preserved and wheel_transform(kart, i).is_equal_approx(authored[i])
		verify(bind_preserved, color + ": imported bind transforms and axle centers preserved")
		var centers_stable := true
		var axles_stable := true
		var bases_stable := true
		var angle_bounded := true
		# More than 100,000 degrees of rolling while steering in both directions,
		# including reverse. A spinning tire's axle must never tip with its roll.
		for frame in 12000:
			kart.speed = -10.0 if frame % 800 > 600 else 43.0
			kart.update_wheel_motion(-kart.global_basis.z * kart.speed / 144.0, 1.0 / 144.0)
			kart.steer = sin(float(frame) * .037)
			kart.animate_wheels(1.0 / 144.0)
			angle_bounded = angle_bounded and absf(kart.wheel_roll) <= PI
			for i in 4:
				var combined := wheel_transform(kart, i)
				var yaw := -kart.steer * .35 if i < 2 else 0.0
				var expected_axle := Basis(Vector3.UP, yaw) * Vector3.RIGHT
				centers_stable = centers_stable and combined.origin.distance_to(authored[i].origin) < .00001
				axles_stable = axles_stable and (combined.basis * Vector3.RIGHT).distance_to(expected_axle) < .00001
				bases_stable = bases_stable and combined.basis.is_equal_approx(combined.basis.orthonormalized()) and absf(combined.basis.determinant() - 1.0) < .00001
		verify(centers_stable and axles_stable, color + ": tires retain axle alignment and center through 12,000 steering/spin frames")
		verify(bases_stable and angle_bounded, color + ": no accumulated skew, scale drift, or unbounded angles")
		kart.speed = 43
		kart.update_wheel_motion(Vector3.ZERO, 1.0 / 60.0)
		for frame in 144: kart.animate_wheels(1.0 / 144.0)
		var stopped_roll := kart.wheel_roll
		kart.steer = 1
		kart.animate_wheels(1.0)
		verify(is_equal_approx(kart.wheel_roll, stopped_roll) and is_zero_approx(kart.wheel_steering_pivots[2].rotation.y), color + ": stationary tires stop despite commanded 43 m/s and rear wheels never steer")
		kart.speed = 33
		kart.update_wheel_motion(-kart.global_basis.z * 33.0 / 60.0, 1.0 / 60.0)
		var final_angles: Array[float] = []
		for rate in [30, 60, 144]:
			kart.wheel_roll = 0
			kart.wheel_visual_speed = 0
			for frame in rate * 3: kart.animate_wheels(1.0 / rate)
			final_angles.append(kart.wheel_roll)
		verify(absf(wrapf(final_angles[0] - final_angles[2], -PI, PI)) < .0002 and absf(wrapf(final_angles[1] - final_angles[2], -PI, PI)) < .0002, color + ": wheel travel agrees at 30, 60, and 144 rendered FPS")
		kart.wheel_roll = 0
		kart.wheel_visual_speed = 0
		kart.update_wheel_motion(kart.global_basis.z * 8.0 / 60.0, 1.0 / 60.0)
		kart.animate_wheels(.05)
		verify(kart.wheel_motion_speed < -7.9 and kart.wheel_roll > 0, color + ": reverse displacement spins tires backward independently of throttle")
		kart.active = true
		kart.boost_time = 1
		kart._process(1.0 / 144.0)
		verify(kart.flames[0].visible and kart.exhaust_trails[0].emitting and not kart.spark_left.emitting, color + ": boost emits separate exhaust trails without false drift sparks")
		kart.boost_time = 0
		kart.drifting = true
		kart.drift_charge = .8
		kart._process(1.0 / 144.0)
		verify(not kart.flames[0].visible and not kart.exhaust_trails[0].emitting and kart.spark_left.emitting and kart.spark_right.emitting, color + ": charged drift emits sparks on both rear tires")
		kart.free()
	await test_blocked_kart(circuit)
	print("WHEEL_TEST_REPORT ", JSON.stringify({"status": "PASS" if failures.is_empty() else "FAIL", "checks": checks, "errors": failures}))
	quit(0 if failures.is_empty() else 1)

func static_box(center: Vector3, size: Vector3, yaw := 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	root.add_child(body)
	body.position = center
	body.rotation.y = yaw
	return body

func test_blocked_kart(circuit: LeoCircuit) -> void:
	var kart := LeoKart.new()
	root.add_child(kart)
	kart.setup(circuit, 1, false, "hedgehog", "blue")
	kart.place(40, 0)
	var start := kart.global_position
	var forward := -kart.global_basis.z
	var floor := static_box(start + Vector3.DOWN * .62, Vector3(50, 1, 50))
	var wall := static_box(start + forward * 7 + Vector3.UP * 3, Vector3(20, 8, 1), kart.rotation.y)
	for frame in 130:
		# Hold the commanded road speed high while real CharacterBody collisions
		# stop motion. This reproduces grinding into an obstruction in the clip.
		kart.speed = 43
		await physics_frame
		await process_frame
	verify(kart.speed > 40 and absf(kart.wheel_motion_speed) < .05 and absf(kart.wheel_visual_speed) < .1, "Actual wall collision stops rolling while commanded speed remains above 40 m/s")
	for frame in 45:
		kart.speed = -10
		await physics_frame
		await process_frame
	verify(kart.wheel_motion_speed < -8 and kart.wheel_visual_speed < -8, "Reversing away from a wall resumes rolling in the correct direction")
	kart.recover()
	verify(is_zero_approx(kart.wheel_motion_speed) and is_zero_approx(kart.wheel_visual_speed), "Recovery clears wheel velocity so teleport distance cannot spin tires")
	kart.free()
	wall.free()
	floor.free()
