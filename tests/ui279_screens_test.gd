extends SceneTree
## Actual menu/results captures complement the focused loading-row regression.
var game: Node3D
var output: String
var errors: Array[String]=[]
var checks:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:errors.append(message);push_error(message)
func settle(count: int=6) -> void:
 for frame in count:await process_frame
func scrolls(button: Control) -> bool:
 var ancestor:=button.get_parent()
 while ancestor:
  if ancestor is ScrollContainer:return true
  ancestor=ancestor.get_parent()
 return false
func shot(name: String) -> void:
 await settle()
 var extent:=root.get_visible_rect()
 for parent in [game.hud.menu_root,game.hud.modal_root]:
  for button in parent.find_children("*","Button",true,false):
   if button.is_visible_in_tree() and not scrolls(button):check(extent.encloses(button.get_global_rect()),"Non-scrolling action stays on screen / "+name+" / "+button.text)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(name+".png"))
func gauge_signature(instruments: LeoRaceInstruments) -> Dictionary:
 return {"speed":instruments.labels.speed.get_rect(),"font_size":instruments.labels.speed.get_theme_font_size("font_size"),"font":instruments.labels.speed.get_theme_font("font"),"rpm":instruments.labels.rpm_unit.get_rect(),"analog":LeoTelemetry.rpm_bounds(instruments),"nitro":instruments.nitro_liquid.get_rect()}
func camera_gauges() -> void:
 game.state="race";game.race_time=12.
 for kart in game.karts:
  kart.set_physics_process(false);kart.active=false;kart.wheel_motion_speed=23.6
  if kart.motor_audio:kart.motor_audio.set_process(false);kart.motor_audio.rpm=4200.
 for extent in [Vector2i(1280,720),Vector2i(1920,1080)]:
  root.size=extent;await settle()
  for count in [1,2]:
   game.human_count=count;game.split_view.activate(count==2);game.hud.show_race();await settle()
   var references: Array=[]
   for view in ["chase","ghost","cockpit"]:
    for slot in count:
     game.local_players[slot].camera_view=view;game.local_players[slot].camera_rig.reset();game.update_local_camera(game.local_players[slot],1.)
    await settle()
    var instruments: Array=game.split_view.overlays if count==2 else [game.hud.unified_hud]
    for slot in count:
     var hud: LeoRaceInstruments=instruments[slot]
     check(LeoCameraViews.effective(game.local_players[slot])==view,"Requested camera mode is actually active / "+view)
     var presentation:=gauge_signature(hud)
     var original_speed:=Rect2(580,hud.size.y-172,180,65) if count==2 else Rect2(1293,663+hud.size.y-900.,220,110)
     var original_center:=Vector2(670,hud.size.y-135) if count==2 else Vector2(1400,720+hud.size.y-900.)
     # Label's bundled raster metrics expand its natural height (117px at 91pt).
     # Preserve the authored position/width/font, and compare final height by view.
     check(presentation.speed.position==original_speed.position and is_equal_approx(presentation.speed.size.x,original_speed.size.x) and presentation.font_size==(62 if count==2 else 91),"Original digital speed design/position is preserved / "+view)
     check(LeoTelemetry.rpm_center(hud)==original_center,"Original analog RPM position is preserved / "+view)
     if view=="chase":references.append(presentation)
     else:check(presentation==references[slot],"Analog RPM and digital KM/H retain identical geometry/font in "+view+" / P"+str(slot+1))
     check(hud.labels.speed.is_visible_in_tree() and hud.labels.rpm_unit.is_visible_in_tree() and hud.nitro_liquid.is_visible_in_tree(),"Complete original gauge remains visible / "+view)
     check(hud.labels.speed.get_theme_font("font")==LeoSpeedDigits.font,"Original bundled raster speed font is preserved / "+view)
     check(hud.labels.speed.text=="084","Digital KM/H reads actual driving speed / "+view)
     var draws:=hud.analog_rpm_draws;await settle(2)
     check(hud.analog_rpm_draws>draws,"Analog RPM needle renders in "+view)
     if count==1 and view=="cockpit":
      var transform:=hud.get_global_transform_with_canvas()
      check((transform*LeoTelemetry.COCKPIT_TOP_STRIP.end).y<=root.get_visible_rect().size.y*.09,"Solo cockpit header occupies at most nine percent of height")
      check(not hud.labels.brand.visible and not hud.labels.progress.visible and not hud.labels.corner.visible,"Cockpit header removes oversized identity and decorative microcopy")
      var window_scale:=float(root.size.y)/root.get_visible_rect().size.y
      for label in [hud.labels.position,hud.labels.lap,hud.labels.timer,hud.labels.track]:check(label.get_theme_font_size("font_size")*absf(transform.get_scale().y)*window_scale>=19.99,"Compact cockpit header retains readable type")
    await shot("gauges-%dp-%s-%dx%d"%[count,view,extent.x,extent.y])
 game.split_view.activate(false)
