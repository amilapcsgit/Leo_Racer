extends SceneTree
## Compare streamed geometry with the pinned release, including tiny work slices.
var errors: Array[String] = []
var checks := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: errors.append(message)
func run() -> void:
	var baseline := ""
	var baseline_circuit := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-baseline-script="): baseline=arg.trim_prefix("--qa-baseline-script=")
		if arg.begins_with("--qa-baseline-circuit="): baseline_circuit=arg.trim_prefix("--qa-baseline-circuit=")
	if baseline.is_empty(): quit(2); return
	var original := GDScript.new()
	original.source_code=FileAccess.get_file_as_string(baseline)
	if original.reload() != OK: quit(2); return
	var game: Node3D = load("res://scenes/main.tscn").instantiate()
	game.diagnostics_mode = true
	root.add_child(game)
	await game.initialization_finished
	var circuit_script := GDScript.new()
	circuit_script.source_code=FileAccess.get_file_as_string(baseline_circuit)
	if circuit_script.reload()!=OK: await game.quit_game(2); return
	var original_circuit: RefCounted=circuit_script.new(game.track_definition)
	var original_us := 0
	var cached_us := 0
	for index in 120:
		for lane in [-100.,-24.,0.,24.,100.]:
			var point: Vector3=game.circuit.sample(game.circuit.length*index/120.,lane)+Vector3.UP*3.
			var began:=Time.get_ticks_usec()
			var expected: Dictionary=original_circuit.project(point)
			original_us += Time.get_ticks_usec()-began
			began=Time.get_ticks_usec()
			var actual: Dictionary=game.circuit.project(point)
			cached_us += Time.get_ticks_usec()-began
			check(actual==expected,"Projection caching preserves exact release projection results")
	var scenery: LeoTrackEnvironment = game.track_environment
	scenery.set_process(false)
	scenery.tile_job.clear()
	var legacy: Node3D=original.new()
	legacy.configure(game)
	game.world.add_child(legacy)
	legacy.set_process(false)
	var peak_slice_us := 0
	var total_slices := 0
	for index in 12:
		var position: Vector3=game.circuit.sample(game.circuit.length*index/12.,24.)
		var key:=Vector2i(floori(position.x/scenery.TILE),floori(position.z/scenery.TILE))
		if scenery.tiles.has(key):
			scenery.tiles[key].free()
			scenery.tiles.erase(key)
		legacy.build_tile(key)
		var job:=scenery.begin_tile(key)
		while true:
			var began:=Time.get_ticks_usec()
			var done:=scenery.advance_tile(job,1)
			peak_slice_us=maxi(peak_slice_us,Time.get_ticks_usec()-began)
			total_slices += 1
			if done: break
			if total_slices%32==0:
				scenery.change_tier(0 if scenery.tier==2 else 2)
				await process_frame
		var expected: MultiMesh=legacy.tiles[key].multimesh
		var actual: MultiMesh=scenery.tiles[key].multimesh
		check(expected.instance_count==actual.instance_count,"Sliced tile preserves baseline blade count")
		check(actual.visible_instance_count==mini(actual.instance_count,scenery.COUNTS[scenery.tier]),"In-flight detail changes apply to completed grass")
		for i in mini(expected.instance_count,actual.instance_count):
			check(expected.get_instance_transform(i).is_equal_approx(actual.get_instance_transform(i)),"Sliced tile preserves baseline placement")
		legacy.tiles[key].free()
		legacy.tiles.erase(key)
		scenery.tiles[key].free()
		scenery.tiles.erase(key)
		scenery.tile_job=scenery.begin_tile(key)
		scenery.advance_tile(scenery.tile_job,1)
		scenery.invalidate(job.area)
		scenery.pending.clear()
		scenery.elapsed=0.
		scenery._process(0.)
		check(scenery.tile_job.is_empty() and not scenery.tiles.has(key),"Invalidation cancels stale tile work")
	legacy.free()
	print("TILE280_PROFILE ",JSON.stringify({"status":"PASS" if errors.is_empty() else "FAIL","errors":errors,"checks":checks,"slices":total_slices,"peak_slice_ms":peak_slice_us/1000.,"original_projection_ms":original_us/1000.,"cached_projection_ms":cached_us/1000.}))
	await game.quit_game(0 if errors.is_empty() else 1)
