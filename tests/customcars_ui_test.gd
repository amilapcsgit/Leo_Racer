extends SceneTree
## Real viewport events, isolated from player settings. Native OS dialogs need
## a separate manual pass; use the same FileDialog's embedded UI in this test.
var errors: Array[String]=[]
var checks := 0
func _initialize() -> void:run.call_deferred()
func expect(value: bool,message: String) -> void:
 checks+=1
 if not value:errors.append(message)
func escape(viewport: Viewport) -> void:
 for pressed in [true,false]:
  var event:=InputEventKey.new();event.keycode=KEY_ESCAPE;event.physical_keycode=KEY_ESCAPE;event.pressed=pressed
  if viewport is Window and viewport!=root:
   event.window_id=viewport.get_window_id();Input.parse_input_event(event)
  else:viewport.push_input(event,true)
  await process_frame
func run() -> void:
 var events=load("res://scripts/content/content_refresh_check.gd")
 var game: Node=load("res://scenes/main.tscn").instantiate();root.add_child(game);await game.initialization_finished
 game.diagnostics_mode=true;game.show_content_manager();await process_frame
 var manager: LeoContentManager=game.content_panel
 manager.browser.use_native_dialog=false
 await events.click(self,events.find_button(manager,"Import GLB…"))
 expect(manager.browser.visible,"Pointer Import GLB did not open the file chooser")
 expect(manager.visible and is_instance_valid(game.content_panel),"Opening the chooser closed Content")
 var original_screen: String=game.hud.frontend.screen
 await escape(manager.browser)
 expect(not manager.browser.visible,"Escape did not close the file chooser")
 expect(is_instance_valid(game.content_panel) and manager.visible,"Chooser Escape also closed Content")
 expect(game.hud.frontend.screen==original_screen,"Underlying frontend consumed chooser Escape")
 manager.browser.hide()
 # Cancel on the initial deferred-import frame, before a wheel/body preview exists.
 var vehicle: VehicleDefinition=game.catalog.vehicle(&"duster")
 var editor:=LeoVehicleSetup.new();editor.game=game;editor.configure(vehicle);game.add_child(editor);manager.hide()
 await escape(root)
 await process_frame;await process_frame
 expect(not is_instance_valid(editor),"Escape did not cancel the editor during initial model loading")
 manager.show()
 # Keep Content alive while background import finishes, then verify focus/mouse.
 while not LeoAssets._loading.is_empty():await process_frame
 var original_size:=root.size
 for size in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1080)]:
  root.size=size;await process_frame;await process_frame
  await events.click(self,manager.refresh_button)
  while manager.refreshing:await process_frame
  expect(root.gui_get_focus_owner()==manager.refresh_button,"Frontend stole Content focus after resizing to "+str(size))
  expect(manager.status.text.contains("Refreshed "),"Pointer Refresh failed after resizing to "+str(size))
 root.size=original_size
 await escape(root);await process_frame
 expect(not is_instance_valid(game.content_panel),"Content Escape did not return to the game menu")
 var report:={"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors,"native_file_dialog":"Not simulated; embedded FileDialog routes tested","physical_windows_dpi":"Not measured"}
 DirAccess.make_dir_recursive_absolute("res://build/customcars")
 FileAccess.open("res://build/customcars/ui.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
 print("CUSTOMCARS_UI_TEST ",JSON.stringify(report))
 game.stop_all_audio();game.queue_free();await process_frame;await process_frame
 quit(0 if errors.is_empty() else 1)
