extends SceneTree
var phase:=""
var frames: Dictionary={}
var game: Node3D
func _initialize() -> void:run.call_deferred()
func _process(delta: float) -> bool:
	if not phase.is_empty():frames[phase].append(delta*1000.)
	return false
func begin(label: String) -> void:phase=label;frames[label]=[]
func run() -> void:
	root.size=Vector2i(1920,1080);Engine.max_fps=120
	game=load("res://scenes/main.tscn").instantiate()
	begin("cold_city_scene");root.add_child(game);await game.initialization_finished
	begin("track_change_astra");await game.select_track("astra_coast")
	begin("warm_city_scene");await game.select_track("colombo_city")
	begin("selected_garage_preview");game.hud.show_garage()
	await game.hud.garage_selector.set_selection(&"mario",&"bigster")
	begin("six_racer_assembly");game.human_count=2;await game.start_race()
	phase=""
	var result:={};var ok:=true
	for label in frames:
		var values: Array=frames[label];values.sort()
		if values.is_empty():ok=false;continue
		result[label]={"frames":values.size(),"p95_ms":values[int((values.size()-1)*.95)],"max_ms":values.back()}
		# Catch a frozen loading animation; report smaller insertion/shader spikes explicitly.
		if float(values.back())>1000.:ok=false
	var report:={"status":"PASS" if ok else "FAIL","renderer":RenderingServer.get_current_rendering_method(),"phases":result,"limit_ms":1000}
	FileAccess.open("res://docs/qa-colombo-city/loading.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("CITY_LOADING_PROFILE ",report)
	await game.quit_game(0 if ok else 1)
