extends SceneTree
# Uses only 1.9 public interfaces so the same script can measure the old export.
var game: Node3D
var viewport: SubViewport
var label:="neon"
var baseline_assets:=""
var output:="res://build/qa-neon/gpu-neon.json"
func _initialize() -> void:run.call_deferred()
func frames(count: int) -> void:
 for i in count:await process_frame
func sample() -> float:
 print("GPU_SAMPLE_BEGIN ",label)
 await frames(30)
 var values: Array[float]=[]
 for i in 90:
  await RenderingServer.frame_post_draw
  values.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport.get_viewport_rid()))
 values.sort();return values[values.size()/2]
func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--baseline-assets="):baseline_assets=arg.trim_prefix("--baseline-assets=")
  if arg.begins_with("--gpu-label="):label=arg.trim_prefix("--gpu-label=")
  if arg.begins_with("--gpu-out="):output=arg.trim_prefix("--gpu-out=")
 if not baseline_assets.is_empty() or not OS.has_feature("editor"):
  var error:=LeoAssets.configure(baseline_assets if not baseline_assets.is_empty() else OS.get_executable_path().get_base_dir().path_join("GameAssets"))
  if error!=OK or LeoAssets.mount_packs()!=OK:push_error("Cannot mount baseline content");quit(1);return
 viewport=SubViewport.new();viewport.size=Vector2i(1920,1080);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport);RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(),true)
 game=load("res://scenes/main.tscn").instantiate();viewport.add_child(game);await game.initialization_finished;print("GPU_INITIALIZED ",label);game.diagnostics_mode=true;game.set_process(false)
 game.return_menu();var home:=await sample();print("GPU_HOME ",home)
 game.hud.frontend.open_garage(0);print("GPU_GARAGE_OPEN")
 var deadline:=Time.get_ticks_msec()+30000
 while not is_instance_valid(game.hud.garage_selector.assembly) and Time.get_ticks_msec()<deadline:await process_frame
 game.hud.garage_selector.set_process(false);var garage:=await sample()
 game.return_menu();game.hud.frontend.show_tracks();var tracks:=await sample()
 var report:={"label":label,"home_ms":home,"garage_ms":garage,"tracks_ms":tracks,"gpu":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"resolution":"1920x1080","track":game.chosen_track_id,"measurement":"Median of 90 frames after 30 warmup frames per screen; same hardware and scene."}
 FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("NEON_GPU_PROFILE ",JSON.stringify(report))
 game.stop_all_audio();game.queue_free();await frames(6);viewport.queue_free();await frames(6);LeoAssets.cache.clear();LeoAssets._patched_meshes.clear();quit()