func run() -> void:
 output=ProjectSettings.globalize_path("res://build/qa279/ui-screens")
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--qa-output="):output=arg.trim_prefix("--qa-output=")
 DirAccess.make_dir_recursive_absolute(output)
 check(LeoAssets.configure(OS.get_environment("LEO_ASSET_ROOT"))==OK and LeoAssets.mount_packs()==OK,"Installed assets mount")
 LeoVehicleLibrary.discover()
 game=load("res://scenes/main.tscn").instantiate();game.diagnostics_mode=true;root.add_child(game);await game.initialization_finished
 game.ranking_store=load("res://scripts/LocalRankingStore.cs").new()
 check(game.ranking_store.open_store(output.path_join("ui-records.sqlite3")),"Isolated empty records database opens")
 var front: LeoFrontend=game.hud.frontend
 for extent in [Vector2i(1280,720),Vector2i(1920,1080)]:
  root.size=extent;await settle()
  var suffix: String="-%dx%d"%[extent.x,extent.y]
  front.show_home();await shot("home"+suffix)
  check(root.gui_get_focus_owner()!=null,"Home has keyboard/controller focus")
  front.show_setup(2);await shot("setup-split"+suffix)
  front.show_settings();await settle()
  var tabs:=game.hud.modal_root.find_child("SettingsTabs",true,false) as TabContainer
  check(tabs!=null and tabs.get_tab_count()==5,"Five settings pages include Game Logic")
  if tabs:
   for index in 5:
    tabs.current_tab=index;await shot("settings-"+tabs.get_tab_title(index).to_lower()+suffix)
    if tabs.get_tab_control(index).name=="GameLogicTab":
     var toggle:=tabs.find_child("AllowAIBigster",true,false) as CheckButton
     check(toggle!=null and toggle.button_pressed==game.allow_ai_bigster,"Game Logic checkbox reflects the saved AI preference")
     if toggle:
      toggle.button_pressed=true;check(game.allow_ai_bigster,"Game Logic opt-in checkbox updates the next-race preference")
      toggle.button_pressed=false;check(not game.allow_ai_bigster,"Game Logic checkbox can restore the default OFF policy")
  front.close_modal()
  front.show_controls(0);await shot("controls"+suffix);front.close_modal()
  front.show_tracks();await shot("tracks"+suffix);front.close_modal()
  front.show_records();await settle(20);await shot("records"+suffix);front.close_modal()
  game.return_menu()
 game.human_count=2;game.local_players[0].vehicle_id=&"bigster";game.local_players[1].vehicle_id=&"duster"
 await game.start_race();game.set_process(false)
 await camera_gauges();game.state="results"
 for kart in game.karts:kart.set_physics_process(false);kart.active=false
 for slot in 2:
  game.local_players[slot].kart.finished=true;game.local_players[slot].kart.finish_time=123.456+float(slot)*2.
  game.local_players[slot].best_lap=40.123+float(slot)
 front.result_reference_time=124.;front.result_reference_session=game.session_id
 for extent in [Vector2i(1280,720),Vector2i(1920,1080)]:
  root.size=extent;await settle()
  for count in [1,2]:
   game.human_count=count;front.show_results();await shot("results-%dp-%dx%d"%[count,extent.x,extent.y])
   var words: String=" ".join(game.hud.menu_root.find_children("*","Label",true,false).map(func(label):return label.text))
   check(words.contains("Best lap") and words.contains("PERSONAL BEST"),"Results include best lap and comparable personal-best delta")
 var report:={"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors,"renderer":RenderingServer.get_current_rendering_method()}
 FileAccess.open(output.path_join("ui-screens.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("UI_SCREENS279 ",JSON.stringify(report));await game.quit_game(0 if errors.is_empty() else 1)
