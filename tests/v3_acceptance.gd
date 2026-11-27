extends SceneTree
var errors: Array[String]=[]
var checks:=0
var output:="res://build/distinct/v3"
var game: Node3D
class FakeRouter extends LeoInputRouter:
	var connected: Array[int]=[]
	func connected_devices() -> Array[int]:return connected
	func fingerprint(id: int) -> Dictionary:return {"guid":str(id),"name":"Test "+str(id)}
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="):output=arg.trim_prefix("--qa-output=")
	DirAccess.make_dir_recursive_absolute(output)
	var assets:=OS.get_environment("LEO_ASSET_ROOT")
	assert(LeoAssets.configure(assets)==OK and LeoAssets.mount_packs()==OK)
	LeoVehicleLibrary.discover()
	var inventory: Array=[]
	for raw in LeoVehicleLibrary.entries:
		var vehicle:=LeoVehiclePresentation.resolve(raw)
		var entry: Dictionary=vehicle.get_meta("presentation_audit").duplicate(true)
		var model:=vehicle.model.instantiate() as Node3D
		var materials: Array=[]
		for mesh in model.find_children("*","MeshInstance3D",true,false):
			for i in mesh.mesh.get_surface_count():
				var mat: Material=mesh.get_active_material(i)
				if mat is StandardMaterial3D:
					materials.append({"node":String(model.get_path_to(mesh)),"surface":i,"name":mat.resource_name,"roughness":mat.roughness,"metallic":mat.metallic,"clearcoat":mat.clearcoat_enabled,"unshaded":mat.shading_mode==BaseMaterial3D.SHADING_MODE_UNSHADED,"transparent":mat.transparency,"texture":mat.albedo_texture!=null,"normal":mat.normal_enabled})
		entry.materials=materials;inventory.append(entry);model.free()
		check(vehicle==LeoVehiclePresentation.resolve(vehicle),"Presentation applied once / "+String(raw.id))
		check(vehicle.official==raw.official and vehicle.content_folder==raw.content_folder,"Presentation preserves package classification / "+String(raw.id))
		for i in raw.wheels.size():
			check(vehicle.wheels[i].pivot==raw.wheels[i].pivot,"Model-local wheel pivot is not scaled twice / "+String(raw.id))
			check(absf(vehicle.wheels[i].radius-raw.wheels[i].radius*float(entry.factor))<.00001,"Wheel radius uses world metres / "+String(raw.id))
		check(vehicle.collision_size.is_finite() and vehicle.collision_size.min_axis_index()>=0,"Finite collision / "+String(raw.id))
		if raw.id==&"bigster":check(absf(vehicle.normalization.basis.get_scale().x-1.)<.0001,"Bigster is 100 percent")
	FileAccess.open(output.path_join("fleet-audit.json"),FileAccess.WRITE).store_string(JSON.stringify(inventory,"  "))
	if "--audit-only" in OS.get_cmdline_user_args():finish();return
	controller_tests()
	for kind in ["suv","sport","small","bus","electric"]:
		for layer in 5:
			var sound:=LeoVehicleAudio.loop(kind,layer)
			var peak:=0
			for sample in range(0,sound.data.size(),2):peak=maxi(peak,absi(sound.data.decode_s16(sample)))
			check(sound.mix_rate==22050 and sound.loop_end==11025 and peak>0 and peak<32767,"Generated audio is bounded and non-silent / "+kind+str(layer))
			if layer<3:check(absi(sound.data.decode_s16(0)-sound.data.decode_s16(sound.data.size()-2))<1500,"Engine loop seam / "+kind+str(layer))
			if layer==0:sound.save_to_wav(output.path_join(kind+"-idle.wav"))
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await game.initialization_finished
	game.diagnostics_mode=true;game.human_count=2
	var panel:=LeoControlsPanel.new();panel.router=game.input_router;root.add_child(panel)
	var closed:=[false]
	panel.closed.connect(func():closed[0]=true)
	var cancel:=InputEventAction.new();cancel.action="ui_cancel";cancel.pressed=true
	panel.pending_device={"kind":"gamepad","device":7};panel._input(cancel)
	check(panel.pending_device.is_empty() and not closed[0],"Controller Back cancels device confirmation")
	game.input_router.start_capture(0,"boost");panel._input(cancel)
	check(game.input_router.capture_slot<0 and not closed[0],"Back cancels capture without trapping controls")
	panel._input(cancel);check(closed[0],"Back exits controls after cancellation")
	panel.queue_free();await process_frame
	Engine.time_scale=8.;Engine.physics_ticks_per_second=480;Engine.max_physics_steps_per_frame=128
	for track in game.tracks:
		game.state="menu"
		await game.select_track(String(track.id))
		await game.start_race();game.set_process(false)
		for racer in game.karts:racer.set_physics_process(false)
		for slot in 2:
			var kart: LeoKart=game.local_players[slot].kart
			for next in [0,9,17,24]:
				kart.finished=false;kart.retired=false;kart.next_gate=next;kart.last_reported_gate=next-1;kart.active=true
				kart.recover()
				var lower: float=floorf(float(maxi(0,next-1))/8.)*game.circuit.length
				check(kart.next_gate==next and (kart.progress<0. if next==0 else kart.progress>=lower),"Recovery retains lap / "+String(track.id)+" P"+str(slot+1)+" gate "+str(next))
				var expected: float=float(next)*game.circuit.length/8.
				kart.place(expected-4.,0.);kart.auto_drive=true;kart.speed=12.;kart.ai.reset(42,0.)
				kart.set_physics_process(true)
				for tick in 180:
					await physics_frame
					if kart.next_gate>next:break
				kart.set_physics_process(false)
				check(kart.next_gate==next+1,"Real forward crossing after recovery / "+String(track.id)+" P"+str(slot+1)+" gate "+str(next))
				if next==24:check(kart.finished,"Finish is reachable after third-lap recovery")
			kart.finished=false;kart.active=true;kart.next_gate=9;kart.last_reported_gate=8
			kart.place(game.circuit.length*1.5,0.)
			var projection: Dictionary=game.circuit.project(kart.position)
			kart.advance_checkpoints(projection,Vector3.ZERO)
			check(kart.next_gate==9 and kart.checkpoint_missed,"Skipped checkpoint remains uncredited and Recover available")
			kart.recover();check(not kart.checkpoint_missed,"Recovery clears missed-checkpoint hint")
		game.human_count=2;game.state="race";game.race_time=900.
		game.karts[0].finished=true;game.karts[1].finished=false;game.karts[1].active=true
		game._process(.01);check(game.state=="race" and game.karts[1].active,"Late P2 can continue without timeout")
	game.human_count=1;game.hud.show_race()
	check(game.hud.labels.has("speed") and game.hud.labels.has("sector") and game.hud.binding_hints.size()==5,"Detailed solo HUD restored")
	game.hud._process(.016)
	check(game.hud.binding_hints[2].text==game.input_router.players[0].describe("recover"),"Solo HUD shows actual bindings")
	game.human_count=2;game.hud.show_race();check(game.hud.labels.is_empty(),"Split retains separate compact HUDs")
	finish()
