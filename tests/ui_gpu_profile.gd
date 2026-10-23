extends SceneTree
var game: Node3D
var viewport: SubViewport
func _initialize() -> void:run.call_deferred()
func frames(count: int) -> void:
 for i in count:await process_frame
func sample() -> float:
 await frames(30)
 var values: Array[float]=[]
 for i in 90:
  await RenderingServer.frame_post_draw
  values.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport.get_viewport_rid()))
 values.sort();return values[values.size()/2]
func run() -> void:
 viewport=SubViewport.new();viewport.size=Vector2i(1920,1080);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport);RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(),true)
 game=load("res://scenes/main.tscn").instantiate();viewport.add_child(game);await game.initialization_finished;game.diagnostics_mode=true;game.human_count=1
 await game.start_race();game.state="race";game.race_time=12.
 for kart in game.karts:kart.set_physics_process(false)
 game.set_process(false);game.hud.hud_root.hide()
 var baseline:=await sample()
 game.hud.hud_root.show()
 var hud_time:=await sample()
 game.toggle_pause()
 var blur_time:=await sample()
 var report:={"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"resolution":"1920x1080","scene_without_ui_ms":baseline,"scene_with_hud_ms":hud_time,"scene_with_pause_ms":blur_time,"hud_delta_ms":hud_time-baseline,"pause_delta_ms":blur_time-baseline,"target_ms":2.,"measurement":"Median of 90 frames after 30 warmup frames; same frozen scene."}
 report["status"]="PASS" if baseline>0 and maxf(hud_time-baseline,blur_time-baseline)<=2. else "CHECK"
 DirAccess.make_dir_recursive_absolute("res://build/qa-ui")
 FileAccess.open("res://build/qa-ui/gpu-profile.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("UI_GPU_PROFILE ",JSON.stringify(report))
 game.stop_all_audio();game.queue_free();await frames(3);viewport.queue_free();await frames(3);quit()
