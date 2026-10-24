extends SceneTree
var errors: Array[String]=[]
var checks:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:errors.append(message);push_error(message)
func ticks(n: int) -> void:
 for i in n:await physics_frame
func run() -> void:
 var game: Node3D=load("res://scenes/main.tscn").instantiate();root.add_child(game);await game.initialization_finished;await process_frame
 game.diagnostics_mode=true;game.human_count=2
 game.input_router.assign(1,"gamepad",17,false)
 game.selected_kart=game.catalog.vehicle_index(&"bigster")
 game.local_players[1].vehicle_id=&"duster";game.local_players[1].player_name="SECOND PILOT"
 await game.start_race();game.state="race"
 check(game.karts.size() == 6, "Six karts must be spawned")
 if game.karts.size() == 6:
  for kart in game.karts:kart.active=true
  for i in range(2,6):game.karts[i].active=false
  var a: LeoKart=game.karts[0];var b: LeoKart=game.karts[1]
  check(a.is_player and b.is_player,"Two humans and four AI")
  check(a.control_input!=b.control_input and a.control_input==game.input_router.players[0],"Independent providers")
  check(b.racer_name=="SECOND PILOT" and b.vehicle_key=="duster","Second player identity and vehicle")
  game.test_input("accelerate",1.,0);await ticks(75)
  check(a.speed>10 and absf(b.speed)<.1,"P1 throttle cannot drive P2")
  game.test_input("accelerate",0.,0);game.test_input("accelerate",1.,1);await ticks(75)
  check(b.speed>10,"P2 accelerates independently")
  game.local_players[0].lap_started=10.;game.local_players[1].lap_started=22.;game.race_time=70.
  game.on_gate(a,8);game.on_gate(b,8)
  check(is_equal_approx(game.local_players[0].best_lap,60.) and is_equal_approx(game.local_players[1].best_lap,48.),"Independent lap timing")
  a.next_gate=7;b.next_gate=7;a.recover();b.recover();await ticks(2)
  check(a.next_gate==7 and b.next_gate==7,"Recovery retains ordered gates")
  check(a.position.distance_to(b.position)>2.,"Simultaneous recovery uses separate safe lanes")
  var before_a:=a.position;var before_b:=b.position;var time: float=game.race_time
  game.toggle_pause();await create_timer(.08,true,false,true).timeout
  check(game.paused and a.position==before_a and b.position==before_b and game.race_time==time,"Shared pause freezes both racers")
  game.toggle_pause()
  game.input_router._connection(17,false)
  check(game.paused and not game.disconnect_message.is_empty(),"Device loss pauses both humans")
  game.input_router.assign(1,"gamepad",17,false);game.toggle_pause()
  check(game.local_players[1].announcement_time==0.,"Reassignment removes the disconnected HUD message")
  game.race_time=100.;game.on_gate(a,24);game._process(.1)
  check(a.finished and game.state=="race" and b.active,"First finisher does not stop P2")
  check(a.collision_layer==0 and a.collision_mask==1,"Finished car cannot block active player")
  game.race_time=120.;game.on_gate(b,24);game._process(.01)
  check(game.state=="results" and b.finished,"Results wait for both humans")
  await game.start_race();game.state="race";game.karts[0].active=true;game.karts[1].active=true
  game.retire_player(0);check(game.karts[0].retired and game.state=="race","P1 retirement lets P2 continue")
  game.retire_player(1);check(game.state=="results","Both retire ends the race")
  await game.start_race();game.countdown=.8
  game._on_local_command(0,"accelerate");game._process(1.)
  check(game.karts[0].boost_time>0 and game.karts[1].boost_time==0,"Countdown launch charge belongs only to the triggering player")
  await game.start_race();game.state="race"
  var first: LeoKart=game.karts[0];var second: LeoKart=game.karts[1]
  first.active=true;second.active=true;first.place(100.,0.);second.place(112.,0.)
  first.wheel_motion_speed=20.;second.wheel_motion_speed=20.;first.boost_fuel=.2;second.boost_fuel=.2
  game.update_slipstream(.5)
  check(first.boost_fuel>.2 and second.boost_fuel==.2,"Slipstream regeneration belongs to the trailing human")
  first.speed=20.;second.speed=-20.;game._process(.6)
  check(game.local_players[1].wrong_way>.5 and game.local_players[0].wrong_way==0.,"Wrong-way feedback is independent")
  game.selected_player_slot=1;game.toggle_pause();game.hud.show_garage("pause")
  var swap_id: StringName=&"blue" if game.catalog.vehicle(&"blue") else &"duster"
  check(game.swap_player_vehicle(&"mario",swap_id,"SECOND SWAP") and game.karts[0]==first and game.karts[1]!=second and game.local_players[1].kart==game.karts[1],"Pause car swap targets only P2")
  game.toggle_pause();game.hud.show_garage("pause");game.input_router.players[1].device=-1;game.diagnostics_mode=false
  check(not game.swap_player_vehicle(&"mario",&"duster","MISSING DEVICE") and game.paused,"Car change cannot bypass mandatory device reassignment")
  game.diagnostics_mode=true
 var report:={"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors}
 FileAccess.open("res://build/qa-ui/race.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("LOCAL_RACE_TEST ",report)
 game.return_menu();game.stop_all_audio();game.queue_free();await process_frame;await process_frame;quit(0 if errors.is_empty() else 1)
