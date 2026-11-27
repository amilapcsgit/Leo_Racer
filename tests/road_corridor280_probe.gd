extends SceneTree
## Source diagnostic. Samples the legal road corridor with production vehicle envelopes.

const VEHICLES := ["bigster", "duster"]

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="):
			output = arg.trim_prefix("--qa-output=")
	if output.is_empty():
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var game: Node3D = load("res://scenes/main.tscn").instantiate()
	game.diagnostics_mode = true
	root.add_child(game)
	await game.initialization_finished
	var findings := []
	var replay_ok := true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--road-addon="):
			var addon := LeoTrackDefinition.new()
			addon.folder = arg.trim_prefix("--road-addon=")
			addon.read_manifest(addon.folder.path_join("manifest.json"))
			if not addon.error.is_empty():
				push_error(addon.error)
				await game.quit_game(2)
				return
			game.tracks.append(addon)
	var tracks := []
	for definition in game.tracks:
		tracks.append(String(definition.id))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--road-track="):
			tracks = [arg.trim_prefix("--road-track=")]
	for track in tracks:
		print("ROAD_SWEEP_START ",track)
		if game.chosen_track_id != track and not await game.select_track(track):
			push_error("Road sweep failed to load " + track)
			await game.quit_game(2)
			return
		await physics_frame
		if "--road-replay" in OS.get_cmdline_user_args():
			replay_ok=(await replay_sector(game)) and replay_ok
			continue
		if "--road-boost-pads" in OS.get_cmdline_user_args():
			replay_ok=(await replay_boost_pads(game)) and replay_ok
			game.return_menu()
			continue
		var course: LeoCircuit = game.circuit
		var space := game.get_world_3d().direct_space_state
		for vehicle_id in VEHICLES:
			var vehicle: VehicleDefinition = game.catalog.vehicle(StringName(vehicle_id))
			var box := BoxShape3D.new()
			box.size = vehicle.collision_size
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = box
			query.collision_mask = 1
			for station in ceili(course.length):
				var distance := float(station)
				var basis := course.frame_at(distance)
				var edge := maxf(0.0, course.width_at(distance)*0.5-box.size.x*0.5-0.35)
				var steps := maxi(1, ceili(edge*2.0))
				for lane in range(steps+1):
					var offset := lerpf(-edge,edge,float(lane)/steps)
					var origin := course.sample(distance,offset)+Vector3.UP*.12
					var center := vehicle.collision_position

					query.transform = Transform3D(basis,origin+basis*center)
					var hit := space.get_rest_info(query)
					if hit.is_empty() or Vector3(hit.normal).y > 0.6:
						continue
					if not fits_road(course,query.transform,box.size,distance):
						continue
					var collider := instance_from_id(hit.collider_id) as Node
					findings.append({"track":track,"vehicle":vehicle_id,"station_m":distance,
						"offset_m":offset,"normal":str(hit.normal),
						"collider":str(collider.get_path()) if collider else ""})
				if station%100 == 0:
					await physics_frame
		print("ROAD_SWEEP_TRACK_DONE ",track," hits=",findings.size())
	var report := FileAccess.open(output.path_join("road-sweep.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify(findings,"  "))
	report.close()
	print("ROAD_SWEEP_DONE ",JSON.stringify({"status":"PASS" if findings.is_empty() and replay_ok else "FAIL","tracks":tracks,"hits":findings.size()}))
	await game.quit_game(0 if findings.is_empty() and replay_ok else 2)

func fits_road(course: LeoCircuit, transform: Transform3D, size: Vector3, station: float) -> bool:
	for x in [-.5, .5]:
		for z in [-.5, 0., .5]:
			var corner := transform * Vector3(float(x)*size.x, 0., float(z)*size.z)
			var projection := course.project(corner, int(station/course.step))
			if absf(projection.offset) > course.width_at(projection.distance)*.5 - .25:
				return false
	return true

func replay_sector(game: Node3D) -> bool:
	game.set_handling_preset(LeoRaceRules.Handling.STANDARD)
	await game.start_race()
	game.state = "race"
	var car: LeoKart = game.player
	for peer in game.karts:
		if peer != car:
			peer.collision_layer=0
			peer.set_physics_process(false)
	var course: LeoCircuit = game.circuit
	car.recovered.connect(func(_kart): print("ROAD_REPLAY_RECOVERY ",car.last_s/course.length))
	var passed := true
	for lane in [0.,-2.,2.,-3.5,3.5]:
		car.place(course.length*.625,lane)
		car.ai.reset(2026,lane)
		car.auto_drive=true
		car.active=true
		car.speed=40.
		car.velocity=course.direction(car.last_s)*car.speed
		var last_speed := car.speed
		for frame in 540:
			await physics_frame
			var stationed: float = float(course.project(car.position,car.nearest_index).distance)/course.length
			if stationed > .70:break
			for index in car.get_slide_collision_count():
				var hit:=car.get_slide_collision(index)
				if hit.get_normal().y < .65:
					print("ROAD_REPLAY_CONTACT ",stationed," ",car.speed," ",hit.get_normal()," ",hit.get_collider().get_path()," ",hit.get_position()," shape ",hit.get_collider_shape_index())
			if absf(car.speed-last_speed)>7.:
				print("ROAD_REPLAY_SPEED_CHANGE ",stationed," ",last_speed," -> ",car.speed," ",car.position)
			last_speed=car.speed
		var cleared := car.last_s/course.length > .70
		passed = passed and cleared
		print("ROAD_REPLAY_END ",lane," ",car.last_s/course.length," ",car.speed," cleared=",cleared)
	return passed

func replay_boost_pads(game: Node3D) -> bool:
	game.set_handling_preset(LeoRaceRules.Handling.STANDARD)
	await game.start_race()
	game.state = "race"
	var car: LeoKart = game.player
	for other in game.karts:
		if other != car:
			other.collision_layer = 0
			other.active = false
	var course: LeoCircuit = game.circuit
	var passed := not course.boosts.is_empty()
	for index in course.boosts.size():
		var station := float(course.boosts[index]) * course.length
		var lane := course.boost_lane(index)
		var outside := lane - signf(lane) * (LeoCircuit.BOOST_WIDTH * 0.5 + 0.8)
		for target in [lane, outside]:
			car.place(station - 3.5, target)
			car.active = true
			car.boost_cooldown = 0.0
			car.boost_time = 0.0
			car.speed = 22.0
			car.velocity = course.direction(station - 3.5) * car.speed
			for frame in 26:
				await physics_frame
			var triggered := car.boost_time > 0.0
			var matched: bool = triggered == (target == lane)
			print("BOOST_REPLAY ", course.definition.id, " ", index, " ", target, " triggered=", triggered, " matched=", matched)
			passed = passed and matched
	return passed
