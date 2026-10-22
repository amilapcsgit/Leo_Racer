extends SceneTree
var errors: Array[String]=[]
var checks:=0
var game: Node3D
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:errors.append(message);push_error(message)
func ticks(n: int) -> void:
 for i in n:await physics_frame
func overlap(a: LeoKart,b: LeoKart) -> bool:
 var query:=PhysicsShapeQueryParameters3D.new();var shape:=BoxShape3D.new();shape.size=a.definition.collision_size*.95;query.shape=shape;query.collision_mask=2;query.exclude=[a.get_rid()];query.transform=Transform3D(a.global_basis,a.global_position+a.global_basis*a.definition.collision_position)
 for hit in a.get_world_3d().direct_space_state.intersect_shape(query):
  if hit.collider==b:return true
 return false
func run() -> void:
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame;game.diagnostics_mode=true;game.human_count=2;game.selected_kart=game.catalog.vehicle_index(&"bigster");game.local_players[1].vehicle_id=&"duster"
 game.start_race();game.state="race";await ticks(2)
 var a: LeoKart=game.karts[0];var b: LeoKart=game.karts[1]
 var clear_spawn:=true
 for i in game.karts.size():
  for j in range(i+1,game.karts.size()):
   if overlap(game.karts[i],game.karts[j]):clear_spawn=false
 check(clear_spawn,"All six footprints spawn without overlap")
 for k in game.karts:k.active=false
 a.place(30.,0);b.place(44.,0);b.rotation.y+=PI;a.active=true;b.active=true
 game.test_input("accelerate",1.,0);game.test_input("accelerate",1.,1);a.speed=30.;b.speed=30.;await ticks(60)
 check(not overlap(a,b),"Head-on unequal-size vehicles remain separated")
 check(a.position.is_finite() and b.position.is_finite() and a.position.y<2 and b.position.y<2,"Head-on contact preserves grounded finite transforms")
 game.input_router.clear_all();a.active=false;b.active=false;a.place(90.,-2.8);b.place(90.,2.8);a.rotation.y-=.55;b.rotation.y+=.55;a.active=true;b.active=true;a.speed=22.;b.speed=22.;game.test_input("accelerate",1.,0);game.test_input("accelerate",1.,1);await ticks(60)
 check(not overlap(a,b) and a.position.is_finite() and b.position.is_finite(),"Side contact cannot interpenetrate or destabilize")
 game.input_router.clear_all();a.next_gate=4;b.next_gate=4;a.recover();b.recover();await ticks(2);check(not overlap(a,b) and a.next_gate==4 and b.next_gate==4,"Simultaneous recovery keeps footprints and ordered sectors")
 a.place(150.,8.8);a.active=false;await ticks(3)
 var projection: Dictionary=game.circuit.project(a.position)
 check(absf(projection.offset)+a.definition.collision_size.x*.5<=LeoCircuit.WIDTH*.5+.05,"Large SUV stays inside footprint-adjusted barrier")
 game.race_time=100.;game.on_gate(a,24);check(a.collision_layer==0,"Finished SUV is non-blocking")
 # A full shared-world race: diagnostic acceleration of wall time only.
 game.start_race();game.state="race"
 for kart in game.karts:kart.active=true;kart.auto_drive=true
 Engine.time_scale=8.;Engine.max_physics_steps_per_frame=32
 var deadline:=Time.get_ticks_msec()+100000
 var first_finish_seen:=false
 while not game.karts.all(func(k):return k.finished) and Time.get_ticks_msec()<deadline:
  await process_frame
  if game.karts[0].finished!=game.karts[1].finished:
   first_finish_seen=true
   check(game.state!="results","One human still racing after other finishes")
   # Only one assertion for this interval.
   break
 while not game.karts.all(func(k):return k.finished) and Time.get_ticks_msec()<deadline:await process_frame
 Engine.time_scale=1.
 check(game.karts.all(func(k):return k.finished and k.next_gate==25 and k.lap==3),"Both humans and all four AI complete three ordered laps")
 check(game.local_players[0].best_lap>0 and game.local_players[1].best_lap>0 and game.local_players[0].best_lap<99999 and game.local_players[1].best_lap<99999,"Independent best lap records survive a full race")
 var progress: Array=[]
 for k in game.karts:progress.append({"name":k.racer_name,"finished":k.finished,"next_gate":k.next_gate,"time":k.finish_time})
 var report:={"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors,"full_race":progress,"first_finish_interval_seen":first_finish_seen}
 FileAccess.open("res://docs/qa-local2player/integration.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("LOCAL_INTEGRATION_TEST ",report)
 game.return_menu();game.stop_all_audio();game.queue_free();await process_frame;await process_frame;quit(0 if errors.is_empty() else 1)
