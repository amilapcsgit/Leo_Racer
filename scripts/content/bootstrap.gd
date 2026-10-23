extends Node
var screen: LeoLoadingScreen
func _ready() -> void:
	screen=LeoLoadingScreen.new();add_child(screen)
	await get_tree().process_frame
	await begin()
func begin() -> void:
	if "--verify-boot-art" in OS.get_cmdline_user_args():
		var errors: Array[String]=[]
		for path in [LeoLoadingBackdrops.DAY,LeoLoadingBackdrops.NIGHT]:
			var texture:=load(path) as Texture2D
			if not texture or texture.get_width()<1:errors.append(path)
		print("BOOT_ART_VALIDATION ",JSON.stringify({"status":"PASS" if errors.is_empty() else "FAIL","errors":errors,"before_asset_mount":true}))
		get_tree().quit(0 if errors.is_empty() else 1);return
	screen.stage("Checking game assets…",5)
	await get_tree().process_frame
	if not OS.has_feature("editor"):
		var root:=OS.get_executable_path().get_base_dir().path_join("GameAssets")
		var validator:=Thread.new()
		validator.start(func():return LeoAssets.configure(root))
		while validator.is_alive():await get_tree().process_frame
		var error:=int(validator.wait_to_finish())
		if error==OK:error=LeoAssets.mount_packs()
		if error!=OK:
			printerr("CONTENT_VALIDATION_FAILED ",LeoAssets.failure)
			if "--verify-content" in OS.get_cmdline_user_args():get_tree().quit(2);return
			screen.show_failure(LeoAssets.failure,begin,func():get_tree().quit());return
	if "--verify-content" in OS.get_cmdline_user_args():
		var tracks:=LeoTrackDefinition.discover()
		if tracks.is_empty():printerr("CONTENT_VALIDATION_FAILED No compatible tracks");get_tree().quit(2);return
		for track in tracks:
			if not track.mount():printerr("CONTENT_VALIDATION_FAILED ",track.error);get_tree().quit(2);return
		print("CONTENT_VALIDATION_OK tracks=",tracks.map(func(t):return t.id)," cache=",LeoAssets.cache.size())
		get_tree().quit();return
	screen.stage("Loading interface…",20)
	var path:="res://scenes/main.tscn"
	ResourceLoader.load_threaded_request(path)
	while ResourceLoader.load_threaded_get_status(path)==ResourceLoader.THREAD_LOAD_IN_PROGRESS:await get_tree().process_frame
	if ResourceLoader.load_threaded_get_status(path)!=ResourceLoader.THREAD_LOAD_LOADED:
		screen.show_failure("Game interface could not be loaded.",begin,func():get_tree().quit());return
	var scene:=ResourceLoader.load_threaded_get(path) as PackedScene
	var game:=scene.instantiate();get_tree().root.add_child(game)
	while not game.initialized and game.initialization_error.is_empty():await get_tree().process_frame
	if not game.initialization_error.is_empty():
		var message: String=game.initialization_error
		game.queue_free();screen.show_failure(message,begin,func():get_tree().quit());return
	get_tree().current_scene=game;queue_free()
