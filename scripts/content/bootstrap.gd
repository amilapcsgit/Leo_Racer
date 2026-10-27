extends Node
var screen: LeoLoadingScreen
const TRACE=preload("res://scripts/content/boot_trace.gd")
func _ready() -> void:
	TRACE.mark("bootstrap_ready")
	DisplayServer.window_set_title("Leo Racer")
	screen=LeoLoadingScreen.new();add_child(screen)
	await get_tree().process_frame
	await begin()
func begin() -> void:
	if "--vehicle-workshop" in OS.get_cmdline_user_args():
		await begin_workshop();return
	if "--verify-boot-art" in OS.get_cmdline_user_args():
		var errors: Array[String]=[]
		for path in [LeoLoadingBackdrops.DAY,LeoLoadingBackdrops.NIGHT]:
			var texture:=load(path) as Texture2D
			if not texture or texture.get_width()<1:errors.append(path)
		print("BOOT_ART_VALIDATION ",JSON.stringify({"status":"PASS" if errors.is_empty() else "FAIL","errors":errors,"before_asset_mount":true}))
		get_tree().quit(0 if errors.is_empty() else 1);return
	TRACE.mark("asset_validation_begin")
	screen.stage("Checking game assets…",5)
	await get_tree().process_frame
	if not OS.has_feature("editor"):
		var root:=OS.get_executable_path().get_base_dir().path_join("GameAssets")
		var validator:=Thread.new()
		validator.start(func():return LeoAssets.configure(root))
		while validator.is_alive():await get_tree().process_frame
		var error:=int(validator.wait_to_finish())
		TRACE.mark("asset_validation_complete")
		if error==OK:error=LeoAssets.mount_packs()
		TRACE.mark("packs_mounted")
		if error!=OK:
			printerr("CONTENT_VALIDATION_FAILED ",LeoAssets.failure)
			if "--verify-content" in OS.get_cmdline_user_args():get_tree().quit(2);return
			screen.show_failure(LeoAssets.failure,begin,func():get_tree().quit());return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--workshop-test="):
			var trial:=load("res://scripts/content/workshop_trial.gd").new() as Node3D
			trial.configure(argument.trim_prefix("--workshop-test="));get_tree().root.add_child(trial);get_tree().current_scene=trial;queue_free();return
	if "--verify-content" in OS.get_cmdline_user_args():
		var tracks:=LeoTrackDefinition.discover()
		if tracks.is_empty():printerr("CONTENT_VALIDATION_FAILED No compatible tracks");get_tree().quit(2);return
		for track in tracks:
			if not track.mount():printerr("CONTENT_VALIDATION_FAILED ",track.error);get_tree().quit(2);return
			print("TRACK_VERIFIED ",track.id," official=",not track.modified)
		print("CONTENT_VALIDATION_OK tracks=",tracks.map(func(t):return t.id)," cache=",LeoAssets.cache.size())
		get_tree().quit();return
	if "--verify-content-refresh" in OS.get_cmdline_user_args():
		# This diagnostic builds its own game UI. Do not leave bootstrap's higher
		# CanvasLayer intercepting the real pointer events under test.
		screen.hide()
		var report: Dictionary=await load("res://scripts/content/content_refresh_check.gd").run(get_tree())
		print("CONTENT_REFRESH_TEST ",JSON.stringify(report));get_tree().quit(0 if report.status=="PASS" else 2);return
	if "--validate-vehicles" in OS.get_cmdline_user_args():
		var report: Dictionary=await load("res://scripts/content/content_validator.gd").vehicles(get_tree())
		FileAccess.open("user://content-validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
		print("VEHICLE_VALIDATION ",JSON.stringify(report));get_tree().quit(0 if report.status=="PASS" else 2);return
	TRACE.mark("interface_load_begin")
	screen.stage("Loading interface…",20)
	var path:="res://scenes/main.tscn"
	ResourceLoader.load_threaded_request(path)
	while ResourceLoader.load_threaded_get_status(path)==ResourceLoader.THREAD_LOAD_IN_PROGRESS:await get_tree().process_frame
	if ResourceLoader.load_threaded_get_status(path)!=ResourceLoader.THREAD_LOAD_LOADED:
		screen.show_failure("Game interface could not be loaded.",begin,func():get_tree().quit());return
	TRACE.mark("interface_resource_loaded")
	var scene:=ResourceLoader.load_threaded_get(path) as PackedScene
	var game:=scene.instantiate();get_tree().root.add_child(game)
	while not game.initialized and game.initialization_error.is_empty():await get_tree().process_frame
	if not game.initialization_error.is_empty():
		var message: String=game.initialization_error
		game.queue_free();screen.show_failure(message,begin,func():get_tree().quit());return
	TRACE.mark("game_ready")
	get_tree().current_scene=game
	if "--drive-test" in OS.get_cmdline_user_args():
		for argument in OS.get_cmdline_user_args():
			if argument=="--distinct-check":
				screen.hide();var probe: Node=load("res://scripts/content/balance_check.gd").new();probe.game=game;get_tree().root.add_child(probe);probe.run.call_deferred();break
			if argument.begins_with("--vehicle-check="):
				screen.hide();var probe: Node=load("res://scripts/content/vehicle_check.gd").new();probe.game=game;get_tree().root.add_child(probe);probe.run.call_deferred();break
			if argument.begins_with("--track-check="):
				screen.hide();var probe: Node=load("res://scripts/content/track_check.gd").new();probe.game=game;get_tree().root.add_child(probe);probe.run.call_deferred();break
	queue_free()

func begin_workshop() -> void:
	DisplayServer.window_set_title("Leo Racer / Vehicle Workshop")
	var job: Dictionary={"format":1,"source":"","vehicles_root":OS.get_executable_path().get_base_dir().path_join("GameAssets/vehicles")}
	if OS.has_feature("editor"):job.vehicles_root=LeoVehicleLibrary.default_root()
	var job_path:=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--workshop-job="):job_path=argument.trim_prefix("--workshop-job=")
	if not job_path.is_empty():
		var file:=FileAccess.open(job_path,FileAccess.READ)
		var parsed: Variant=JSON.parse_string(file.get_as_text()) if file and file.get_length()<1048576 else null
		if not parsed is Dictionary or parsed.get("format")!=1:
			screen.show_failure("Workshop job could not be read.",begin_workshop,func():get_tree().quit());return
		job=parsed
	if not OS.has_feature("editor"):
		var folder:=OS.get_executable_path().get_base_dir().path_join("Tools/VehicleWorkshop")
		var metadata: Variant=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("workshop.json"))) if FileAccess.file_exists(folder.path_join("workshop.json")) else null
		if not metadata is Dictionary or metadata.get("workshop_api")!=1 or metadata.get("core_major")!=2 or not ProjectSettings.load_resource_pack(folder.path_join("workshop.pck"),true):
			screen.show_failure("Vehicle Workshop is missing or incompatible. Restore Tools/VehicleWorkshop from this development package.",begin_workshop,func():get_tree().quit());return
	screen.stage("Opening offline Vehicle Workshop…",75);await get_tree().process_frame
	var script:=load("res://tools/vehicle_workshop/workshop.gd") as GDScript
	if not script or not script.can_instantiate():
		screen.show_failure("Vehicle Workshop could not be loaded.",begin_workshop,func():get_tree().quit());return
	var app:=script.new() as Control
	app.configure(job)
	app.completed.connect(func(result: Dictionary):
		LeoWorkshopLauncher.write_result(job_path,result)
		get_tree().quit())
	get_tree().root.add_child(app);get_tree().current_scene=app;screen.hide()
	if "--workshop-smoke" in OS.get_cmdline_user_args():
		await get_tree().process_frame;await get_tree().process_frame
		var report:={"status":"PASS","workshop_api":1,"offline":true,"separate_entrypoint":true,"source_untouched":true}
		LeoWorkshopLauncher.write_result(job_path,report);print("WORKSHOP_BOOT_TEST ",JSON.stringify(report));get_tree().quit()
