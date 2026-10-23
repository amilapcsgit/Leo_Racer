extends SceneTree
var errors: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
	if not ok:errors.append(message);push_error(message)
func run() -> void:
	var game: Node3D=load("res://scenes/main.tscn").instantiate();root.add_child(game);await game.initialization_finished
	await game.select_track("colombo_city")
	var single:="--single-player" in OS.get_cmdline_user_args()
	game.diagnostics_mode=true;game.human_count=1 if single else 2
	game.selected_kart=game.catalog.vehicle_index(&"bigster");game.local_players[1].vehicle_id=&"duster"
	await game.start_race();game.state="race"
	for kart in game.karts:kart.active=true;kart.auto_drive=true
	Engine.time_scale=8.;Engine.max_physics_steps_per_frame=64
	var first_finish_interval:=false
	while game.race_time<1100. and game.state!="results":
		await physics_frame
		if not single and game.karts[0].finished!=game.karts[1].finished:
			first_finish_interval=true;check(game.state=="race","One human finishing must leave the other racing")
	Engine.time_scale=1.
	check(game.state=="results","Three laps complete within the route-scaled time budget")
	if not single:check(first_finish_interval,"Humans finish independently")
	var racers: Array=[]
	for kart in game.karts:
		if kart.is_player:check(kart.finished and kart.next_gate==25,"Human completed all checkpoints: "+kart.racer_name)
		racers.append({"name":kart.racer_name,"finished":kart.finished,"next_gate":kart.next_gate,"time":kart.finish_time})
	var report:={"status":"PASS" if errors.is_empty() else "FAIL","errors":errors,"full_race":racers,"first_finish_interval_seen":first_finish_interval,"track":"colombo_city","length_m":game.circuit.length}
	report.humans=game.human_count
	FileAccess.open("res://build/qa-ui/full-race%s.json" % ("-single" if single else ""),FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("CITY_FULL_RACE_TEST ",report)
	await game.quit_game(0 if errors.is_empty() else 1)
