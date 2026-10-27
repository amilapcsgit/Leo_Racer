extends SceneTree
var errors: Array[String]=[]
var checks := 0
var game: Node3D
var reports: Dictionary={}
var mode := "features"
var output := "res://build/distinct"
var gate_sequence: Dictionary={}

func _initialize() -> void:run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)

func save_report(name: String, data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(output)
	FileAccess.open(output.path_join(name+".json"),FileAccess.WRITE).store_string(JSON.stringify(data,"  "))

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--distinct-mode="):mode=arg.trim_prefix("--distinct-mode=")
		if arg.begins_with("--qa-output="):output=arg.trim_prefix("--qa-output=")
	var assets := OS.get_environment("LEO_ASSET_ROOT")
	check(LeoAssets.configure(assets)==OK and LeoAssets.mount_packs()==OK,"Asset packs mount")
	LeoVehicleLibrary.discover()
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await game.initialization_finished;game.diagnostics_mode=true
	if mode in ["races","pace","comparison","probe"]:
		# Accelerate batches while retaining the production 1/60 simulation step.
		Engine.time_scale=8.;Engine.physics_ticks_per_second=480;Engine.max_physics_steps_per_frame=128
	if mode=="races":await races()
	elif mode=="pace":await pace()
	elif mode=="comparison":await comparison()
	elif mode=="probe":await probe()
	else:await features()
	var report := {"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors,"mode":mode,"details":reports}
	save_report(mode,report);print("DISTINCT_TEST ",JSON.stringify(report))
	await game.quit_game(0 if errors.is_empty() else 2)

func features() -> void:
	var roster: Array=[]
	var official := 0
	for vehicle: VehicleDefinition in game.catalog.vehicles:
		var rules := LeoRaceRules.resolve(vehicle)
		roster.append({"id":String(vehicle.id),"official":vehicle.official,"rules":rules})
		check(rules.boosted_speed>=rules.max_speed and rules.max_speed>0.,"Valid limits / "+String(vehicle.id))
		if vehicle.id!=&"bigster":check(rules.max_speed<50. and rules.boosted_speed<62.5,"Bigster owns outright speed / "+String(vehicle.id))
		if vehicle.official:official+=1;check(rules.class_id==LeoRaceRules.CLASS,"Official comparison class")
		else:check(rules.class_id=="modded","Imported car remains unranked")
	check(game.catalog.vehicles.size()==20 and official==7,"Selected 20 installed cars / 7 official")
	var unknown := VehicleDefinition.new();unknown.id=&"unknown_future_car";unknown.official=false
	check(LeoRaceRules.resolve(unknown).max_speed==162./3.6,"Unknown import receives compact profile")
	var bigster: VehicleDefinition=game.catalog.vehicle(&"bigster")
	for pair in [["bigster","suv"],["mclaren","sport"],["formula_blue","sport"],["aqua","small"],["race_bus","bus"],["hover","electric"]]:
		if not game.catalog.vehicle(StringName(pair[0])):continue
		check(LeoVehicleAudio.profile(game.catalog.vehicle(StringName(pair[0])))==pair[1],"Vehicle sound class / "+pair[0])
	var rules := LeoRaceRules.resolve(bigster)
	check(rules.max_speed==50. and rules.boosted_speed==62.5 and rules.acceleration==18. and rules.handling==1.,"Bigster tuning preserved")
	check(bigster.braking_regeneration==.035 and bigster.electric_boost,"Bigster hybrid behavior retained")
	game.selected_kart=game.catalog.vehicle_index(&"bigster");await game.start_race()
	game.set_process(false)
	for kart in game.karts:kart.set_physics_process(false)
	var kart: LeoKart=game.player
	kart.active=true;kart.auto_drive=false
	var local: LeoLocalPlayer=game.local_players[0]
	var rig=local.camera_rig
	check(rig.field_of_view(0.,0.,false)==63. and rig.field_of_view(50.,0.,false)==73.,"Speed FOV endpoints")
	check(rig.field_of_view(90.,30.,false)==85. and rig.field_of_view(90.,30.,true,67.)==67.,"FOV cap and Reduced Motion")
	game.set_reduced_motion(true);kart.speed=50.;game.camera.fov=70.
	game.update_local_camera(local,1.)
	check(absf(game.camera.fov-game.base_camera_fov)<.001,"Reduced Motion selects constant base FOV")
	var resting_distance: float=game.camera.position.distance_to(kart.position)
	kart.wheel_motion_speed=50.;game.update_local_camera(local,1.)
	check(absf(game.camera.position.distance_to(kart.position)-resting_distance)<.001,"Reduced Motion suppresses speed-driven camera dolly")
	game.set_reduced_motion(false)
	for quality in 3:
		game.graphics_quality=quality;game.apply_graphics()
		check(not game.environment.ssr_enabled or (quality==2 and RenderingServer.get_current_rendering_method()=="forward_plus"),"SSR quality gate")
	game.human_count=2;game.graphics_quality=2;game.apply_graphics()
	check(not game.environment.ssr_enabled and not game.environment.volumetric_fog_enabled,"Split-screen caps expensive effects")
	game.human_count=1
	# A slower leader should cause a committed passing choice, no state mutation.
	var leader: LeoKart=game.karts[1]
	kart.place(100.,0.);leader.place(115.,0.);kart.speed=30.;leader.speed=12.
	for other in game.karts:
		if other!=kart and other!=leader:other.place(300.+other.racer_id*10.,0.)
	kart.ai.reset(42,0.);var position_before := kart.position
	var command := kart.ai.commands(kart,.2)
	check(absf(kart.ai.lane)>2. and kart.ai.commitment>0.,"AI chooses a passing lane")
	check(kart.position==position_before and kart.speed==30.,"AI decisions cannot mutate physics state")
	var committed := kart.ai.lane;kart.ai.commands(kart,.05)
	check(kart.ai.lane==committed,"AI holds passing commitment")
	leader.place(102.,kart.ai.lane);command=kart.ai.commands(kart,.2)
	check(command.throttle<=0. or kart.ai.lane!=committed,"AI aborts unsafe lane or brakes")
	kart.ai.reset(101,0.);var first := kart.ai.patience;kart.ai.reset(101,0.)
	check(first==kart.ai.patience,"Seeded personality is repeatable")
	# Real physics replay against the original controller, inherited setup only.
	await replay(kart)
	var audio := kart.motor_audio
	audio.throttle=1.;kart.wheel_motion_speed=25.;audio.update(.2)
	check(audio.layers.size()==5 and audio.rpm>900. and audio.gear>1,"Layered engine / RPM / virtual gears")
	var p2_audio := LeoVehicleAudio.new();leader.add_child(p2_audio);p2_audio.setup(leader)
	check(audio.bus_name!=p2_audio.bus_name,"Local audio buses are independent")
	p2_audio.queue_free()
	check(game.opponent_audio.voices.size()==4,"Nearby opponent voices bounded")
	var db=load("res://scripts/LocalRankingStore.cs").new()
	var database := output.path_join("records.sqlite3")
	DirAccess.remove_absolute(database)
	check(db.open_store(ProjectSettings.globalize_path(database)),"Isolated records store opens")
	var row := {"finished":true,"retired":false,"next_gate":25,"race_time":200.,"best_lap":60.,"profile_id":"test","name":"Test","driver":"human","vehicle":"bigster","class_id":"suv180","place":1}
	check(db.save_session_for_track("old",1,[row],false,false,"astra_coast",1,"balanced_v1")==1,"Legacy record retained")
	row.class_id=LeoRaceRules.CLASS
	check(db.save_session_for_track("new",1,[row],false,false,"astra_coast",1,LeoRaceRules.ID)==1,"New record stored")
	check(db.best_times_for_track(1,"suv180","",false,"astra_coast",1,"balanced_v1").size()==1 and db.best_times_for_track(1,LeoRaceRules.CLASS,"",false,"astra_coast",1,LeoRaceRules.ID).size()==1,"Rulesets remain isolated")
	db.close_store();reports.roster=roster
	await straight_measurements()

func straight_measurements() -> void:
	var holder := Node3D.new();root.add_child(holder)
	var floor_body := StaticBody3D.new();var floor_collision := CollisionShape3D.new();var floor_shape := BoxShape3D.new()
	floor_shape.size=Vector3(12000,1,12000);floor_collision.shape=floor_shape;floor_collision.position.y=-.5;floor_body.add_child(floor_collision);holder.add_child(floor_body)
	var definition := LeoTrackDefinition.new();var points: Array=[]
	for edge in 4:
		for i in 512:
			var corners := [Vector3(-2500,0,-2500),Vector3(2500,0,-2500),Vector3(2500,0,2500),Vector3(-2500,0,2500)]
			var point: Vector3=corners[edge].lerp(corners[(edge+1)%4],float(i)/512.)
			points.append([point.x,point.y,point.z])
	definition.route={"points":points,"length":20000.,"width":18.}
	var track := LeoCircuit.new(definition)
	var subjects: Array[LeoKart]=[];var times: Dictionary={};var peaks: Dictionary={};var speeds: Dictionary={}
	for vehicle: VehicleDefinition in game.catalog.vehicles:
		vehicle=LeoVehiclePresentation.resolve(vehicle)
		var kart := LeoKart.new();holder.add_child(kart);kart.definition=vehicle;kart.vehicle_key=String(vehicle.id);kart.circuit=track
		LeoRaceRules.apply(kart);kart.is_player=true;kart.control_input=LeoPlayerInput.new();kart.active=true
		kart.visual=Node3D.new();kart.add_child(kart.visual)
		var collision := CollisionShape3D.new();var shape := BoxShape3D.new();shape.size=vehicle.collision_size;collision.shape=shape;collision.position=vehicle.collision_position;kart.add_child(collision)
		kart.collision_layer=0;kart.collision_mask=1;kart.floor_snap_length=.5;kart.place(1000.,0.)
		kart.control_input.inject_test("accelerate",1.);subjects.append(kart);peaks[kart.vehicle_key]=0.
	for tick in 300:
		await physics_frame
		for kart in subjects:
			if kart.speed>=100./3.6 and not times.has(kart.vehicle_key):times[kart.vehicle_key]=float(tick+1)/60.
	for kart in subjects:speeds[kart.vehicle_key]=kart.speed;kart.boost(1.6,"MEASUREMENT")
	for tick in 96:
		await physics_frame
		for kart in subjects:peaks[kart.vehicle_key]=maxf(peaks[kart.vehicle_key],kart.speed)
	var rows: Array=[]
	for kart in subjects:
		check(absf(speeds[kart.vehicle_key]-kart.max_speed)<.001,"Measured normal ceiling / "+kart.vehicle_key)
		check(absf(peaks[kart.vehicle_key]-kart.boosted_ceiling())<.001,"Measured boost ceiling / "+kart.vehicle_key)
		rows.append({"id":kart.vehicle_key,"zero_to_100_seconds":times.get(kart.vehicle_key,0.),"normal_kmh":speeds[kart.vehicle_key]*3.6,"boost_kmh":peaks[kart.vehicle_key]*3.6})
	var compact_time: float=times.get("import_2024_byd_atto_2",100.)
	check(compact_time<times.get("bigster",0.),"Compact wins the measured launch section")
	reports.straight_measurements=rows
	holder.queue_free();await physics_frame

func replay(kart: LeoKart) -> void:
	var script := load("res://build/distinct/baseline/manual_controller.gd") as GDScript
	check(script!=null and script.can_instantiate(),"Baseline controller snapshot loads")
	if not script:return
	# Driving preservation must exclude the collision response being changed.
	var free_definition:=LeoTrackDefinition.new()
	free_definition.route={"length":30000.,"width":2000.,"points":[[-5000.,0.,0.],[5000.,0.,0.],[5000.,0.,5000.],[-5000.,0.,5000.]]}
	var free_track:=LeoCircuit.new(free_definition)
	var floor_body:=StaticBody3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(12000,1,12000)
	var collider:=CollisionShape3D.new();collider.shape=shape;collider.position.y=-.5;floor_body.add_child(collider);game.add_child(floor_body)
	var initial := free_track.length*.1
	var results: Array=[]
	for baseline in [true,false]:
		var subject: LeoKart=script.new() if baseline else LeoKart.new()
		game.add_child(subject);subject.setup(free_track,30,true,"human","bigster")
		subject.set_physics_process(false);subject.collision_mask=1
		subject.control_input=LeoPlayerInput.new();subject.active=true;subject.place(initial,0.)
		var trace: Array=[]
		for tick in 600:
			subject.control_input.inject_test("accelerate",1. if tick<380 else 0.)
			subject.control_input.inject_test("brake",1. if tick>=380 and tick<490 else 0.)
			subject.control_input.inject_test("left",.1 if tick>200 and tick<280 else 0.)
			subject.control_input.inject_test("right",.35 if tick>280 and tick<350 else 0.)
			subject.control_input.inject_test("drift",1. if tick>280 and tick<350 else 0.)
			subject.control_input.inject_test("boost",1. if tick==120 else 0.)
			await physics_frame
			subject._physics_process(1./60.)
			trace.append([subject.position.x,subject.position.y,subject.position.z,subject.speed,subject.rotation.y,subject.boost_fuel,subject.boost_time,subject.drift_charge])
		results.append(trace);subject.stop_audio();subject.free();await physics_frame
	var difference := 0.0
	for i in results[0].size():
		for j in results[0][i].size():difference=maxf(difference,absf(results[0][i][j]-results[1][i][j]))
	check(difference<.001,"Bigster original/new manual input replay matches")
	reports.manual_replay={"ticks":600,"maximum_difference":difference,"fixture":"unobstructed wide road; collisions tested separately"}
	floor_body.queue_free();await physics_frame

func races() -> void:
	game.set_process(false)
	var rows: Array=[]
	var covered: Dictionary={}
	var completed := 0
	var total := 0
	for track_id in ["astra_coast","colombo_city","kandy_lake"]:
		game.return_menu();check(await game.select_track(track_id),"Track loads / "+track_id)
		for seed_value in 10:
			game.return_menu();game.human_count=1
			game.selected_kart=(seed_value*5+rows.size()*7)%game.catalog.vehicles.size()
			proxy_grid(6)
			for kart in game.karts:
				kart.auto_drive=true;kart.active=true;kart.ai.reset(seed_value*1009+kart.racer_id,kart.ai_lane)
				covered[kart.vehicle_key]=true
			var deadline := maxf(500.,game.circuit.length*.24)
			while game.race_time<deadline and not game.karts.all(func(k):return k.finished):
				await physics_frame;game.race_time+=1./60.
				if int(game.race_time*60.)%120==0:
					for kart in game.karts:
						var measured: float=game.circuit.project(kart.position,kart.nearest_index).offset
						check(absf(measured-kart.road_offset)<.02,"Cached route offset agrees with geometric projection")
			var racers: Array=[]
			for kart in game.karts:
				total+=1
				if kart.finished:completed+=1
				check(kart.next_gate<=25,"No skipped or duplicated finish checkpoints")
				racers.append({"id":kart.vehicle_key,"finished":kart.finished,"gate":kart.next_gate,"seconds":kart.finish_time})
			rows.append({"track":track_id,"seed":seed_value,"racers":racers})
			print("DISTINCT_RACE ",track_id," seed=",seed_value," completed=",completed,"/",total)
			save_report("race-progress",{"races":rows,"covered":covered.keys(),"completed":completed,"total":total})
	check(float(completed)/maxi(1,total)>=.95,"At least 95 percent of racers finish")
	check(covered.size()==game.catalog.vehicles.size(),"All selected vehicles rotate through race grid")
	reports={"races":rows,"completion_rate":float(completed)/maxi(1,total),"vehicles":covered.size()}

func pace() -> void:
	# One isolated car at a time, with actual collision dimensions and controller.
	game.set_process(false)
	var rows: Array=[]
	for track_id in ["astra_coast","colombo_city","kandy_lake"]:
		game.return_menu();check(await game.select_track(track_id),"Pace track loads")
		for vehicle: VehicleDefinition in game.catalog.vehicles:
			game.return_menu();game.selected_kart=game.catalog.vehicle_index(vehicle.id)
			proxy_grid(1)
			game.player.auto_drive=true;game.player.active=true;game.player.ai.reset(100,0.);game.player.place(0.,0.)
			while game.player.next_gate<9 and game.race_time<maxf(240.,game.circuit.length*.12):
				await physics_frame;game.race_time+=1./60.
			check(game.player.next_gate>=9,"Clean lap completes / "+String(vehicle.id)+" / "+track_id)
			rows.append({"id":String(vehicle.id),"track":track_id,"lap_seconds":game.race_time,"gate":game.player.next_gate,"speed":game.player.speed,"progress":game.player.progress})
			print("DISTINCT_PACE ",JSON.stringify(rows[-1]))
			save_report("pace-progress",{"laps":rows})
	var reference: Dictionary={}
	for row in rows:
		if row.id=="bigster":reference[row.track]=row.lap_seconds
	var margins: Dictionary={}
	for vehicle: VehicleDefinition in game.catalog.vehicles:
		var ratio := 0.0
		for row in rows:
			if row.id==String(vehicle.id):ratio+=float(row.lap_seconds)/float(reference[row.track])/3.
		margins[String(vehicle.id)]=(ratio-1.)*100.
		if vehicle.id!=&"bigster":check(ratio>=1.02,"Bigster aggregate margin / "+String(vehicle.id))
	reports={"laps":rows,"normalized_lap_time_margin_percent":margins}

func proxy_grid(count: int, baseline_script: GDScript = null) -> void:
	# Same production controller, actual metadata/colliders and real track surfaces.
	# Omit render meshes/audio so 144 physics laps do not repeatedly import GLBs.
	game.remove_racers();game.state="race";game.race_time=0.;game.world.show();game.stage.hide()
	gate_sequence.clear()
	for i in count:
		var kart: LeoKart=baseline_script.new() if baseline_script else LeoKart.new();game.add_child(kart)
		kart.circuit=game.circuit;kart.racer_id=i;kart.vehicle_key=String(game.catalog.vehicles[(game.selected_kart+i*3)%game.catalog.vehicles.size()].id)
		kart.definition=LeoVehiclePresentation.resolve(game.catalog.vehicle(StringName(kart.vehicle_key)));LeoRaceRules.apply(kart)
		kart.visual=Node3D.new();kart.add_child(kart.visual)
		var collision := CollisionShape3D.new();var shape := BoxShape3D.new()
		shape.size=kart.definition.collision_size;collision.shape=shape;collision.position=kart.definition.collision_position;kart.add_child(collision)
		kart.collision_layer=2;kart.collision_mask=3;kart.floor_snap_length=.5
		kart.ai_lane=-3.2 if i%2==0 else 3.2
		kart.place(-8.-float(i/2)*12.,kart.ai_lane)
		kart.active=true;kart.auto_drive=true;kart.gate_crossed.connect(game.on_gate)
		gate_sequence[kart.racer_id]=0
		kart.gate_crossed.connect(func(subject,gate):
			if gate!=gate_sequence[subject.racer_id]:check(false,"Checkpoint event order")
			gate_sequence[subject.racer_id]=gate+1)
		game.karts.append(kart)
	game.player=game.karts[0];game.local_players[0].kart=game.player

func comparison() -> void:
	game.set_process(false)
	var baseline := load("res://build/distinct/baseline/ai_controller.gd") as GDScript
	var rows: Array=[]
	var totals := [0,0]
	for track_id in ["astra_coast","colombo_city","kandy_lake"]:
		game.return_menu();check(await game.select_track(track_id),"Comparison track loads")
		for version in 2:
			game.selected_kart=game.catalog.vehicle_index(&"bigster");proxy_grid(6,baseline if version==0 else null)
			var contacts := 0
			var touching: Dictionary={}
			while game.race_time<maxf(500.,game.circuit.length*.24) and not game.karts.all(func(k):return k.finished):
				await physics_frame;game.race_time+=1./60.
				for kart in game.karts:
					if kart.finished:continue
					var projection: Dictionary=game.circuit.project(kart.position,kart.nearest_index)
					var normal := Vector3(-projection.tangent.z,0,projection.tangent.x).normalized()
					var footprint: float=absf(kart.global_basis.x.dot(normal))*kart.definition.collision_size.x*.5+absf(kart.global_basis.z.dot(normal))*kart.definition.collision_size.z*.5
					var at_wall: bool=absf(projection.offset)>=maxf(3.,game.circuit.width_at(projection.distance)*.5-footprint-.15)-.02
					if at_wall and not touching.get(kart.racer_id,false):contacts+=1
					touching[kart.racer_id]=at_wall
			totals[version]+=contacts
			rows.append({"track":track_id,"controller":"baseline" if version==0 else "distinct_v2","boundary_contacts":contacts,"completed":game.karts.filter(func(k):return k.finished).size(),"seconds":game.race_time})
			print("DISTINCT_COMPARISON ",JSON.stringify(rows[-1]))
	# A lane obstruction gives the controller an avoidable wall, rather than
	# claiming an improvement when both controllers already run clean laps.
	game.return_menu();await game.select_track("colombo_city")
	var straight := 100.0
	for sample in range(100,5000,25):
		if absf(game.circuit.direction(sample).signed_angle_to(game.circuit.direction(sample+80.),Vector3.UP))<.02:straight=sample;break
	var wall := StaticBody3D.new();var collider := CollisionShape3D.new();var box := BoxShape3D.new()
	box.size=Vector3(2.8,3.,.5);collider.shape=box;wall.add_child(collider);game.add_child(wall)
	wall.position=game.circuit.sample(straight+30.)+Vector3.UP*1.5
	var facing: Vector3=game.circuit.direction(straight+30.);wall.rotation.y=atan2(-facing.x,-facing.z)
	for version in 2:
		game.selected_kart=game.catalog.vehicle_index(&"bigster");proxy_grid(1,baseline if version==0 else null)
		var kart: LeoKart=game.player;kart.place(straight,0.);kart.speed=30.;kart.ai_lane=0.;kart.ai.reset(100,0.)
		var contacts := 0
		for tick in 300:
			await physics_frame
			var hit_wall := false
			for i in kart.get_slide_collision_count():
				if kart.get_slide_collision(i).get_collider()==wall:hit_wall=true
			if hit_wall:contacts+=1
		totals[version]+=contacts
		rows.append({"track":"controlled_obstruction","controller":"baseline" if version==0 else "distinct_v2","wall_contact_frames":contacts})
	wall.free()
	check(totals[1]<totals[0],"New AI makes fewer boundary contacts than baseline")
	reports={"runs":rows,"baseline_contacts":totals[0],"new_contacts":totals[1]}

func probe() -> void:
	game.set_process(false);game.return_menu();await game.select_track("colombo_city")
	game.selected_kart=34;proxy_grid(6)
	for kart in game.karts:kart.ai.reset(1009+kart.racer_id,kart.ai_lane)
	for tick in 36000:
		await physics_frame;game.race_time+=1./60.
		if tick%1200==0:
			var rows: Array=[]
			for kart in game.karts:rows.append({"id":kart.vehicle_key,"s":kart.last_s,"speed":kart.speed,"gate":kart.next_gate,"lane":kart.ai.lane,"target_speed":kart.ai.target_speed,"gap":kart.ai.clear_distance,"stalled":kart.ai.stalled})
			print("AI_PROBE ",game.race_time," ",JSON.stringify(rows));save_report("probe-progress",{"time":game.race_time,"racers":rows})
		if game.karts.all(func(k):return k.finished):break
