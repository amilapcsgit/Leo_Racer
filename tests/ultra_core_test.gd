extends SceneTree
var errors: Array[String]=[]
var checks:=0
var output := ""
var game: Node3D
class TwinRouter extends LeoInputRouter:
	func connected_devices() -> Array[int]:return [7,8]
	func fingerprint(_id: int) -> Dictionary:return {"guid":"same-guid","name":"Xbox Wireless Controller","serial":""}
	func save_profiles() -> Error:return OK

func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func run() -> void:
	output=ProjectSettings.globalize_path("res://build/qa270") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir().path_join("QA")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-output="):output=argument.trim_prefix("--qa-output=")
	DirAccess.make_dir_recursive_absolute(output)
	DirAccess.make_dir_recursive_absolute(output)
	var content:=ProjectSettings.globalize_path("res://build/content-baseline/GameAssets") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir().path_join("GameAssets")
	check(LeoAssets.configure(content)==OK and LeoAssets.mount_packs()==OK,"Verified released content mounts")
	LeoVehicleLibrary.discover()
	game=load("res://scenes/main.tscn").instantiate();game.diagnostics_mode=true;root.add_child(game);await game.initialization_finished
	check(game.catalog.vehicles.size()==21 and game.catalog.drivers.size()==6 and game.tracks.size()==3,"21 cars, six drivers, three tracks")
	check(game.selected_laps==3,"Default race length is three laps")
	for course in game.tracks:
		var map:=LeoTrackHologram.new();map.set_route(course)
		check(map.texture!=null,"Route outline generated: "+course.id);map.free()
	await records()
	haptics()
	controllers()
	var spring:=LeoArcadeDynamics.new();spring.spring_velocity.x=-1.
	for tick in 120:spring.spring(Vector3.ZERO,1./120.)
	check(spring.compression.length()<.001 and spring.spring_velocity.length()<.001,"Suspension settles in one second")
	for laps in [1,3,10]:
		game.selected_laps=laps;await game.start_race()
		check(game.karts.all(func(k):return not k.damage or k.damage.patches.is_empty()),"Contact prewarm leaves cars undamaged")
		check(game.karts.size()==6 and game.karts.all(func(k):return k.lap_count==laps),"Race snapshots laps for all six racers: %d" % laps)
		game.selected_laps=2
		check(game.karts[0].lap_count==laps and game.active_laps==laps,"Active race cannot change through setup settings")
		var kart: LeoKart=game.karts[0]
		game.state="race";game.race_time=100.
		game.on_gate(kart,LeoCircuit.GATES*laps-1)
		check(not kart.finished,"Race cannot finish before its final gate")
		kart.next_gate=LeoCircuit.GATES*laps+1
		game.on_gate(kart,LeoCircuit.GATES*laps)
		check(kart.finished,"Race finishes at configured final gate: %d" % laps)
		game.return_menu()
	game.selected_laps=3
	game.hud.frontend.show_setup(2);await process_frame
	check(game.hud.frontend.start_button!=null,"Redesigned split setup is interactive")
	game.hud.frontend.show_settings();await process_frame;game.hud.frontend.close_modal()
	game.hud.frontend.show_tracks();await process_frame;game.hud.frontend.close_modal()
	game.hud.frontend.show_records();await process_frame;game.hud.frontend.close_modal()
	check(game.hud.modal_root.get_child_count()==0,"Redesigned panels close and restore focus")
	var report:={"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors}
	FileAccess.open(output.path_join("core.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("ULTRA_CORE_TEST ",JSON.stringify(report))
	await game.quit_game(0 if errors.is_empty() else 1)
func records() -> void:
	var store=load("res://scripts/LocalRankingStore.cs").new()
	var path:=ProjectSettings.globalize_path("user://ultra-records-%d.sqlite3" % Time.get_ticks_usec())
	check(store.open_store(path),"SQLite opens")
	for laps in [1,3,10]:
		var row:={"finished":true,"retired":false,"next_gate":8*laps+1,"race_time":100.*laps,"best_lap":80.,"profile_id":"pilot","name":"ULTRA PILOT","driver":"human","vehicle":"bigster","class_id":"arcade_v2","place":1}
		var id:="lap-%d" % laps
		check(store.save_session_for_track(id,1,[row],false,false,"astra_coast",1,"ultra_v6_static",laps)==1,"Stores valid %d-lap result" % laps)
		check(store.save_session_for_track(id,1,[row],false,false,"astra_coast",1,"ultra_v6_static",laps)==0,"Idempotent result retry")
		check(store.best_times_for_track(1,"arcade_v2","",false,"astra_coast",1,"ultra_v6_static",laps).size()==1,"Race times separated by laps")
		check(store.best_times_for_track(1,"arcade_v2","",true,"astra_coast",1,"ultra_v6_static",laps).size()==1,"Best laps retain selected race context")
		var invalid:=row.duplicate();invalid.next_gate=8*laps
		check(store.save_session_for_track(id+"-short",1,[invalid],false,false,"astra_coast",1,"ultra_v6_static",laps)==0,"Incomplete checkpoint sequence excluded")
	check(store.save_session_for_track("lap-1",1,[],false,false,"astra_coast",1,"ultra_v6_static",3)==-1,"Conflicting session metadata rejected")
	check(store.best_times_for_track(1,"arcade_v2","",false,"astra_coast",1,"distinct_v5_static",3).is_empty(),"2.6 and 2.7 rulesets remain separate")
	store.close_store()
func haptics() -> void:
	var rumble:=LeoHaptics.new();root.add_child(rumble)
	var time: Array[float]=[0.];var sent: Array=[]
	rumble.clock=func():return time[0]
	rumble.output=func(device,weak,strong,duration):sent.append([device,weak,strong,duration])
	rumble.play(7,"crash",1.);rumble.play(7,"scrape",.2)
	check(rumble.channels.size()==1 and sent[-1][2]>.8,"Scrape cannot erase strong crash feedback")
	for event in sent:check(event[1]>=0. and event[1]<=1. and event[2]>=0. and event[2]<=1.,"Motor output is bounded")
	time[0]=1.;rumble.tick()
	check(rumble.channels.is_empty() and sent[-1][1]==0. and sent[-1][2]==0.,"Expired rumble explicitly stops")
	rumble.play(7,"landing");rumble.enabled=false;rumble.tick()
	check(rumble.channels.is_empty(),"Disabling cancels all feedback")
	rumble.enabled=true;rumble.play(7,"identify");rumble._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(rumble.channels.is_empty(),"Focus loss cancels all feedback")
	rumble.free()

func controllers() -> void:
	var router:=TwinRouter.new();router.settings_path="user://ultra-input-fixture.cfg";root.add_child(router);router.active_slots=2
	router.assign(0,"gamepad",7,false);router.assign(1,"gamepad",8,false)
	check(router.device_label(7)=="Xbox Controller · Pad 1 · Player 1" and router.device_label(8)=="Xbox Controller · Pad 2 · Player 2","Same-name controllers have unique player/Pad labels")
	router.begin_claim(1)
	var event:=InputEventJoypadButton.new();event.device=7;event.button_index=JOY_BUTTON_A;event.pressed=true
	check(router.claim_event(event) and router.claim_slot==-1,"Physical claim event is consumed")
	check(router.players[1].device==7 and router.players[0].device==8,"Claiming swaps ownership without sharing a pad")
	event.pressed=false;check(router.claim_event(event) and router.claimed_releases.is_empty(),"Claim release cannot activate menu navigation")
	router.begin_claim(0)
	var escape:=InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.pressed=true
	check(router.claim_event(escape) and router.claim_slot==-1,"Claim cancellation is consumed")
	var identity:={7:router.fingerprint(7),8:router.fingerprint(8)}
	router.restore_assignments([7,8],identity)
	check(router.players[0].device==-1 and router.players[1].device==-1,"Indistinguishable reconnects require confirmation")
	router.free()
