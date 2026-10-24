extends RefCounted
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
  manager.refresh_button.pressed.emit()
  while manager.refreshing:await tree.process_frame
  checks+=1
  if not LeoVehicleLibrary.pending.has(pending) or not manager.status.text.contains("Refreshed "):errors.append("Refresh button did not discover a newly dropped GLB")
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
 game.stop_all_audio();game.queue_free();await tree.process_frame;await tree.process_frame
 return {"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors,"actual_refresh_button":true,"workshop_return":true}

