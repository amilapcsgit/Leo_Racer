extends SceneTree
var failures: Array[String]=[]
var checks:=0
var game: Node3D
var viewport: SubViewport
var visual:=false
var out:="res://build/qa-ui/"
func _initialize() -> void:run.call_deferred()
func check(ok: bool,words: String) -> void:
 checks+=1
 if not ok:failures.append(words);push_error(words)
func frames(count: int=3) -> void:
 for i in count:await process_frame
func capture(name: String) -> void:
 if not visual:return
 await frames(15);await RenderingServer.frame_post_draw
 viewport.get_texture().get_image().save_png(out+name+".png")
func buttons(parent: Node) -> Array[String]:
 var result: Array[String]=[]
 for button in parent.find_children("*","Button",true,false):result.append(button.text)
 return result
func run() -> void:
 visual="--visual-test" in OS.get_cmdline_user_args()
 DirAccess.make_dir_recursive_absolute(out)
 viewport=SubViewport.new();viewport.size=Vector2i(1600,900);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 game=load("res://scenes/main.tscn").instantiate();viewport.add_child(game)
 var deadline:=Time.get_ticks_msec()+120000
 while not game.initialized and Time.get_ticks_msec()<deadline:
  await process_frame
 check(game.initialized,"Game initializes")
 if not game.initialized:print("UI_FRONTEND_TEST initialization failed");quit(1);return
 game.diagnostics_mode=true
 var ui: LeoFrontend=game.hud.frontend
 check("Go Race   →" in buttons(game.hud.menu_root),"Home has dominant Go Race")
 check(not "2 PLAYER MODE" in buttons(game.hud.menu_root),"Player count moved into setup")
 await capture("home")
 game.loading.race_summary="Astra Lotus Coast · 2 players · 3 laps";game.loading.stage("Getting your race ready…",65);await capture("loading");game.loading.hide()
 ui.show_setup(2);await frames()
 check(not ui.start_button.disabled and game.human_count==2,"Two players can start without readiness checklist")
 check(ui.player_status.size()==2,"Two player cards")
 var start_bounds:=ui.start_button.get_global_rect()
 check(start_bounds.end.y<=900 and start_bounds.position.y>=0,"Start button fits the design canvas")
 await capture("setup-two")
 ui.show_controls(1);await frames()
 check(ui.start_button.focus_mode==Control.FOCUS_NONE,"Dialog suspends background focus")
 check(not game.input_router.gameplay_enabled and game.input_router.controls_testing,"Controls test cannot activate race actions")
 check(game.hud.modal_root.get_child_count()>0,"Controls dialog opens")
 await capture("controls")
 ui.close_modal();await frames()
 check(game.hud.modal_root.get_child_count()==0,"Back closes controls")
 check(ui.start_button.focus_mode==Control.FOCUS_ALL,"Closing a dialog restores background focus")
 ui.show_tracks();await frames();await capture("tracks");ui.close_modal()
 var old_track: String=game.chosen_track_id
 await ui.choose_track(game.track_definition);await frames()
 check(ui.screen=="setup" and game.human_count==2,"Track selection retains setup and player count")
 var broken:=LeoTrackDefinition.new();broken.id="missing_test";broken.display_name="Unavailable track";broken.folder="res://assets/tracks/astra_coast";broken.metadata={"packs":[{"file":"not-installed.pck"}]}
 game.tracks.append(broken)
 await ui.choose_track(broken);await frames()
 check(game.chosen_track_id==old_track and ui.screen=="setup" and game.loading.visible,"Track failure preserves the selected race")
 game.loading.back.pressed.emit();await frames();check(not game.loading.visible,"Track failure has an actionable way back");ui.close_modal();game.tracks.erase(broken)
 ui.show_settings();await frames();await capture("settings");ui.close_modal()
 ui.show_guide();await frames();await capture("help");ui.close_modal()
 ui.show_records();await frames();await capture("records");ui.close_modal()
 ui.open_garage(1);await frames()
 check(game.hud.scene_mode=="garage" and game.selected_player_slot==1,"Garage targets P2")
 var garage: ModularCarSelector=game.hud.garage_selector
 check(garage.race_button.text=="Use This Ride","Garage confirms back into setup")
 var preview_deadline:=Time.get_ticks_msec()+30000
 while not is_instance_valid(garage.assembly) and Time.get_ticks_msec()<preview_deadline:await process_frame
 check(is_instance_valid(garage.assembly),"Live garage preview loads")
 await capture("garage")
 garage.race_requested.emit(garage.driver_id,garage.vehicle_id);await frames()
 check(ui.screen=="setup" and game.state=="lobby","Garage returns to setup without racing")
 for dimensions in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1080)]:
  viewport.size=dimensions;await frames()
  var bounds: Vector2=game.hud.position+Vector2(1600,900)*game.hud.scale
  check(bounds.x<=dimensions.x+.1 and bounds.y<=dimensions.y+.1,"Canvas fits "+str(dimensions))
  check(ui.start_button.get_global_rect().end.y<=dimensions.y+.1,"Start button remains visible at "+str(dimensions))
  await capture("setup-%dx%d" % [dimensions.x,dimensions.y])
 viewport.size=Vector2i(1600,900)
 await ui.start_selected();await frames()
 check(game.state=="countdown" and game.split_view.visible,"Start Race launches split screen")
 check(game.input_router.assignment_locked and game.input_router.gameplay_enabled,"Race locks device assignment and enables driving")
 game.state="race";game.race_time=12.
 for kart in game.karts:kart.set_physics_process(false)
 await capture("race-two")
 var pause_key:=InputEventKey.new();pause_key.physical_keycode=KEY_P;pause_key.pressed=true;viewport.push_input(pause_key,true);await frames()
 check(game.paused and not game.input_router.gameplay_enabled,"Pause freezes game and driving input")
 pause_key=InputEventKey.new();pause_key.physical_keycode=KEY_P;pause_key.pressed=false;viewport.push_input(pause_key,true)
 await capture("pause")
 ui.show_settings();await frames();ui.modal_back.call();await frames()
 check(game.paused and ui.modal_title=="TAKE A BREATHER","Settings returns to pause")
 game.toggle_pause();await frames()
 check(not game.paused and game.input_router.gameplay_enabled and game.hud.modal_root.get_child_count()==0,"Resume restores driving and closes overlay")
 var freeze_key:=InputEventKey.new();freeze_key.physical_keycode=KEY_P;freeze_key.pressed=true;viewport.push_input(freeze_key,true);await frames()
 check(game.paused,"A single pause event cannot pause and resume twice")
 freeze_key=InputEventKey.new();freeze_key.physical_keycode=KEY_P;freeze_key.pressed=false;viewport.push_input(freeze_key,true)
 freeze_key=InputEventKey.new();freeze_key.physical_keycode=KEY_P;freeze_key.pressed=true;viewport.push_input(freeze_key,true);await frames()
 check(not game.paused,"P resumes from the pause menu")
 game.return_menu();ui.show_setup(1);await ui.start_selected();await frames()
 check(not game.split_view.visible and is_instance_valid(game.hud.unified_hud),"Solo uses unified HUD")
 game.state="race";game.race_time=2.
 for kart in game.karts:kart.set_physics_process(false)
 await capture("race-one")
 game.hud.show_results();await frames()
 check(ui.screen=="results" and "Race Again   →" in buttons(game.hud.menu_root),"Results offers race again")
 await capture("results")
 game.stop_all_audio();game.ui_audio.voice.stop();game.return_menu();game.queue_free();await frames();viewport.queue_free();await frames()
 var report:={"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"errors":failures,"visual":visual,"renderer":RenderingServer.get_current_rendering_method()}
 FileAccess.open(out+"frontend-"+RenderingServer.get_current_rendering_method()+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("UI_FRONTEND_TEST ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
