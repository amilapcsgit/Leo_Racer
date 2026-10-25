extends SceneTree
var checks:=0
var errors: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func settle(streamer: Node3D) -> void:
	while streamer.busy:await process_frame
	await streamer.refresh(true)
	while streamer.busy:await process_frame
func run() -> void:
	var game: Node3D=load("res://scenes/main.tscn").instantiate();root.add_child(game);await game.initialization_finished
	check(await game.select_track("kandy_lake"),"Colombo scenery loads")
	var streamer: Node3D=game.world.find_child("ColomboSceneryStreaming",true,false)
	await settle(streamer)
	check(streamer.cells.size()>40 and streamer.loaded.size()>0 and streamer.loaded.size()<streamer.cells.size(),"Only nearby detail cells start resident")
	var count:=0;var buffers_valid:=true
	for node in game.world.find_children("*","MultiMeshInstance3D",true,false):
		if not node.has_meta("instance_buffer"):continue
		count+=1
		var buffer: PackedFloat32Array=node.get_meta("instance_buffer")
		var stride:=16 if node.multimesh.use_colors else 12
		if buffer.size()!=node.multimesh.instance_count*stride:buffers_valid=false
	check(count>10 and buffers_valid,"Offline bake retains explicit CPU instance buffers")
	var collision_count: int=game.world.find_children("*","StaticBody3D",true,false).size()
	game.human_count=2;await game.start_race();game.state="capture"
	for kart in game.karts:kart.active=false;kart.set_physics_process(false)
	game.karts[0].place(0,0);game.karts[1].place(game.circuit.length*.5,0)
	for local in game.local_players:local.camera.global_position=local.kart.position+Vector3.UP*4.
	await settle(streamer)
	var all_demanded:=true;var positions: Array[Vector3]=streamer.anchors()
	for cell in streamer.cells:
		var center:=Vector3(cell.center[0],0,cell.center[1])
		if streamer.wanted(center,streamer.load_radius,positions) and not streamer.loaded.has(cell.id):all_demanded=false
	check(all_demanded,"Union of both players and cameras receives scenery")
	check(game.world.find_children("*","StaticBody3D",true,false).size()==collision_count,"Streaming never removes race collision")
	var distant_count:=0
	for cell in streamer.cells:
		var center:=Vector3(cell.center[0],0,cell.center[1])
		if not streamer.wanted(center,streamer.unload_radius,positions):
			distant_count+=1
			check(not streamer.loaded.has(cell.id),"Distant cell released: "+String(cell.id))
	check(distant_count>0,"Hysteresis releases genuinely distant detail")
	check(LeoAssets.cache.size()<=12,"Resource cache remains bounded while driving")
	game.return_menu()
	var memory_samples: Array[float]=[]
	var node_counts: Array[int]=[]
	for cycle in 3:
		check(await game.select_track("astra_coast"),"Return to preserved circuit "+str(cycle))
		check(await game.select_track("colombo_city"),"Preserved Colombo loads")
		check(await game.select_track("kandy_lake"),"Reload city without stale cells "+str(cycle))
		streamer=game.world.find_child("ColomboSceneryStreaming",true,false);await settle(streamer)
		for frame in 4:await process_frame
		memory_samples.append(Performance.get_monitor(Performance.MEMORY_STATIC));node_counts.append(get_node_count())
		check(streamer.loaded.size()<streamer.cells.size() and LeoAssets.cache.size()<=12,"Repeated track loading stays bounded "+str(cycle))
	check(memory_samples[-1]<=memory_samples[1]*1.10+8.*1024.*1024.,"Repeated track changes do not accumulate substantial memory")
	check(node_counts[-1]<=node_counts[1]+2,"Repeated worlds do not accumulate nodes")
	var report:={"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors,"cells":streamer.cells.size(),"resident_cells":streamer.loaded.size(),"cache_entries":LeoAssets.cache.size(),"memory_static_bytes":memory_samples,"node_counts":node_counts}
	FileAccess.open("res://build/modularity/streaming.json" if "--modularity" in OS.get_cmdline_user_args() else "res://build/kandy/streaming.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("CITY_STREAMING_TEST ",report)
	await streamer.stop();game.stop_all_audio();game.queue_free();await process_frame;await process_frame;quit(0 if errors.is_empty() else 1)
