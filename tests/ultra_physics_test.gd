extends SceneTree
var output := ""
var game: Node3D
var errors: Array[String]=[]
var checks:=0
var rows: Array=[]
var gates: Dictionary={}
func _initialize() -> void:run.call_deferred()
func check(ok: bool,text: String) -> void:
	checks+=1
	if not ok:errors.append(text);push_error(text)
func proxy(vehicle: VehicleDefinition,id: int,laps: int) -> LeoKart:
	var kart:=LeoKart.new();game.add_child(kart)
	kart.circuit=game.circuit;kart.racer_id=id;kart.vehicle_key=String(vehicle.id);kart.lap_count=laps
	kart.definition=LeoVehiclePresentation.resolve(vehicle);LeoRaceRules.apply(kart)
	kart.visual=Node3D.new();kart.add_child(kart.visual)
	var collider:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=kart.definition.collision_size;collider.shape=shape;collider.position=kart.definition.collision_position;kart.add_child(collider)
	kart.collision_layer=2;kart.collision_mask=3;kart.floor_snap_length=LeoArcadeDynamics.SNAP
	kart.ai_lane=-3.2 if id%2==0 else 3.2;kart.place(-8.-float(id/2)*12.,kart.ai_lane)
	kart.active=true;kart.auto_drive=true
	return kart
func run() -> void:
	output=ProjectSettings.globalize_path("res://build/qa270") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir().path_join("QA")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-output="):output=argument.trim_prefix("--qa-output=")
	DirAccess.make_dir_recursive_absolute(output)
	var content:=ProjectSettings.globalize_path("res://build/content-baseline/GameAssets") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir().path_join("GameAssets")
	check(LeoAssets.configure(content)==OK and LeoAssets.mount_packs()==OK,"Content mounted")
	LeoVehicleLibrary.discover();game=load("res://scenes/main.tscn").instantiate();game.diagnostics_mode=true;root.add_child(game);await game.initialization_finished
	game.set_process(false);game.hud.frontend.set_process(false);game.hud.hide();await game.hud.garage_selector.scheduler.pause_for_race();game.remove_racers();game.world.show();game.stage.hide()
	Engine.physics_ticks_per_second=720;Engine.time_scale=12.;Engine.max_physics_steps_per_frame=96;Engine.max_fps=0
	await stability()
	for track in ["astra_coast","colombo_city","kandy_lake"]:
		game.return_menu();await process_frame
		check(await game.select_track(track),"Track loads / "+track);game.set_process(false);await game.hud.garage_selector.scheduler.pause_for_race()
		for laps in [1,3,10]:await race_case(track,laps)
	Engine.time_scale=1.;Engine.physics_ticks_per_second=60;
	var report:={"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors,"cases":rows,"production_controller":true,"presentation_omitted_for_physics_matrix":true}
	DirAccess.make_dir_recursive_absolute(output)
	FileAccess.open(output.path_join("physics.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("ULTRA_PHYSICS_TEST ",JSON.stringify(report));await game.quit_game(0 if errors.is_empty() else 1)
func stability() -> void:
	check(await game.select_track("astra_coast"),"Stability track loads");game.set_process(false);await game.hud.garage_selector.scheduler.pause_for_race()
	for vehicle in game.catalog.vehicles:
		game.remove_racers();await physics_frame
		var kart:=proxy(vehicle,0,3);game.karts.append(kart);kart.auto_drive=false;kart.active=false;kart.collision_mask=1;kart.place(100.,0.)
		for tick in 90:await physics_frame
		check(kart.grounded and kart.position.is_finite() and kart.velocity.length()<1.,"Stationary grounded stability / "+String(vehicle.id))
		var landings: Array=[];kart.surface_feedback.connect(func(kind,strength):
			if kind=="landing":landings.append(strength))
		kart.position.y+=2.;kart.velocity.y=0.;kart.grounded=false;kart.airborne_time=0.;kart.landing_suppression=0.
		for tick in 120:await physics_frame
		check(kart.grounded and landings.size()==1,"Drop has one bounded landing / "+String(vehicle.id))
		check(absf(kart.dynamics.compression.x)<.001,"Landing settles / "+String(vehicle.id))
		kart.recover();landings.clear()
		for tick in 30:await physics_frame
		check(landings.is_empty(),"Recovery suppresses landing feedback / "+String(vehicle.id))
		kart.active=true;kart.auto_drive=true
		for tick in 180:await physics_frame
		check(kart.position.is_finite() and kart.velocity.is_finite() and absf(kart.speed)>5.,"Normal speed stability / "+String(vehicle.id))
		kart.boost(1.6,"test")
		for tick in 120:await physics_frame
		check(kart.position.is_finite() and kart.velocity.is_finite() and absf(kart.position.y-float(game.circuit.project(kart.position).center.y))<3.,"Boost stability / "+String(vehicle.id))
		print("ULTRA_STABILITY ",vehicle.id)
	game.remove_racers()
func race_case(track: String,laps: int) -> void:
	check(game.track_definition.id==track,"Actual track identity / "+track)
	game.remove_racers();await physics_frame
	game.active_laps=laps;game.state="race";game.race_time=0.;game.race_modified=true;gates.clear()
	for id in 6:
		var vehicle: VehicleDefinition=game.catalog.vehicles[(id*3)%game.catalog.vehicles.size()]
		var kart:=proxy(vehicle,id,laps);game.karts.append(kart);gates[id]=0
		kart.gate_crossed.connect(func(subject,gate):
			check(gate==int(gates[subject.racer_id]),"Ordered checkpoint / "+track)
			gates[subject.racer_id]=gate+1)
		kart.gate_crossed.connect(game.on_gate)
	for local in game.local_players:local.kart=null
	var limit:=maxf(240.,game.circuit.length*laps/12.)
	var finite:=true
	while game.race_time<limit and not game.karts.all(func(k):return k.finished):
		await physics_frame;game.race_time+=1./60.
		if fmod(game.race_time,30.)<1./60.:print("ULTRA_RACE_PROGRESS ",track," ",laps," ",game.race_time," ",game.karts.map(func(k):return k.next_gate))
		for kart in game.karts:
			finite=finite and kart.position.is_finite() and kart.velocity.is_finite()
	check(finite,"Finite race transforms / "+track)
	check(game.karts.all(func(k):return k.finished and k.next_gate==8*laps+1 and k.lap==laps),"All six finish %d laps / %s" % [laps,track])
	var result:={"track":track,"actual_track":game.track_definition.id,"length":game.circuit.length,"laps":laps,"finished":game.karts.filter(func(k):return k.finished).size(),"seconds":game.race_time,"next_gates":game.karts.map(func(k):return k.next_gate)}
	rows.append(result);print("ULTRA_RACE_CASE ",JSON.stringify(result))