func controller_tests() -> void:
	var router:=FakeRouter.new();router.active_slots=2
	router.connected=[0,1,2]
	router.assign(0,"gamepad",0,false);router.assign(1,"gamepad",1,false)
	router.assign(0,"gamepad",1,false)
	check(router.players[0].device==1 and router.players[1].device==2,"Occupied device moves other player to free controller")
	router.connected=[0,1];router.assign(0,"gamepad",0,false);router.assign(1,"gamepad",1,false);router.assign(1,"gamepad",0,false)
	check(router.players[1].device==0 and router.players[0].device==1,"No free controller swaps former device")
	router.connected=[0];router.assign(0,"keyboard",-1,false);router.assign(1,"gamepad",0,false);router.assign(0,"gamepad",0,false)
	check(router.players[0].device==0 and router.players[1].kind=="keyboard","One controller falls back to keyboard")
	router.assign(0,"keyboard",-1,false)
	check(router.ready_problem(0).is_empty() and router.ready_problem(1).is_empty(),"Shared keyboard fallback uses nonoverlapping layouts")
	router.free()
func finish() -> void:
	var report:={"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors}
	FileAccess.open(output.path_join("acceptance.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("V3_ACCEPTANCE ",JSON.stringify(report))
	if game:await game.quit_game(0 if errors.is_empty() else 2)
	else:quit(0 if errors.is_empty() else 2)
