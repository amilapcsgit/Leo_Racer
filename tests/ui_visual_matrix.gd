extends SceneTree
var viewport: SubViewport
var game: Node3D
var errors: Array[String]=[]
var captures:=0
var output:="res://build/qa-ui/matrix/"
func _initialize() -> void:run.call_deferred()
func frames(count: int=5) -> void:
 for i in count:await process_frame
func shot(name: String) -> void:
 await frames(5);await create_timer(.35).timeout;await RenderingServer.frame_post_draw
 var dimensions:=viewport.size
 viewport.get_texture().get_image().save_png(output+name+"-%dx%d.png" % [dimensions.x,dimensions.y])
 var panel:=game.hud.modal_root.find_child("ConfirmationDialog",true,false) as Control
 if panel:
  var bounds:=panel.get_global_rect()
  if bounds.position.x<-.1 or bounds.position.y<-.1 or bounds.end.x>dimensions.x+.1 or bounds.end.y>dimensions.y+.1:errors.append("Dialog clipped: "+name+" "+str(dimensions))
 captures+=1
func run() -> void:
 output+=RenderingServer.get_current_rendering_method()+"/"
 DirAccess.make_dir_recursive_absolute(output)
 viewport=SubViewport.new();viewport.own_world_3d=true;viewport.size=Vector2i(1600,900);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 game=load("res://scenes/main.tscn").instantiate();viewport.add_child(game);await game.initialization_finished;game.diagnostics_mode=true
 var ui: LeoFrontend=game.hud.frontend
 for dimensions in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1080)]:
  viewport.size=dimensions;await frames()
  game.return_menu();await shot("home")
  ui.show_setup(2);await shot("setup")
  ui.show_settings();await shot("settings");ui.close_modal()
  ui.show_tracks();await shot("tracks");ui.close_modal()
  ui.show_controls(1);await shot("controls");ui.close_modal()
  ui.show_guide();await shot("help");ui.close_modal()
  ui.show_records();await shot("records");ui.close_modal()
  ui.open_garage(0);await frames(60)
  await shot("garage")
  game.hud.garage_selector.back_requested.emit();await frames()
  await ui.start_selected();game.state="race";game.race_time=12.
  for kart in game.karts:kart.set_physics_process(false)
  await shot("race-two")
  game.toggle_pause();await shot("pause");game.toggle_pause();game.return_menu()
  ui.show_setup(1);await ui.start_selected();game.state="race";game.race_time=12.
  for kart in game.karts:kart.set_physics_process(false)
  await shot("race-one")
  game.hud.show_results();await shot("results")
  game.loading.race_summary="Colombo City Grand Prix · 2 players · 3 laps";game.loading.stage("Getting your race ready…",65);await shot("loading");game.loading.hide()
  game.return_menu()
 var report:={"status":"PASS" if errors.is_empty() else "FAIL","captures":captures,"errors":errors,"renderer":RenderingServer.get_current_rendering_method(),"sizes":["1280x720","1920x1080","2560x1080"]}
 FileAccess.open("res://build/qa-ui/visual-matrix-"+RenderingServer.get_current_rendering_method()+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("UI_VISUAL_MATRIX ",JSON.stringify(report))
 game.stop_all_audio();game.queue_free();await frames();viewport.queue_free();await frames();LeoAssets.cache.clear();LeoAssets._patched_meshes.clear();quit(0 if errors.is_empty() else 1)
