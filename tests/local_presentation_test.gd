extends SceneTree
var errors: Array[String]=[]
var checks:=0
var game: Node3D
func _initialize() -> void:run.call_deferred()
func check(ok: bool,text: String) -> void:
 checks+=1
 if not ok:errors.append(text);push_error(text)
func frame() -> void:
 await process_frame;await process_frame
func capture(name: String) -> void:
 if not "--visual-test" in OS.get_cmdline_user_args():return
 await frame();await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://docs/qa-local2player/"+name+".png")
func run() -> void:
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await game.initialization_finished;await frame();game.diagnostics_mode=true
 var labels:=[]
 for button in game.hud.menu_root.find_children("*","Button",true,false):labels.append(button.text)
 check("2 PLAYER MODE" in labels and "CONTROLS" in labels,"Menu exposes multiplayer and controls")
 game.open_local_lobby();await frame()
 check(game.hud.local_lobby.cards.size()==2 and game.state=="lobby","Two-player setup cards")
 check(game.hud.local_lobby.start_button.disabled,"Race cannot start without device readiness")
 await capture("lobby")
 game.selected_player_slot=1;game.hud.show_garage("lobby");await frame()
 check(game.hud.garage_selector.vehicle_id==game.local_players[1].vehicle_id,"Garage targets P2")
 game.hud.garage_selector.choose_driver(&"hedgehog");game.hud.garage_selector.choose_vehicle(&"bigster")
 check(game.local_players[1].driver_id==&"hedgehog" and game.local_players[1].vehicle_id==&"bigster","P2 garage edits own selection")
 game.open_local_lobby();game.selected_driver=game.catalog.driver_index(&"human");game.selected_kart=game.catalog.vehicle_index(&"bigster")
 game.custom_player_name="LEFT PILOT";game.local_players[1].player_name="RIGHT PILOT";game.local_players[1].vehicle_id=&"duster"
 await game.start_race();game.state="race"
 for kart in game.karts:kart.active=true;kart.set_physics_process(false)
 await frame()
 check(game.split_view.visible,"Split view active")
 check(game.split_view.views[0].world_3d==game.split_view.views[1].world_3d and game.split_view.views[0].world_3d==game.get_world_3d(),"Both cameras share one physics world")
 check(not game.camera.current and game.split_view.cameras[0].current and game.split_view.cameras[1].current,"Only the two race cameras render")
 check(game.local_players[0].camera!=game.local_players[1].camera,"Independent chase cameras")
 check(game.karts.all(func(k):return k.visual.visible),"P1 view never globally hides P2 racers")
 for resolution in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1080)]:
  root.size=resolution
  if DisplayServer.get_name()!="headless":DisplayServer.window_set_size(resolution)
  await frame()
  var left: SubViewport=game.split_view.views[0];var right: SubViewport=game.split_view.views[1]
  print("SPLIT_SIZE ",resolution," canvas ",game.split_view.size," views ",left.size," / ",right.size)
  check(absf(left.size.x-right.size.x)<=1 and left.size.y==resolution.y,"Equal vertical split at "+str(resolution))
  check(game.split_view.overlays[0].title.text.contains("LEFT PILOT") and game.split_view.overlays[1].title.text.contains("RIGHT PILOT"),"Names isolated at "+str(resolution))
  await capture("split-%dx%d" % [resolution.x,resolution.y])
 game.toggle_pause();check(game.split_view.views[0].render_target_update_mode==SubViewport.UPDATE_ONCE,"Paused view freezes")
 await capture("split-pause")
 game.toggle_pause();check(game.split_view.views[1].render_target_update_mode==SubViewport.UPDATE_ALWAYS,"Resume updates both cameras")
 game.race_time=123.4;game.on_gate(game.karts[0],24);game.on_gate(game.karts[1],24);game._process(.01)
 check(game.hud.scene_mode=="results" and game.state=="results","Shared two-player results")
 await capture("split-results")
 game.return_menu();check(not game.split_view.visible and game.camera.current,"Menu restores full-window camera")
 game.human_count=1;await game.start_race();check(not game.split_view.visible and game.camera.current,"Single-player stays full width")
 var report:={"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors,"renderer":RenderingServer.get_current_rendering_method(),"captures":"--visual-test" in OS.get_cmdline_user_args()}
 FileAccess.open("res://docs/qa-local2player/presentation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("LOCAL_PRESENTATION_TEST ",report)
 game.return_menu();game.stop_all_audio();game.queue_free();await frame();quit(0 if errors.is_empty() else 1)
