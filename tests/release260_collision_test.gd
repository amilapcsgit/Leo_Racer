extends SceneTree
var game: Node3D
var checks:=0
var errors: Array[String]=[]
var output:="res://build/quality25/test"
var mode:="audit"
var details: Dictionary={}
func _initialize() -> void:run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="):output=arg.trim_prefix("--qa-output=")
		if arg.begins_with("--quality25-mode="):mode=arg.trim_prefix("--quality25-mode=")
	DirAccess.make_dir_recursive_absolute(output)
	check(LeoAssets.configure(OS.get_environment("LEO_ASSET_ROOT"))==OK and LeoAssets.mount_packs()==OK,"RC assets mount")
	LeoVehicleLibrary.discover()
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await game.initialization_finished
	game.diagnostics_mode=true;game.set_process(false)
	if mode=="audit":await audit()
	elif mode=="contacts":await contacts()
	elif mode=="addons":await addons()
	elif mode=="capture":await collision_capture()
	elif mode=="replay":await replay()
	var report:={"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors,"details":details}
	FileAccess.open(output.path_join(mode+".json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("QUALITY25 ",JSON.stringify(report));await game.quit_game(0 if errors.is_empty() else 2)
func audit() -> void:
	check(LeoDefaultRoster.ids().size()==21,"Locked default roster contains twenty-one IDs")
	check(game.catalog.vehicles.size()==21,"Fresh selected content has exactly twenty-one packages")
	check(LeoDefaultRoster.ai_vehicles(game.catalog).size()==21,"All default AI choices come from roster")
	check(LeoRaceRules.ID=="ultra_v6_static","Collision changes have a new record ruleset")
	var missing:=LeoLocalPlayer.new(1);missing.restore({"vehicle":"excluded_temporarily"},game.catalog)
	check(missing.vehicle_id==&"bigster" and missing.preferred_vehicle_id==&"excluded_temporarily","Unavailable saved car uses Bigster without losing preference")
	var rows: Array=[]
	for vehicle in game.catalog.vehicles:
		check(String(vehicle.id) in LeoDefaultRoster.ids(),"Installed default ID / "+String(vehicle.id))
		var subject:=LeoKart.new();game.add_child(subject);subject.setup(game.circuit,0,false,"human",String(vehicle.id))
		subject.set_physics_process(false);subject.place(80.,0.)
		await physics_frame
		check(subject.damage.surfaces.size()>0,"Authored body surfaces found / "+String(vehicle.id))
		check(subject.scale==Vector3.ONE,"Physics scale remains identity / "+String(vehicle.id))
		check(subject.effects.marks.size()<=42,"Skid allocation bounded / "+String(vehicle.id))
		if not subject.damage.surfaces.is_empty():
			var entry: Dictionary=subject.damage.surfaces[0]
			var mesh: MeshInstance3D=entry.node
			var arrays: Array=mesh.mesh.surface_get_arrays(entry.surface)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var p: Vector3=mesh.global_transform*vertices[0]
			for i in 10:subject.report_contact(p,Vector3.RIGHT,Vector3.LEFT*20.,null,"concrete");subject.contact_clock+=.3
			check(not subject.damage.patches.is_empty() and subject.damage.patches.size()<=8,"Conforming cosmetic damage / "+String(vehicle.id))
			var count:=subject.damage.patches.size();subject.recover()
			check(subject.damage.patches.size()==count,"Recovery preserves cosmetic state / "+String(vehicle.id))
		game.reduced_motion=true;subject.active=false;subject.contact_recoil=Vector3(.1,0,.1);subject._physics_process(1./60.)
		check(subject.contact_recoil==Vector3.ZERO and subject.visual.rotation.x==0. and subject.visual.rotation.z==0.,"Reduced Motion suppresses chassis jolts / "+String(vehicle.id))
		game.reduced_motion=false
		rows.append({"id":String(vehicle.id),"official":vehicle.official,"damage_surfaces":subject.damage.surfaces.size(),"patches":subject.damage.patches.size(),"collision":LeoVehicleCodec.encode(subject.definition.collision_size)})
		subject.stop_audio();subject.queue_free();await physics_frame;await process_frame
	details.vehicles=rows
func contacts() -> void:
	game.selected_kart=game.catalog.vehicle_index(&"bigster");await game.start_race()
	for kart in game.karts:kart.set_physics_process(false)
	var subject: LeoKart=game.player;subject.auto_drive=false;subject.active=true
	var initial: float=game.circuit.length*.1
	var rows: Array=[]
	for speed in [3.,30.,62.5]:
		for angle in [0.,PI*.4]:
			subject.place(initial,0.);subject.speed=speed
			var normal:=Vector3.RIGHT.rotated(Vector3.UP,angle)
			var incoming: Vector3=Vector3.LEFT*speed
			var result:=LeoContactSolver.remove_closing(incoming,normal)
			check(result.length()<=incoming.length()+.001,"Static contact never adds energy")
			check(result.dot(normal)>=-.001,"Static contact removes penetration velocity")
			check((result.slide(normal)-incoming.slide(normal)).length()<.001,"Glancing contact retains tangent velocity")
			rows.append({"speed":speed,"angle":angle,"after":LeoVehicleCodec.encode(result)})
	# Real controller crossing against the installed continuous edge.
	for track in ["astra_coast","colombo_city","kandy_lake"]:
		game.return_menu();check(await game.select_track(track),"Contact track loads / "+track)
		await game.start_race()
		for kart in game.karts:kart.set_physics_process(false);kart.collision_layer=0
		subject=game.player;subject.collision_layer=2;subject.active=true;subject.auto_drive=false;subject.control_input=LeoPlayerInput.new()
		var station: float=game.circuit.length*.12;var width: float=game.circuit.width_at(station)*.5
		subject.place(station,width-subject.definition.collision_size.x*.5-.4)
		var outward: Vector3=game.circuit.frame_at(station).x
		subject.rotation.y=atan2(-outward.x,-outward.z);subject.speed=40.;subject.velocity=outward*40.
		subject.control_input.inject_test("accelerate",1.)
		var gate:=subject.next_gate
		for tick in 30:await physics_frame;subject._physics_process(1./60.)
		var projection: Dictionary=game.circuit.project(subject.position)
		check(absf(projection.offset)<width+.2,"Physical rail contains vehicle / "+track)
		check(subject.next_gate==gate,"Barrier contact cannot gain a checkpoint / "+track)
	game.return_menu();await game.select_track("astra_coast");await game.start_race()
	for kart in game.karts:kart.set_physics_process(false);kart.collision_layer=0
	var other: LeoKart=game.karts[1]
	subject=game.player
	for speed in [3.,30.,62.5]:
		for kind in ["head_on","rear_end","side"]:
			for car in [subject,other]:
				car.collision_layer=2;car.collision_mask=3;car.is_player=true;car.auto_drive=false;car.control_input=LeoPlayerInput.new();car.active=true;car.boost_time=0.
			var station: float=game.circuit.length*.1
			var separation: float=(subject.definition.collision_size.z+other.definition.collision_size.z)*.5+.2
			subject.place(station,0.);other.place(station+separation,0.)
			subject.speed=speed;other.speed=0.
			if kind=="head_on":other.rotation.y+=PI;other.speed=speed
			if kind=="side":
				subject.place(station,-2.1);other.place(station,0.)
				var right: Vector3=game.circuit.frame_at(station).x
				subject.rotation.y=atan2(-right.x,-right.z)
			var before:=subject.next_gate
			for tick in 20:
				await physics_frame
				subject._physics_process(1./60.);other._physics_process(1./60.)
				check(subject.velocity.length()<speed+2. and other.velocity.length()<speed+2.,"Pair contact has no artificial velocity spike / "+kind)
			check(subject.next_gate==before,"Pair contact cannot award checkpoint / "+kind)
			check(subject.position.is_finite() and other.position.is_finite(),"Pair contact remains finite / "+kind)
			rows.append({"kind":kind,"speed":speed,"after_a":subject.speed,"after_b":other.speed,"separation":subject.position.distance_to(other.position)})
	details.contacts=rows

func addons() -> void:
	check(game.catalog.vehicles.size()==21 and game.catalog.vehicle(&"blue")!=null,"Manual excluded package becomes selectable")
	var pool:=LeoDefaultRoster.ai_vehicles(game.catalog)
	check(pool.size()==21 and not pool.any(func(v):return v.id==&"blue"),"Manual add-on is excluded from automatic grids")
	var subject:=LeoKart.new();game.add_child(subject);subject.setup(game.circuit,0,false,"human","blue");subject.set_physics_process(false)
	check(subject.damage.surfaces.is_empty(),"Unreviewed add-on receives no guessed damage surfaces")
	subject.report_contact(subject.position,Vector3.RIGHT,Vector3.LEFT*20.,null,"concrete")
	check(subject.damage.patches.is_empty(),"Generic add-on contact keeps source finish pristine")
	subject.queue_free();await physics_frame

func collision_capture() -> void:
	game.return_menu();assert(await game.select_track("kandy_lake"));game.human_count=1
	game.selected_kart=game.catalog.vehicle_index(&"bigster");await game.start_race();game.state="race"
	root.size=Vector2i(1280,720)
	for car in game.karts:car.set_physics_process(false);car.active=false;car.collision_layer=0
	var subject: LeoKart=game.player;subject.collision_layer=2;subject.active=true;subject.auto_drive=false;subject.control_input=LeoPlayerInput.new()
	var station: float=game.circuit.length*.12;var half: float=game.circuit.width_at(station)*.5
	subject.place(station,half-subject.definition.collision_size.z*.5-.7)
	var outward: Vector3=game.circuit.frame_at(station).x
	subject.rotation.y=atan2(-outward.x,-outward.z);subject.speed=30.;subject.velocity=outward*30.
	game.local_players[0].heading=subject.rotation.y;game.local_players[0].camera_rig.reset()
	var frames:=output.path_join("frames");DirAccess.make_dir_recursive_absolute(frames)
	for index in 90:
		for step in 2:await physics_frame;subject._physics_process(1./60.)
		game.race_time+=1./30.
		var local: LeoLocalPlayer=game.local_players[0]
		local.camera_rig.orbit=Vector2(-.8,.12);local.camera_rig.orbit_idle=0.
		game.update_local_camera(local,1./30.)
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(frames.path_join("frame-%03d.png"%index))
	check(not subject.damage.patches.is_empty(),"Recorded physical barrier impact creates conforming damage")
	check(subject.damage.patches.size()<=8,"Recorded impact respects damage budget")
	details={"frames":90,"fps":30,"track":"kandy_lake","damage_patches":subject.damage.patches.size(),"renderer":RenderingServer.get_current_rendering_method()}

func replay() -> void:
	game.remove_racers()
	await process_frame;await physics_frame;await physics_frame
	var subjects: Array[LeoKart]=[]
	var traces: Array=[[],[]]
	for version in ["2.5","2.6"]:
		var kart: LeoKart=load("res://build/qa260/baseline_250_controller.gd").new() if version=="2.5" else LeoKart.new()
		game.add_child(kart);kart.setup(game.circuit,0,true,"human","bigster");LeoRaceRules.apply(kart)
		kart.set_physics_process(false);kart.active=true;kart.control_input=LeoPlayerInput.new();kart.place(100.,0.)
		# Both controllers see the same static world in the same physics tick.
		# Disable their mutual contact so the reference cannot push the candidate.
		kart.collision_layer=0;kart.collision_mask=1;subjects.append(kart)
	await process_frame;await physics_frame;await physics_frame
	for tick in 360:
		await physics_frame
		for index in subjects.size():
			var kart:=subjects[index]
			kart.control_input.inject_test("accelerate",1.);kart.control_input.inject_test("left",maxf(0.,sin(tick*.035)*.2));kart.control_input.inject_test("right",maxf(0.,-sin(tick*.035)*.2))
			kart.control_input.inject_test("drift",1. if tick>120 and tick<200 else 0.);kart.control_input.inject_test("boost",1. if tick==240 else 0.)
			kart._physics_process(1./60.)
			traces[index].append({"position":kart.position,"speed":kart.speed,"fuel":kart.boost_fuel})
	var position_error:=0.;var speed_error:=0.;var fuel_error:=0.
	var first_difference: Dictionary={}
	for tick in 360:
		if first_difference.is_empty() and traces[0][tick].position.distance_to(traces[1][tick].position)>.0001:first_difference={"tick":tick,"old":str(traces[0][tick]),"new":str(traces[1][tick])}
		position_error=maxf(position_error,traces[0][tick].position.distance_to(traces[1][tick].position))
		speed_error=maxf(speed_error,absf(traces[0][tick].speed-traces[1][tick].speed))
		fuel_error=maxf(fuel_error,absf(traces[0][tick].fuel-traces[1][tick].fuel))
	check(traces[1].all(func(row):return row.position.is_finite() and is_finite(row.speed) and row.fuel>=0. and row.fuel<=1.),"Historical replay comparison is diagnostic; 2.7 safety uses dedicated dynamics tests")
	details.replay={"first_difference":first_difference,"ticks":360,"position_error":position_error,"speed_error":speed_error,"fuel_error":fuel_error,"baseline":"release/2.5.0 @ 3d37854"}
	for kart in subjects:kart.stop_audio();kart.queue_free()
