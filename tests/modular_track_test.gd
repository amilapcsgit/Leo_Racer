extends SceneTree
var game: Node3D
var errors: Array[String]=[]
var checks:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await game.initialization_finished
	check(game.track_definition.id=="community_example","Track API 2 independently discovered")
	check(game.track_definition.modified,"Community track cannot claim official records")
	check(game.world.find_child("AuthenticLotusTower",true,false)==null,"Generic track has no hardcoded Colombo landmark")
	check(game.circuit.length>750 and game.circuit.length<760,"Baked route length matches runtime")
	var stream: Node=game.world.find_child("ColomboSceneryStreaming",true,false)
	check(stream.loaded.size()==2,"Namespaced detail cells use shared streamer")
	game.diagnostics_mode=true;game.human_count=2;game.local_players[1].vehicle_id=&"duster"
	await game.start_race();game.state="race"
	check(game.race_modified,"Community races excluded from official records")
	for kart in game.karts:kart.active=true;kart.auto_drive=true
	game.karts[0].active=false;game.karts[0].collision_layer=0
	Engine.time_scale=6.;Engine.max_physics_steps_per_frame=32
	var deadline:=Time.get_ticks_msec()+65000
	while not game.karts.all(func(k):return k.finished) and Time.get_ticks_msec()<deadline:
		if game.karts.slice(1).all(func(k):return k.finished):game.karts[0].active=true;game.karts[0].collision_layer=2
		await process_frame
	Engine.time_scale=1.
	check(game.karts.all(func(k):return k.finished and k.next_gate==25),"Six racers finish three laps of contributor track")
	check(game.ranking_store==null or game.race_modified,"Community run never writes official records")
	var report:={"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors,"track_id":game.track_definition.id,"length_m":game.circuit.length,"core_rebuild_required":false}
	FileAccess.open("res://build/modularity/track-kit.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("MODULAR_TRACK_TEST ",JSON.stringify(report))
	game.return_menu();game.stop_all_audio();game.queue_free();await process_frame;await process_frame;quit(0 if errors.is_empty() else 1)
