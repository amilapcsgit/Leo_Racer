extends Node
var screen: LeoLoadingScreen
func _ready() -> void:
	screen=LeoLoadingScreen.new();add_child(screen)
	await get_tree().process_frame
	await begin()
func begin() -> void:
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
			screen.show_failure(LeoAssets.failure,begin,func():get_tree().quit());return
	screen.stage("Loading interface…",20)
	var path:="res://scenes/main.tscn"
	ResourceLoader.load_threaded_request(path)
	while ResourceLoader.load_threaded_get_status(path)==ResourceLoader.THREAD_LOAD_IN_PROGRESS:await get_tree().process_frame
	if ResourceLoader.load_threaded_get_status(path)!=ResourceLoader.THREAD_LOAD_LOADED:
		screen.show_failure("Game interface could not be loaded.",begin,func():get_tree().quit());return
	var scene:=ResourceLoader.load_threaded_get(path) as PackedScene
	var game:=scene.instantiate();get_tree().root.add_child(game)
	if not game.initialized:await game.initialization_finished
	get_tree().current_scene=game;queue_free()
