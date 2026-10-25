extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
 var game: Node3D=load("res://scenes/main.tscn").instantiate();root.add_child(game);await game.initialization_finished
 game.diagnostics_mode=true;game.human_count=2
 Engine.time_scale=12.;Engine.max_physics_steps_per_frame=96
 var rows: Array=[];var errors: Array[String]=[]
 for id in ["import_1968_volkswagen_beetle","byd_yangwang_u8","import_toyota_landcruiser_v8_2022"]:
  game.selected_kart=game.catalog.vehicle_index(StringName(id));game.local_players[1].vehicle_id=&"duster"
  await game.start_race();game.state="race"
  for kart in game.karts:kart.active=true;kart.auto_drive=true
  var kart: Node3D=game.karts[0]
  var initial_progress: float=kart.progress
  for tick in 1200:await physics_frame
  kart.boost_fuel=1.;kart.boost(1.5,"RELEASE CHECK")
  for tick in 120:await physics_frame
  var travelled: float=kart.progress-initial_progress
  var ok: bool=travelled>50. and kart.wheels.size()==4 and game.race_modified
  if not ok:errors.append(id+": representative driving/boost failed")
  rows.append({"id":id,"travelled_m":travelled,"wheels":kart.wheels.size(),"unranked":game.race_modified});game.return_menu()
 Engine.time_scale=1.
 var report:={"status":"PASS" if errors.is_empty() else "FAIL","cars":rows,"errors":errors,"driver_tests":0}
 FileAccess.open("res://build/release-2.3/qa/import-driving.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("IMPORT_DRIVING ",JSON.stringify(report));await game.quit_game(0 if errors.is_empty() else 2)
