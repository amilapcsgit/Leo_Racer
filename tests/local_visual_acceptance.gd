extends SceneTree
var game: Node3D
var errors: Array[String]=[]
var checks:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:errors.append(message);push_error(message)
func capture(label: String) -> void:
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_jpg("res://docs/qa-local2player/"+label+".jpg",.88)
func run() -> void:
 root.size=Vector2i(1920,1080);DisplayServer.window_set_size(root.size)
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame;game.diagnostics_mode=true
 game.hud.show_garage()
 for v in [&"duster",&"bigster"]:
  for d in game.catalog.drivers:
   game.hud.garage_selector.choose_driver(d.id);game.hud.garage_selector.choose_vehicle(v)
   check(game.hud.garage_selector.vehicle_id==v and game.hud.garage_selector.driver_id==d.id,"Garage target "+String(v)+"/"+String(d.id))
   await capture("garage-%s-%s" % [v,d.id])
 game.return_menu();game.hud.show_controls();await capture("controls");game.hud.clear(game.hud.modal_root)
 var database=load("res://scripts/LocalRankingStore.cs").new();var path:=ProjectSettings.globalize_path("user://visual-rankings.sqlite3");database.open_store(path)
 database.save_session("visual",1,[{"finished":true,"retired":false,"next_gate":25,"race_time":301.23,"best_lap":98.8,"profile_id":"visual","name":"COLOMBO PILOT","driver":"mario","vehicle":"duster","class_id":"standard165","place":1}],false,false)
 game.ranking_store=database;game.legacy_best_time=320.2;game.hud.show_rankings();await capture("rankings");game.hud.clear(game.hud.modal_root);game.ranking_store=null;database.close_store()
 for suffix in ["","-shm","-wal"]:DirAccess.remove_absolute(path+suffix)
 game.human_count=2;game.selected_kart=game.catalog.vehicle_index(&"bigster");game.local_players[1].vehicle_id=&"duster"
 for d in game.catalog.drivers:
  game.selected_driver=game.catalog.driver_index(d.id);game.local_players[1].driver_id=d.id
  game.start_race();game.state="race"
  for k in game.karts:k.active=true;k.auto_drive=true
  for i in 30:await physics_frame
  check(game.karts[0].driver.get_meta("visible_driver_id")==d.id and game.karts[1].driver.get_meta("visible_driver_id")==d.id,"Driving cabin identities "+String(d.id))
  await capture("driving-"+String(d.id))
 var report:={"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors,"renderer":RenderingServer.get_current_rendering_method(),"resolution":[1920,1080]}
 FileAccess.open("res://docs/qa-local2player/visual-acceptance.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("LOCAL_VISUAL_TEST ",report)
 game.return_menu();game.stop_all_audio();game.queue_free();await process_frame;await process_frame;quit(0 if errors.is_empty() else 1)
