extends SceneTree
var errors: Array[String]=[]
var checks:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func run() -> void:
	var tracks:=LeoTrackDefinition.discover()
	check(tracks.any(func(t):return t.id=="astra_coast" and t.revision==1 and not t.modified),"Original Astra retains official identity and route hash")
	var original:=LeoCircuit.new()
	var circuit:=LeoCircuit.new(tracks.filter(func(t):return t.id=="astra_coast")[0])
	check(circuit.points==original.points and circuit.length==original.length,"Registered Astra preserves every original point")
	for fraction in [0.,.1,.3,.5,.8,.99]:
		var s: float=fraction*circuit.length;var hit:=circuit.project(circuit.sample(s,4.))
		check(absf(circuit.delta_distance(s,hit.distance))<.1 and absf(hit.offset-4.)<.05,"Spatial route projection "+str(fraction))
	check(is_equal_approx(circuit.width_at(100),18.),"Legacy width remains 18 m")
	var data:=tracks[0].route.duplicate(true)
	data.widths=[]
	for i in data.points.size():data.widths.append(24. if i<100 else 18.)
	var custom:=LeoTrackDefinition.new();custom.route=data
	check(LeoCircuit.new(custom).width_at(0)==24.,"Track definition supplies local corner width")
	var game: Node3D=load("res://scenes/main.tscn").instantiate();root.add_child(game);await game.initialization_finished
	game.hud.show_tracks();await process_frame
	check(game.hud.modal_root.find_children("*","Button",true,false).size()>=2,"Track selector includes installed circuit and Back")
	check(await game.select_track("astra_coast"),"Existing track can reload through staged loader")
	check(game.world.get_children().size()>1 and game.circuit.definition.id=="astra_coast","World and track identity agree after selection")
	check(not await game.select_track("missing-track"),"Unknown track leaves current circuit available")
	game.human_count=2;await game.start_race();await process_frame
	check(game.karts.size()==6 and game.split_view.visible,"Track definition works with six-racer split screen")
	check(not await game.select_track("astra_coast"),"Track cannot change under an active race")
	game.return_menu();game.stop_all_audio();game.queue_free();await process_frame
	var store=load("res://scripts/LocalRankingStore.cs").new()
	var path:=ProjectSettings.globalize_path("user://city-rankings-test.sqlite3")
	for suffix in ["","-wal","-shm"]:DirAccess.remove_absolute(path+suffix)
	check(store.open_store(path),"Ranking database opens")
	var row:={"finished":true,"retired":false,"next_gate":25,"race_time":200.,"best_lap":60.,"profile_id":"city-player","name":"CITY PILOT","driver":"human","vehicle":"duster","class_id":"standard165","place":1}
	check(store.save_session("old-astra",1,[row],false,false)==1,"Legacy API remains compatible")
	row.race_time=400.;row.best_lap=120.
	check(store.save_session_for_track("city-r1",1,[row],false,false,"colombo_city",1)==1,"Colombo result saves transactionally")
	row.race_time=100.;row.best_lap=30.
	check(store.save_session_for_track("city-r2",1,[row],false,false,"colombo_city",2)==1,"New course revision saves separately")
	check(store.best_times(1,"standard165","",false)[0].race_ms==200000,"Colombo never replaces Astra best")
	check(store.best_times_for_track(1,"standard165","",false,"colombo_city",1)[0].race_ms==400000,"Revision one excludes faster revision two")
	check(store.best_times_for_track(1,"standard165","",true,"colombo_city",2)[0].lap_ms==30000,"Lap rankings also separate revisions")
	check(store.save_session_for_track("city-r2",1,[row],false,false,"colombo_city",2)==0,"Duplicate session is idempotent")
	check(store.save_session_for_track("modified",1,[row],true,false,"colombo_city",1)==0,"Modified course cannot set records")
	store.close_store();check(store.open_store(path),"Revision rankings persist after reopening")
	check(store.best_times(1,"standard165","",false).size()==1,"Legacy records survive reopening")
	store.close_store()
	var report:={"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors}
	FileAccess.open("res://docs/qa-colombo-city/tracks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("CITY_TRACKS_TEST ",report)
	quit(0 if errors.is_empty() else 1)
