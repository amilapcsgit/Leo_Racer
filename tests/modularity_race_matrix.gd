extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
 var game: Node=load("res://scenes/main.tscn").instantiate();root.add_child(game);await game.initialization_finished;game.diagnostics_mode=true
 var rows: Array=[];var errors: Array[String]=[]
 Engine.physics_ticks_per_second=240;Engine.time_scale=20.;Engine.max_physics_steps_per_frame=128
 for track in ["astra_coast","colombo_city"]:
  await game.select_track(track)
  for humans in [1,2]:
   game.human_count=humans;game.selected_kart=game.catalog.vehicle_index(&"bigster");game.local_players[1].vehicle_id=&"duster"
   await game.start_race();game.state="race"
   for kart in game.karts:kart.active=true;kart.auto_drive=true
   game.karts[0].active=false;game.karts[0].collision_layer=0
   var deadline:=Time.get_ticks_msec()+180000;var premature:=false
   while not game.karts.all(func(k):return k.finished) and Time.get_ticks_msec()<deadline:
    if game.karts.slice(1).all(func(k):return k.finished):game.karts[0].active=true;game.karts[0].collision_layer=2
    if game.state=="results" and not game.karts[0].finished:premature=true;break
    await process_frame
   var finished: bool=game.karts.all(func(k):return k.finished and k.next_gate==25 and k.lap==3)
   if not finished or premature:errors.append(track+" / "+str(humans)+" human race did not complete correctly")
   rows.append({"track":track,"humans":humans,"racers":game.karts.size(),"three_laps_finished":finished,"premature_results":premature,"times":game.karts.map(func(k):return k.finish_time)})
   print("MODULARITY_RACE_CASE ",JSON.stringify(rows[-1]));game.return_menu()
 Engine.time_scale=1.;Engine.physics_ticks_per_second=60
 var report:={"status":"PASS" if errors.is_empty() else "FAIL","races":rows,"errors":errors}
 FileAccess.open("res://build/modularity/race-matrix.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("MODULARITY_RACE_MATRIX ",JSON.stringify(report))
 game.stop_all_audio();game.queue_free();await process_frame;await process_frame;quit(0 if errors.is_empty() else 1)
