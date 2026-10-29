extends Node
## Opt-in export QA; runs only with --drive-test --release-ui-check.
var root: Window:
 get:return get_tree().root
var process_frame: Signal:
 get:return get_tree().process_frame
var game: Node3D
var checks:=0
var errors: Array[String]=[]
var output:=""
const POINTER=preload("res://scripts/content/content_refresh_check.gd")
func _ready() -> void:run.call_deferred()
func check(ok: bool,text: String) -> void:
 checks+=1
 if not ok:errors.append(text);push_error(text)
func button(parent: Node,text: String) -> Button:
 for node in parent.find_children("*","Button",true,false):
  if node.text==text and node.is_visible_in_tree():return node
 return null
func settle(frames: int=4) -> void:
 for frame in frames:await process_frame
 if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
func capture(label: String) -> void:
 await settle()
 if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png(output.path_join(label+".png"))
func font_check(parent: Node) -> void:
 for node in parent.find_children("*","Control",true,false):
  if not node.is_visible_in_tree():continue
  if node is Label and not node.text.is_empty():check(node.get_theme_font_size("font_size")>=20,"Readable label: "+node.text.left(40))
  elif node is BaseButton and not node is LeoActionButton and not node.text.is_empty():check(node.get_theme_font_size("font_size")>=24,"Readable control: "+node.text.left(40))
func content_from_home(label: String,use_keyboard: bool=false) -> void:
 var control:=button(game.hud.menu_root,"Content")
 check(control!=null,"Home Content button exists / "+label)
 if not control:return
 if use_keyboard:
  control.grab_focus()
  for pressed in [true,false]:
   var event:=InputEventAction.new();event.action="ui_accept";event.pressed=pressed;root.push_input(event,true);await process_frame
 else:await POINTER.click(get_tree(),control)
 await settle();check(game.state=="menu" and is_instance_valid(game.content_panel) and game.content_panel.visible,"Content opens from actual Home input / "+label)
 if is_instance_valid(game.content_panel):
  var manager: LeoContentManager=game.content_panel
  manager.browser.use_native_dialog=false;manager.browse_glb();await settle()
  check(manager.browser_open,"Picker input shield / "+label)
  manager.browser.hide();manager.browser.canceled.emit()
  var escape:=InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.physical_keycode=KEY_ESCAPE;escape.pressed=true;root.push_input(escape,true);await settle()
  check(is_instance_valid(game.content_panel),"Picker dismissal Escape preserves Content / "+label)
  font_check(game.content_panel);await capture("content-"+label);await POINTER.click(get_tree(),button(game.content_panel,"Back"));await settle()
 check(not is_instance_valid(game.content_panel),"Content Back closes / "+label)
func run() -> void:
 output=ProjectSettings.globalize_path("res://build/qa26-release/ui")
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--qa-output="):output=arg.trim_prefix("--qa-output=")
 DirAccess.make_dir_recursive_absolute(output);root.size=Vector2i(1920,1080);DisplayServer.window_set_size(root.size);Engine.max_fps=120
 var assets:=OS.get_environment("LEO_ASSET_ROOT")
 if assets.is_empty():assets=OS.get_executable_path().get_base_dir().path_join("GameAssets")
 check(LeoAssets.configure(assets)==OK and LeoAssets.mount_packs()==OK,"Assets mount")
 LeoVehicleLibrary.discover();game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await game.initialization_finished;game.diagnostics_mode=true;game.ranking_store=load("res://scripts/LocalRankingStore.cs").new();check(game.ranking_store.open_store(ProjectSettings.globalize_path("user://rankings.sqlite3")),"SQLite worker opens")
 await content_from_home("fresh")
 for route in ["header","escape","controller","explicit"]:
  await game.start_race();game.state="results";game.hud.frontend.show_results();await settle()
  if route=="header":await POINTER.click(get_tree(),button(game.hud.menu_root,"Back"))
  elif route=="explicit":await POINTER.click(get_tree(),button(game.hud.menu_root,"Home"))
  else:
   var event: InputEvent=InputEventKey.new() if route=="escape" else InputEventJoypadButton.new()
   if event is InputEventKey:event.physical_keycode=KEY_ESCAPE;event.keycode=KEY_ESCAPE
   else:event.button_index=JOY_BUTTON_B;event.device=0
   event.pressed=true;root.push_input(event,true);await settle()
  check(game.state=="menu" and game.karts.is_empty(),"Results route performs menu cleanup / "+route)
  await content_from_home(route,route=="controller")
 game.hud.frontend.show_home();await settle()
 var previous:=""
 for index in 9:
  game.hud.frontend.show_home();await settle()
  var chosen: String=game.hud.frontend.home_art
  check(chosen in game.hud.frontend.HOME_ART and ResourceLoader.exists(chosen),"Home hero packaged")
  check(chosen!=previous,"Home avoids repeated artwork");previous=chosen
  check(game.hud.menu_root.find_children("*","SubViewport",true,false).is_empty(),"Home has no vehicle viewport")
  await settle();check(game.hud.frontend.home_art==chosen,"Home image stable during navigation")
  if index<3:await capture("home-hero-"+str(index))
 for track in LeoLoadingBackdrops.TRACKS:
  var last:="";var seen: Dictionary={}
  for i in 12:
   var operation:=LeoLoadingBackdrops.new_operation("test");var selected:=LeoLoadingBackdrops.begin_load(operation,track)
   check(selected.contains("/"+track+"/"),"Loading art belongs to "+track);check(selected!=last,"Loading art avoids repeats / "+track);check(LeoLoadingBackdrops.begin_load(operation,track)==selected,"Loading operation keeps its art");seen[selected]=true;last=selected
  check(seen.size()==3,"All three loading designs used / "+track)
 for extent in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1440),Vector2i(2560,1080)]:
  root.size=extent;DisplayServer.window_set_size(extent);await settle()
  var size_label:="%dx%d"%[extent.x,extent.y]
  game.hud.frontend.show_home();await settle(12);font_check(game.hud.menu_root);await capture("home-"+size_label)
  game.hud.frontend.show_settings();font_check(game.hud.modal_root);await capture("settings-"+size_label)
  for node in game.hud.modal_root.find_children("*","ScrollContainer",true,false):node.scroll_vertical=10000
  await capture("settings-bottom-"+size_label);await POINTER.click(get_tree(),button(game.hud.modal_root,"Back"))
  game.hud.frontend.show_records();await settle();font_check(game.hud.modal_root);await POINTER.click(get_tree(),button(game.hud.modal_root,"More Filters"));await capture("records-"+size_label);await POINTER.click(get_tree(),button(game.hud.modal_root,"Back"));await settle();check(game.hud.modal_root.get_child_count()==0,"Records Back closes without error")
  game.hud.frontend.show_controls();font_check(game.hud.modal_root);await capture("controls-"+size_label);game.hud.frontend.close_modal()
  game.local_players[0].player_name="ABCDEFGHIJKLMNOPQRSTUVWXYZ123456";game.hud.frontend.show_setup(2);font_check(game.hud.menu_root);await settle(30);check(game.hud.frontend.prompt.get_global_rect().end.y<=root.get_visible_rect().size.y,"Setup footer visible / "+size_label);await capture("setup-"+size_label);game.return_menu()
 var report:={"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors,"renderer":RenderingServer.get_current_rendering_method()}
 FileAccess.open(output.path_join("ui.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("UI26_TEST ",JSON.stringify(report));await game.quit_game(0 if errors.is_empty() else 2)
