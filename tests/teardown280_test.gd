extends SceneTree
## Stress the same rendered race restart/return path used by the moving probe.
class AnchorCourse extends RefCounted:
	func sample(_distance: float) -> Vector3: return Vector3(123,0,456)
class StreamHost extends Node3D:
	var karts: Array = []
	var local_players: Array = []
	var human_count := 1
	var circuit := AnchorCourse.new()

static func verify_detached_anchors(tree_root: Window = null) -> Dictionary:
	var errors: Array[String] = []
	var host := StreamHost.new()
	var kart := LeoKart.new()
	var camera := Camera3D.new()
	var local := LeoLocalPlayer.new(0)
	local.kart=kart
	local.camera=camera
	host.karts.append(kart)
	host.local_players.append(local)
	var streamer: Node3D=load("res://scripts/content/city_streamer.gd").new()
	streamer.game=host
	if not is_inf(streamer.priority(Vector3.ONE)):
		errors.append("A detached racer must not contribute streaming priority")
	var anchors: Array=streamer.anchors()
	if anchors.size()!=1 or not anchors[0].is_equal_approx(Vector3(123,0,456)):
		errors.append("Detached racers/cameras use the safe course anchor")
	var checks := 2
	if tree_root:
		tree_root.add_child(host)
		var scenery := LeoTrackEnvironment.new()
		scenery.game=host
		var fixture := LeoTrackDefinition.new()
		fixture.route={"length":400.,"points":[[0.,0.,0.],[100.,0.,0.],[100.,0.,100.],[0.,0.,100.]]}
		scenery.circuit=LeoCircuit.new(fixture)
		host.add_child(scenery)
		scenery.set_process(false)
		scenery.refresh_wanted()
		checks += 1
		if scenery.last_centers.size()!=1 or not scenery.last_centers[0].is_equal_approx(scenery.circuit.sample(0)):
			errors.append("Environment streaming ignores detached racers")
		scenery.free()
	streamer.free()
	kart.free()
	camera.free()
	host.free()
	return {"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors}

func _initialize() -> void: run.call_deferred()
func run() -> void:
	var detached := verify_detached_anchors(root)
	print("STREAMER_LIFECYCLE280_TEST ",JSON.stringify(detached))
	if not detached.errors.is_empty(): quit(1); return
	var game: Node3D=load("res://scenes/main.tscn").instantiate()
	game.diagnostics_mode=true
	root.add_child(game)
	await game.initialization_finished
	await game.select_track("kandy_lake")
	game.human_count=2
	game.selected_kart=game.catalog.vehicle_index(&"bigster")
	game.local_players[1].vehicle_id=&"duster"
	for repeat_index in 50:
		await game.start_race()
		game.state="race"
		for kart in game.karts:
			kart.active=true
			kart.auto_drive=true
		for frame in 20: await process_frame
		for slot in game.human_count:
			var kart: LeoKart=game.local_players[slot].kart
			kart.report_contact(kart.global_position+Vector3.UP*.5,Vector3.RIGHT,Vector3.LEFT*12.,null,"concrete")
		game.return_menu()
		for frame in 3: await process_frame
	print("TEARDOWN280_TEST ",JSON.stringify({"status":"PASS","restarts":50}))
	await game.quit_game()
