extends Node
## Opt-in Windows-export checks; no editor, SDK or personal records required.
var game: Node3D
func run() -> void:
	var errors: Array[String]=[]
	var output := OS.get_user_data_dir()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="):output=arg.trim_prefix("--qa-output=")
	DirAccess.make_dir_recursive_absolute(output)
	var roster: Array=[]
	for vehicle: VehicleDefinition in game.catalog.vehicles:
		var rules := LeoRaceRules.resolve(vehicle)
		roster.append({"id":String(vehicle.id),"official":vehicle.official,"rules":rules})
		if vehicle.id!=&"bigster" and (rules.max_speed>=50. or rules.boosted_speed>=62.5):errors.append("Outright speed exceeds Bigster: "+String(vehicle.id))
		if rules.class_id!=(LeoRaceRules.CLASS if vehicle.official else "modded"):errors.append("Wrong ranking class")
	var vehicle: VehicleDefinition=LeoVehiclePresentation.resolve(game.catalog.vehicle(&"bigster"))
	if not vehicle.normalization.basis.get_scale().is_equal_approx(Vector3.ONE):errors.append("Bigster must be 100 percent scale")
	if not game.track_definition.ruleset_id().begins_with("distinct_v3"):errors.append("Wrong size-corrected record namespace")
	var bigster := LeoRaceRules.resolve(vehicle)
	for pair in [["bigster","suv"],["mclaren","sport"],["formula_blue","sport"],["aqua","small"],["race_bus","bus"],["hover","electric"]]:
		if LeoVehicleAudio.profile(game.catalog.vehicle(StringName(pair[0])))!=pair[1]:errors.append("Wrong sound class / "+pair[0])
	if bigster.max_speed!=50. or bigster.boosted_speed!=62.5 or bigster.acceleration!=18. or bigster.handling!=1. or vehicle.braking_regeneration!=.035:errors.append("Bigster changed")
	game.selected_kart=game.catalog.vehicle_index(&"bigster");await game.start_race()
	for kart in game.karts:
		var rules := LeoRaceRules.resolve(kart.definition)
		if kart.max_speed!=rules.max_speed or kart.boosted_ceiling()!=rules.boosted_speed or kart.acceleration!=rules.acceleration or kart.handling!=rules.handling:errors.append("Race override mismatch")
	for kart in game.karts:kart.set_physics_process(false)
	game.set_reduced_motion(true);game.player.speed=0.;game.player.wheel_motion_speed=0.
	game.update_local_camera(game.local_players[0],.1)
	var resting_position: Vector3=game.camera.position
	game.player.speed=50.;game.player.wheel_motion_speed=50.
	game.update_local_camera(game.local_players[0],.1)
	if game.camera.position.distance_to(resting_position)>.001 or game.camera.fov!=game.base_camera_fov:errors.append("Reduced Motion camera moves or changes FOV with speed")
	if game.ranking_store!=null:errors.append("Diagnostic opened personal records")
	var report := {"status":"PASS" if errors.is_empty() else "FAIL","errors":errors,"vehicles":roster.size(),"ruleset":game.track_definition.ruleset_id(),"roster":roster}
	FileAccess.open(output.path_join("packaged-balance.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("PACKAGED_BALANCE ",JSON.stringify({"status":report.status,"vehicles":roster.size(),"errors":errors}))
	await game.quit_game(0 if errors.is_empty() else 2)
