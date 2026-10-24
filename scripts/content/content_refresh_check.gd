extends RefCounted
static func click(tree: SceneTree,control: Control) -> void:
 # Exercise GUI hit testing and delivery, including the final CanvasLayer transform.
 await tree.process_frame;await tree.process_frame
 var position:=control.get_global_transform_with_canvas()*(control.size*.5)
 var motion:=InputEventMouseMotion.new();motion.position=position;motion.global_position=position
 tree.root.push_input(motion,true);await tree.process_frame
 print("CONTENT_POINTER ",control.text," position=",position," rect=",control.get_global_rect()," hovered=",tree.root.gui_get_hovered_control())
 for pressed in [true,false]:
  var event:=InputEventMouseButton.new();event.position=position;event.global_position=position;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
  tree.root.push_input(event,true);await tree.process_frame
static func find_button(root: Node,caption: String) -> Button:
 for child in root.find_children("*","Button",true,false):
  if child.text==caption:return child
 return null
static func run(tree: SceneTree) -> Dictionary:
 var errors: Array[String]=[];var checks:=0
 var game: Node=load("res://scenes/main.tscn").instantiate();tree.root.add_child(game);await game.initialization_finished
 game.diagnostics_mode=true;game.show_content_manager();await tree.process_frame
 var manager: LeoContentManager=game.content_panel
 var folder:=LeoVehicleLibrary.default_root();var pending:=folder.path_join("refresh_probe.glb");var probe:=folder.path_join("refresh_probe")
 if FileAccess.file_exists(pending) or DirAccess.dir_exists_absolute(probe):
  errors.append("Refresh fixture already exists; refusing to overwrite it")
 else:
  var stock: VehicleDefinition=game.catalog.vehicle(&"duster");DirAccess.copy_absolute(stock.model_path,pending)
  await click(tree,manager.refresh_button)
  while manager.refreshing:await tree.process_frame
  checks+=1
  if not LeoVehicleLibrary.pending.has(pending) or not manager.status.text.contains("Refreshed "):errors.append("Refresh button did not discover a newly dropped GLB")
  checks+=1
  if tree.root.gui_get_focus_owner()!=manager.refresh_button:errors.append("Underlying frontend stole Content focus")
  var setup_button:=find_button(manager,"Set Up Vehicle")
  await click(tree,setup_button);await tree.process_frame
  var editor: Node=null
  for child in game.get_children():
   if child is LeoVehicleSetup:editor=child
  checks+=1
  if not editor or manager.visible:errors.append("Pointer Set Up Vehicle did not open workshop")
  if editor:
   var back:=find_button(editor,"Back");await click(tree,back)
   while manager.refreshing:await tree.process_frame
   await tree.process_frame
   checks+=1
   if is_instance_valid(editor) or not manager.visible:errors.append("Pointer workshop Back did not restore Content")
  DirAccess.make_dir_recursive_absolute(probe);DirAccess.copy_absolute(pending,probe.path_join("model.glb"))
  var data:=LeoVehicleCodec.serialize(stock);data.id="refresh_probe";data.display_name="Refresh Probe"
  FileAccess.open(probe.path_join("vehicle.json"),FileAccess.WRITE).store_string(JSON.stringify(data,"  ")+"\n")
  # Returning from workshop follows exactly the same awaited refresh path.
  await manager.resume_list();checks+=1
  if not game.catalog.vehicle(&"refresh_probe") or game.KARTS.size()!=game.catalog.vehicles.size():errors.append("Workshop return retained a stale garage roster")
  checks+=1
  if manager.list.get_child_count()!=LeoVehicleLibrary.entries.size()+LeoVehicleLibrary.pending.size()+LeoVehicleLibrary.unavailable.size():errors.append("Refresh left stale list rows")
  game.state="race";var generation:=LeoVehicleLibrary.generation;await manager.refresh();checks+=1
  if LeoVehicleLibrary.generation!=generation:errors.append("Refresh changed content during a race")
  game.state="menu"
  for name in ["model.glb","vehicle.json"]:DirAccess.remove_absolute(probe.path_join(name))
  DirAccess.remove_absolute(probe);DirAccess.remove_absolute(pending)
  await manager.refresh();checks+=1
  if game.catalog.vehicle(&"refresh_probe") or LeoVehicleLibrary.pending.has(pending):errors.append("Refresh retained removed optional content")
  checks+=1
  if game.catalog.vehicles.size()<2 or manager.refresh_button.disabled:errors.append("Refresh did not restore usable menu controls")
 var original_size:=tree.root.size
 for dimensions in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1080)]:
  tree.root.size=dimensions;await tree.process_frame;await tree.process_frame
  await click(tree,manager.refresh_button)
  while manager.refreshing:await tree.process_frame
  checks+=1
  if not manager.status.text.contains("Refreshed ") or tree.root.gui_get_focus_owner()!=manager.refresh_button:errors.append("Pointer refresh/focus failed after resizing to "+str(dimensions))
 tree.root.size=original_size
 await click(tree,find_button(manager,"Back"));await tree.process_frame
 checks+=1
 if is_instance_valid(manager):errors.append("Pointer Content Back did not close panel")
 game.show_content_manager();await tree.process_frame
 var escape:=InputEventKey.new();escape.physical_keycode=KEY_ESCAPE;escape.keycode=KEY_ESCAPE;escape.pressed=true;tree.root.push_input(escape,true);await tree.process_frame
 checks+=1
 if is_instance_valid(game.content_panel):errors.append("Escape did not close Content")
 var saved_vehicles: Array=game.catalog.vehicles.duplicate()
 game.catalog.vehicles.clear();game.show_content_manager();await tree.process_frame
 await click(tree,find_button(game.content_panel,"Back"));await tree.process_frame
 checks+=1
 if is_instance_valid(game.content_panel) or game.hud.frontend.screen!="home":errors.append("An empty roster trapped the user in Content")
 game.catalog.vehicles.append_array(saved_vehicles)
 game.stop_all_audio();game.queue_free();await tree.process_frame;await tree.process_frame
 return {"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors,"pointer_event_delivery":true,"workshop_return":true,"dpi":"Viewport transforms exercised; physical Windows DPI requires visual verification"}

